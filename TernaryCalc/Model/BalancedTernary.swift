import Foundation

/// Exact rational number stored as p/q (denominator > 0, GCD-reduced).
/// Used as the calculator's authoritative value type — display is derived
/// by truncating to the available number of trits "from below" (per the
/// design spec).
struct BalancedTernary: Equatable {
    let numerator: Int
    let denominator: Int

    static let zero = BalancedTernary(rawNumerator: 0, rawDenominator: 1)
    static let one  = BalancedTernary(rawNumerator: 1, rawDenominator: 1)

    enum OperationError: Error {
        case overflow
        case divisionByZero
    }

    private init(rawNumerator: Int, rawDenominator: Int) {
        self.numerator   = rawNumerator
        self.denominator = rawDenominator
    }

    /// Construct from any p/q (q ≠ 0); normalizes sign and reduces by GCD.
    static func make(numerator: Int, denominator: Int) -> BalancedTernary? {
        guard denominator != 0 else { return nil }
        var n = numerator, d = denominator
        if d < 0 {
            // Negate both. Watch for Int.min overflow — extremely unlikely with
            // the values this calculator will produce, but worth being safe.
            guard d != .min, n != .min else { return nil }
            n = -n; d = -d
        }
        let g = gcd(abs(n), d)
        if g > 1 { n /= g; d /= g }
        return BalancedTernary(rawNumerator: n, rawDenominator: d)
    }

    static func from(integer n: Int) -> BalancedTernary {
        BalancedTernary(rawNumerator: n, rawDenominator: 1)
    }
}

private func gcd(_ a: Int, _ b: Int) -> Int {
    var a = abs(a), b = abs(b)
    while b != 0 { (a, b) = (b, a % b) }
    return a == 0 ? 1 : a
}

// MARK: - Operations

extension BalancedTernary {
    func adding(_ other: BalancedTernary) -> Result<BalancedTernary, OperationError> {
        let (ad, o1) = numerator.multipliedReportingOverflow(by: other.denominator)
        let (bc, o2) = other.numerator.multipliedReportingOverflow(by: denominator)
        let (sum, o3) = ad.addingReportingOverflow(bc)
        let (denom, o4) = denominator.multipliedReportingOverflow(by: other.denominator)
        if o1 || o2 || o3 || o4 { return .failure(.overflow) }
        guard let r = BalancedTernary.make(numerator: sum, denominator: denom) else {
            return .failure(.divisionByZero)
        }
        return .success(r)
    }

    /// Standard multiplication. `xRight` is the unmirrored multiplication
    /// where `/` (= +1) acts as identity.
    func xRight(_ other: BalancedTernary) -> Result<BalancedTernary, OperationError> {
        let (p, op) = numerator.multipliedReportingOverflow(by: other.numerator)
        let (q, oq) = denominator.multipliedReportingOverflow(by: other.denominator)
        if op || oq { return .failure(.overflow) }
        guard let r = BalancedTernary.make(numerator: p, denominator: q) else {
            return .failure(.divisionByZero)
        }
        return .success(r)
    }

    /// Mirror multiplication, where `\` (= -1) acts as identity.
    /// xLeft(a, b) = mirror(xRight(a, b)) = xRight(mirror(a), b).
    func xLeft(_ other: BalancedTernary) -> Result<BalancedTernary, OperationError> {
        flipped.xRight(other)
    }

    /// Negation — replaces subtraction.
    var flipped: BalancedTernary {
        BalancedTernary(rawNumerator: -numerator, rawDenominator: denominator)
    }

    /// Multiplicative inverse — replaces division.
    var inverted: Result<BalancedTernary, OperationError> {
        guard numerator != 0 else { return .failure(.divisionByZero) }
        if numerator > 0 {
            return .success(BalancedTernary(rawNumerator: denominator, rawDenominator: numerator))
        } else {
            // Keep denominator positive.
            guard numerator != .min, denominator != .min else { return .failure(.overflow) }
            return .success(BalancedTernary(rawNumerator: -denominator, rawDenominator: -numerator))
        }
    }
}

// MARK: - Display conversion

/// One number's display trits, integer + fractional, with the convention used
/// throughout the app: integer trits are most-significant first; fractional
/// trits are at positions -1, -2, … (in display order, left to right after the
/// decimal point).
struct DisplayTrits: Hashable {
    let integer: [Trit]
    let fractional: [Trit]
}

extension BalancedTernary {
    /// Convert to display trits, truncating the fractional expansion at
    /// `maxFractionalTrits` and approaching the true value from below.
    /// Returns nil on overflow (integer doesn't fit in `maxIntegerTrits`,
    /// or arithmetic overflow during conversion).
    func toDisplayTrits(maxIntegerTrits: Int = 18,
                        maxFractionalTrits: Int = 18) -> DisplayTrits? {
        let p = numerator
        let q = denominator   // already > 0

        // Floor division (toward -∞): Swift's / truncates toward 0.
        let intFloor: Int
        let r0: Int
        if p >= 0 {
            intFloor = p / q
            r0 = p - intFloor * q
        } else {
            let truncQ = p / q
            let truncR = p - truncQ * q              // in (-q, 0]
            if truncR == 0 {
                intFloor = truncQ
                r0 = 0
            } else {
                intFloor = truncQ - 1
                r0 = truncR + q                      // in [0, q)
            }
        }

        // Standard ternary fractional digits (each in {0, 1, 2}).
        var r = r0
        var stdDigits: [Int] = []
        stdDigits.reserveCapacity(maxFractionalTrits)
        for _ in 0..<maxFractionalTrits {
            let (rmul, ovf) = r.multipliedReportingOverflow(by: 3)
            if ovf { return nil }
            let digit = rmul / q
            r = rmul - digit * q
            stdDigits.append(digit)
        }

        // Convert standard digits → balanced trits, with carry propagating
        // from least-significant to most-significant (right to left).
        var fractional: [Trit] = Array(repeating: .zero, count: stdDigits.count)
        var carry = 0
        for k in stride(from: stdDigits.count - 1, through: 0, by: -1) {
            let d = stdDigits[k] + carry
            switch d {
            case 0: fractional[k] = .zero; carry = 0
            case 1: fractional[k] = .pos;  carry = 0
            case 2: fractional[k] = .neg;  carry = 1
            case 3: fractional[k] = .zero; carry = 1
            default: return nil
            }
        }

        let (intWithCarry, ovf) = intFloor.addingReportingOverflow(carry)
        if ovf { return nil }

        let integerTrits = BalancedTernaryConversion.trits(forInteger: intWithCarry)
        if integerTrits.count > maxIntegerTrits { return nil }

        // Strip trailing zero fractional trits.
        while let last = fractional.last, last == .zero {
            fractional.removeLast()
        }

        return DisplayTrits(integer: integerTrits, fractional: fractional)
    }
}
