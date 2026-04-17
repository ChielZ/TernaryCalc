import Foundation
import SwiftUI
import Combine

enum BinaryOp: Hashable {
    case add
    case xRight
    case xLeft

    var glyph: OperatorGlyph {
        switch self {
        case .add:    return .plus
        case .xRight: return .xRight
        case .xLeft:  return .xLeft
        }
    }
}

enum Modifier: Hashable {
    case flip
    case invert

    var glyph: OperatorGlyph {
        switch self {
        case .flip:   return .flip
        case .invert: return .invert
        }
    }
}

/// One row in the running display history. Numbers and operator clusters
/// alternate; an `.ops` row may carry the base op + zero or more modifiers
/// rendered side by side.
enum DisplayRow: Hashable {
    case number(DisplayTrits)
    case ops([OperatorGlyph])
    case error
}

final class CalculatorState: ObservableObject {
    @Published private(set) var integerEntry:    [Trit] = []
    @Published private(set) var fractionalEntry: [Trit] = []
    @Published private(set) var inFractional:    Bool   = false

    @Published private(set) var history: [DisplayRow] = []

    @Published private(set) var accumulator:      BalancedTernary? = nil
    @Published private(set) var pendingOp:        BinaryOp?        = nil
    @Published private(set) var pendingModifiers: [Modifier]       = []

    @Published private(set) var errored: Bool = false

    // MARK: - Derived

    var entryDisplay: DisplayTrits? {
        if integerEntry.isEmpty && fractionalEntry.isEmpty && !inFractional {
            return nil
        }
        let intTrits  = integerEntry.isEmpty ? [Trit.zero] : strippedLeading(integerEntry)
        let fracTrits = strippedTrailing(fractionalEntry)
        return DisplayTrits(integer: intTrits, fractional: fracTrits)
    }

    var entryIsEmpty: Bool {
        integerEntry.isEmpty && fractionalEntry.isEmpty && !inFractional
    }

    /// The "live" operator row to render below the committed history while a
    /// pending op exists (so the user sees the op + modifiers they've chosen
    /// before the operation has been evaluated). Returns nil if no op pending.
    var pendingOpsRow: [OperatorGlyph]? {
        guard let op = pendingOp else { return nil }
        return [op.glyph] + pendingModifiers.map(\.glyph)
    }

    // MARK: - Key actions

    func type(_ trit: Trit) {
        if errored { return }
        let newIntCount  = inFractional ? integerEntry.count       : integerEntry.count + 1
        let newFracCount = inFractional ? fractionalEntry.count + 1 : fractionalEntry.count
        if !fitsInDisplay(intCount: newIntCount, fracCount: newFracCount) { return }
        if inFractional {
            fractionalEntry.append(trit)
        } else {
            integerEntry.append(trit)
        }
    }

    func tab() {
        if errored { return }
        if inFractional {
            let lenMod = fractionalEntry.count % 3
            let needed = lenMod == 0 ? 3 : (3 - lenMod)
            if !fitsInDisplay(intCount: integerEntry.count,
                              fracCount: fractionalEntry.count + needed) { return }
            fractionalEntry.append(contentsOf: Array(repeating: .zero, count: needed))
        } else {
            let lenMod = integerEntry.count % 3
            let needed = lenMod == 0 ? 3 : (3 - lenMod)
            if !fitsInDisplay(intCount: integerEntry.count + needed,
                              fracCount: fractionalEntry.count) { return }
            integerEntry = Array(repeating: .zero, count: needed) + integerEntry
        }
    }

    private func fitsInDisplay(intCount: Int, fracCount: Int, maxSlots: Int = 6) -> Bool {
        let intTT  = max(1, (intCount  + 2) / 3)
        let fracTT = (fracCount + 2) / 3
        return intTT + fracTT <= maxSlots
    }

    func point() {
        if errored { return }
        if !inFractional { inFractional = true }
    }

    func clear() {
        integerEntry.removeAll()
        fractionalEntry.removeAll()
        inFractional = false
        history.removeAll()
        accumulator = nil
        pendingOp = nil
        pendingModifiers = []
        errored = false
    }

    /// `flip` and `invert` are now MODIFIERS attached to the pending op.
    /// They toggle on second press, are reset when a new base op is chosen,
    /// and are no-ops when no op is pending.
    func flip()   { toggleModifier(.flip) }
    func invert() { toggleModifier(.invert) }

    private func toggleModifier(_ m: Modifier) {
        if errored { return }
        guard pendingOp != nil else { return }
        if let i = pendingModifiers.firstIndex(of: m) {
            pendingModifiers.remove(at: i)
        } else {
            pendingModifiers.append(m)
        }
    }

    func operation(_ op: BinaryOp) {
        if errored { return }

        if let value = currentEntryValue() {
            if let acc = accumulator, let p = pendingOp {
                switch evaluate(acc, p, value, pendingModifiers) {
                case .success(let r):
                    guard let dv = displayFor(value), let _ = displayFor(r) else {
                        markError(); return
                    }
                    accumulator = r
                    appendRow(.ops(opsRowGlyphs(p, pendingModifiers)))
                    appendRow(.number(dv))
                case .failure: markError(); return
                }
            } else {
                guard let dv = displayFor(value) else { markError(); return }
                accumulator = value
                appendRow(.number(dv))
            }
            commitEntry()
        }

        pendingOp = op
        pendingModifiers = []
    }

    func equals() {
        if errored { return }

        if let value = currentEntryValue() {
            if let acc = accumulator, let p = pendingOp {
                switch evaluate(acc, p, value, pendingModifiers) {
                case .success(let r):
                    guard let dv = displayFor(value), let dr = displayFor(r) else {
                        markError(); return
                    }
                    accumulator = r
                    appendRow(.ops(opsRowGlyphs(p, pendingModifiers)))
                    appendRow(.number(dv))
                    appendRow(.ops([.equals]))
                    appendRow(.number(dr))
                case .failure: markError(); return
                }
            } else {
                guard let dv = displayFor(value) else { markError(); return }
                accumulator = value
                appendRow(.number(dv))
            }
            commitEntry()
        }
        pendingOp = nil
        pendingModifiers = []
    }

    // MARK: - Helpers

    private func evaluate(_ a: BalancedTernary,
                          _ op: BinaryOp,
                          _ b: BalancedTernary,
                          _ mods: [Modifier]) -> Result<BalancedTernary, BalancedTernary.OperationError> {
        let modifiedB: BalancedTernary
        switch applyModifiers(b, mods) {
        case .success(let m): modifiedB = m
        case .failure(let e): return .failure(e)
        }
        switch op {
        case .add:    return a.adding(modifiedB)
        case .xRight: return a.xRight(modifiedB)
        case .xLeft:  return a.xLeft(modifiedB)
        }
    }

    private func applyModifiers(_ value: BalancedTernary,
                                _ mods: [Modifier]) -> Result<BalancedTernary, BalancedTernary.OperationError> {
        var v = value
        for m in mods {
            switch m {
            case .flip:
                v = v.flipped
            case .invert:
                switch v.inverted {
                case .success(let inv): v = inv
                case .failure(let e): return .failure(e)
                }
            }
        }
        return .success(v)
    }

    private func opsRowGlyphs(_ op: BinaryOp, _ mods: [Modifier]) -> [OperatorGlyph] {
        [op.glyph] + mods.map(\.glyph)
    }

    private func strippedLeading(_ trits: [Trit]) -> [Trit] {
        var out = trits
        while out.count > 1, out.first == .zero { out.removeFirst() }
        return out
    }

    private func strippedTrailing(_ trits: [Trit]) -> [Trit] {
        var out = trits
        while let last = out.last, last == .zero { out.removeLast() }
        return out
    }

    private func currentEntryValue() -> BalancedTernary? {
        if entryIsEmpty { return nil }
        return BalancedTernary.from(entryTrits: integerEntry,
                                    fractional: fractionalEntry)
    }

    private func commitEntry() {
        integerEntry.removeAll()
        fractionalEntry.removeAll()
        inFractional = false
    }

    private func displayFor(_ value: BalancedTernary) -> DisplayTrits? {
        DisplayFit.fit(value, maxSlots: 6)
    }

    private func appendRow(_ row: DisplayRow) {
        history.append(row)
    }

    private func markError() {
        appendRow(.error)
        errored = true
    }

}

// MARK: - BalancedTernary from trit-entry

extension BalancedTernary {
    static func from(entryTrits integer: [Trit], fractional: [Trit]) -> BalancedTernary? {
        var intValue = 0
        for t in integer {
            let (mul, o1) = intValue.multipliedReportingOverflow(by: 3)
            if o1 { return nil }
            let (sum, o2) = mul.addingReportingOverflow(t.rawValue)
            if o2 { return nil }
            intValue = sum
        }
        if fractional.isEmpty {
            return BalancedTernary.from(integer: intValue)
        }
        var fracNum = 0
        var pow3 = 1
        for t in fractional {
            let (mul, o1) = fracNum.multipliedReportingOverflow(by: 3)
            if o1 { return nil }
            let (sum, o2) = mul.addingReportingOverflow(t.rawValue)
            if o2 { return nil }
            fracNum = sum
            let (np, o3) = pow3.multipliedReportingOverflow(by: 3)
            if o3 { return nil }
            pow3 = np
        }
        let (intScaled, o4) = intValue.multipliedReportingOverflow(by: pow3)
        if o4 { return nil }
        let (totalNum, o5) = intScaled.addingReportingOverflow(fracNum)
        if o5 { return nil }
        return BalancedTernary.make(numerator: totalNum, denominator: pow3)
    }
}
