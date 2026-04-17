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

    /// Stack of past states (most recent last). Every mutating key press
    /// pushes onto this stack first; backspace pops and restores. This gives
    /// full-fidelity undo — not just "delete last trit" — at the cost of ~a
    /// few KB per entry. Capped at 500 entries.
    private var undoStack: [StateSnapshot] = []
    private let undoLimit = 500

    private struct StateSnapshot {
        let integerEntry: [Trit]
        let fractionalEntry: [Trit]
        let inFractional: Bool
        let history: [DisplayRow]
        let accumulator: BalancedTernary?
        let pendingOp: BinaryOp?
        let pendingModifiers: [Modifier]
        let errored: Bool
    }

    // MARK: - Derived

    var entryDisplay: DisplayTrits? {
        if integerEntry.isEmpty && fractionalEntry.isEmpty && !inFractional {
            return nil
        }
        let intTrits  = integerEntry.isEmpty ? [Trit.zero] : strippedLeading(integerEntry)
        // Deliberately do NOT strip trailing zero fractional trits during
        // entry — the user typed them and should see them while typing.
        // Stripping happens once the entry commits to the history.
        return DisplayTrits(integer: intTrits,
                            fractional: fractionalEntry,
                            showDecimal: inFractional)
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
        pushSnapshot()
        if inFractional {
            fractionalEntry.append(trit)
        } else {
            integerEntry.append(trit)
        }
    }

    /// Undo the most recent mutating keypress. Pops one state snapshot off the
    /// undo stack; no-op if empty. Works even when `errored` is true, so the
    /// user can walk back out of an error state.
    func backspace() {
        guard let snap = undoStack.popLast() else { return }
        restore(snap)
    }

    private func fitsInDisplay(intCount: Int, fracCount: Int, maxSlots: Int = 6) -> Bool {
        let intTT  = max(1, (intCount  + 2) / 3)
        let fracTT = (fracCount + 2) / 3
        return intTT + fracTT <= maxSlots
    }

    func point() {
        if errored { return }
        if inFractional { return }
        pushSnapshot()
        inFractional = true
    }

    func clear() {
        pushSnapshot()
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
        pushSnapshot()
        if let i = pendingModifiers.firstIndex(of: m) {
            pendingModifiers.remove(at: i)
        } else {
            pendingModifiers.append(m)
        }
    }

    func operation(_ op: BinaryOp) {
        if errored { return }
        pushSnapshot()

        if let value = currentEntryValue() {
            if let acc = accumulator, let p = pendingOp {
                let opsRow = opsRowGlyphs(p, pendingModifiers)
                let dv = displayFor(value)
                switch evaluate(acc, p, value, pendingModifiers) {
                case .success(let r):
                    if let dv = dv, let _ = displayFor(r) {
                        accumulator = r
                        appendRow(.ops(opsRow))
                        appendRow(.number(dv))
                    } else {
                        finalizeWithError(opsRow: opsRow, operandB: dv)
                        return
                    }
                case .failure:
                    finalizeWithError(opsRow: opsRow, operandB: dv)
                    return
                }
            } else {
                if let dv = displayFor(value) {
                    accumulator = value
                    appendRow(.number(dv))
                } else {
                    markError(); return
                }
            }
            commitEntry()
        }

        pendingOp = op
        pendingModifiers = []
    }

    func equals() {
        if errored { return }
        pushSnapshot()

        if let value = currentEntryValue() {
            if let acc = accumulator, let p = pendingOp {
                let opsRow = opsRowGlyphs(p, pendingModifiers)
                let dv = displayFor(value)
                switch evaluate(acc, p, value, pendingModifiers) {
                case .success(let r):
                    if let dv = dv, let dr = displayFor(r) {
                        accumulator = r
                        appendRow(.ops(opsRow))
                        appendRow(.number(dv))
                        appendRow(.ops([.equals]))
                        appendRow(.number(dr))
                    } else {
                        finalizeWithError(opsRow: opsRow, operandB: dv)
                        return
                    }
                case .failure:
                    finalizeWithError(opsRow: opsRow, operandB: dv)
                    return
                }
            } else {
                if let dv = displayFor(value) {
                    accumulator = value
                    appendRow(.number(dv))
                } else {
                    markError(); return
                }
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

    /// Finalize the current operation as an error — push the lead-up rows
    /// (operator + operand B, if available) followed by a synthetic `=` row
    /// and the error row. This makes the overflow appear in the display as
    /// the "answer" of the operation, rather than inline between operand and
    /// operator. Also clears the entry and pending op so no stray `pendingOps`
    /// / entry row gets appended below the error row in `visibleRows`.
    private func finalizeWithError(opsRow: [OperatorGlyph]?, operandB: DisplayTrits?) {
        if let opsRow = opsRow {
            appendRow(.ops(opsRow))
        }
        if let operandB = operandB {
            appendRow(.number(operandB))
        }
        appendRow(.ops([.equals]))
        markError()
        commitEntry()
        pendingOp = nil
        pendingModifiers = []
    }

    // MARK: - Undo stack

    private func takeSnapshot() -> StateSnapshot {
        StateSnapshot(
            integerEntry: integerEntry,
            fractionalEntry: fractionalEntry,
            inFractional: inFractional,
            history: history,
            accumulator: accumulator,
            pendingOp: pendingOp,
            pendingModifiers: pendingModifiers,
            errored: errored
        )
    }

    private func pushSnapshot() {
        undoStack.append(takeSnapshot())
        if undoStack.count > undoLimit {
            undoStack.removeFirst(undoStack.count - undoLimit)
        }
    }

    private func restore(_ s: StateSnapshot) {
        integerEntry     = s.integerEntry
        fractionalEntry  = s.fractionalEntry
        inFractional     = s.inFractional
        history          = s.history
        accumulator      = s.accumulator
        pendingOp        = s.pendingOp
        pendingModifiers = s.pendingModifiers
        errored          = s.errored
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
