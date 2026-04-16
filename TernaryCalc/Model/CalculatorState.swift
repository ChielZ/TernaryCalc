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

/// One row in the running display history. Either a finished number (the
/// previous operand or a result) or the operator that connects two numbers.
enum DisplayRow: Hashable {
    case number(DisplayTrits)
    case op(OperatorGlyph)
    case error
}

final class CalculatorState: ObservableObject {
    /// Trits the user is currently typing for the integer part, in input order
    /// (the first typed trit ends up in the most-significant position once
    /// further trits are appended on its right).
    @Published private(set) var integerEntry:    [Trit] = []
    @Published private(set) var fractionalEntry: [Trit] = []
    @Published private(set) var inFractional: Bool = false

    /// History of finished rows, oldest first. The display will show a
    /// trailing window of these.
    @Published private(set) var history: [DisplayRow] = []

    /// Running accumulator (the left operand of any pending op), and the
    /// pending operator if any.
    @Published private(set) var accumulator: BalancedTernary? = nil
    @Published private(set) var pendingOp:   BinaryOp?        = nil

    /// True while an overflow / divide-by-zero error is on screen; the next
    /// keypress (other than Clear) is ignored.
    @Published private(set) var errored: Bool = false

    // MARK: - Derived

    /// Display rendition of the in-progress entry, or nil if nothing is being
    /// typed (the entry slot is conceptually empty).
    var entryDisplay: DisplayTrits? {
        if integerEntry.isEmpty && fractionalEntry.isEmpty && !inFractional {
            return nil
        }
        let intTrits = integerEntry.isEmpty ? [Trit.zero] : strippedLeading(integerEntry)
        let fracTrits = strippedTrailing(fractionalEntry)
        return DisplayTrits(integer: intTrits, fractional: fracTrits)
    }

    /// True if there is no in-progress entry.
    var entryIsEmpty: Bool {
        integerEntry.isEmpty && fractionalEntry.isEmpty && !inFractional
    }

    // MARK: - Key actions

    func type(_ trit: Trit) {
        if errored { return }
        if inFractional {
            fractionalEntry.append(trit)
        } else {
            integerEntry.append(trit)
        }
    }

    /// Tab pads the current (leftmost incomplete) tri-trit with `|`s.
    /// For the integer side, padding goes on the most-significant side
    /// (leading zeros). For the fractional side, padding goes on the
    /// least-significant side (trailing zeros within the current tri-trit).
    func tab() {
        if errored { return }
        if inFractional {
            let lenMod = fractionalEntry.count % 3
            let needed = lenMod == 0 ? 3 : (3 - lenMod)
            fractionalEntry.append(contentsOf: Array(repeating: .zero, count: needed))
        } else {
            let lenMod = integerEntry.count % 3
            let needed = lenMod == 0 ? 3 : (3 - lenMod)
            integerEntry = Array(repeating: .zero, count: needed) + integerEntry
        }
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
        errored = false
    }

    func flip() {
        if errored { return }
        if !entryIsEmpty {
            integerEntry    = integerEntry.map(Self.mirror)
            fractionalEntry = fractionalEntry.map(Self.mirror)
        } else if let acc = accumulator {
            accumulator = acc.flipped
            replaceLastNumberRow(with: acc.flipped)
        }
    }

    func invert() {
        if errored { return }
        if let value = currentEntryValue() {
            switch value.inverted {
            case .success(let v): replaceEntry(with: v)
            case .failure:        markError()
            }
        } else if let acc = accumulator {
            switch acc.inverted {
            case .success(let v):
                accumulator = v
                replaceLastNumberRow(with: v)
            case .failure: markError()
            }
        }
    }

    func operation(_ op: BinaryOp) {
        if errored { return }
        guard let value = commitEntryAsValue() else {
            // No fresh entry — just update pendingOp if accumulator is set.
            if accumulator != nil { pendingOp = op }
            return
        }
        if let acc = accumulator, let p = pendingOp {
            let result: Result<BalancedTernary, BalancedTernary.OperationError>
            switch p {
            case .add:    result = acc.adding(value)
            case .xRight: result = acc.xRight(value)
            case .xLeft:  result = acc.xLeft(value)
            }
            switch result {
            case .success(let r):
                accumulator = r
                appendRow(.number(displayFor(value)))
                appendRow(.op(op.glyph))
            case .failure: markError(); return
            }
        } else {
            accumulator = value
            appendRow(.number(displayFor(value)))
            appendRow(.op(op.glyph))
        }
        pendingOp = op
    }

    func equals() {
        if errored { return }
        guard let value = commitEntryAsValue() else { return }
        if let acc = accumulator, let p = pendingOp {
            let result: Result<BalancedTernary, BalancedTernary.OperationError>
            switch p {
            case .add:    result = acc.adding(value)
            case .xRight: result = acc.xRight(value)
            case .xLeft:  result = acc.xLeft(value)
            }
            switch result {
            case .success(let r):
                accumulator = r
                appendRow(.number(displayFor(value)))
                appendRow(.op(.equals))
                appendRow(.number(displayFor(r)))
            case .failure: markError(); return
            }
        } else {
            accumulator = value
            appendRow(.number(displayFor(value)))
        }
        pendingOp = nil
    }


    // MARK: - Helpers

    private static func mirror(_ t: Trit) -> Trit {
        switch t {
        case .pos: return .neg
        case .neg: return .pos
        case .zero: return .zero
        }
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

    private func commitEntryAsValue() -> BalancedTernary? {
        guard let v = currentEntryValue() else { return nil }
        integerEntry.removeAll()
        fractionalEntry.removeAll()
        inFractional = false
        return v
    }

    private func displayFor(_ value: BalancedTernary) -> DisplayTrits {
        value.toDisplayTrits() ?? DisplayTrits(integer: [.zero], fractional: [])
    }

    private func appendRow(_ row: DisplayRow) {
        history.append(row)
    }

    private func replaceLastNumberRow(with value: BalancedTernary) {
        if let idx = history.lastIndex(where: { if case .number = $0 { return true } else { return false } }) {
            history[idx] = .number(displayFor(value))
        }
    }

    private func replaceEntry(with value: BalancedTernary) {
        let display = displayFor(value)
        integerEntry = display.integer
        fractionalEntry = display.fractional
        inFractional = !display.fractional.isEmpty
    }

    private func markError() {
        appendRow(.error)
        errored = true
    }
}

// MARK: - BalancedTernary from trit-entry

extension BalancedTernary {
    /// Build a BalancedTernary value from MSB-first integer and fractional
    /// trit lists (as produced by the input state). Values that exceed Int
    /// range during conversion return nil → caller should treat as overflow.
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
        // Compute fractional part as p / 3^k.
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
        // value = intValue + fracNum / pow3 = (intValue * pow3 + fracNum) / pow3
        let (intScaled, o4) = intValue.multipliedReportingOverflow(by: pow3)
        if o4 { return nil }
        let (totalNum, o5) = intScaled.addingReportingOverflow(fracNum)
        if o5 { return nil }
        return BalancedTernary.make(numerator: totalNum, denominator: pow3)
    }
}
