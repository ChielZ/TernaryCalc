import CoreGraphics

enum Trit: Int, Hashable, CaseIterable {
    case neg  = -1
    case zero =  0
    case pos  =  1
}

enum TritGlyphMetrics {
    static let boxSize: CGFloat       = 1400
    static let yTop: CGFloat          =  100
    static let yBottom: CGFloat       = 1300
    static let halfDiagonal: CGFloat  =  200
    static let unitSpacing: CGFloat   =  200
    static let strokeWidth: CGFloat   =   60
}

extension Trit {
    /// Additive inverse: +1 ↔ -1, 0 stays 0.
    var flipped: Trit {
        switch self {
        case .neg:  return .pos
        case .zero: return .zero
        case .pos:  return .neg
        }
    }

    var horizontalExtent: CGFloat {
        self == .zero ? 0 : TritGlyphMetrics.halfDiagonal
    }

    /// Top endpoint x relative to the trit's center column.
    var topOffset: CGFloat {
        switch self {
        case .zero: return 0
        case .pos:  return  TritGlyphMetrics.halfDiagonal
        case .neg:  return -TritGlyphMetrics.halfDiagonal
        }
    }

    /// Bottom endpoint x relative to the trit's center column.
    var bottomOffset: CGFloat {
        switch self {
        case .zero: return 0
        case .pos:  return -TritGlyphMetrics.halfDiagonal
        case .neg:  return  TritGlyphMetrics.halfDiagonal
        }
    }
}

/// Spacing between two adjacent trits (left then right, in display order).
/// `/\` shares its top apex; `\/` shares its bottom apex; both spread to 400.
/// All other pairs draw at the standard 200-unit pitch.
func tritPairSpacing(left: Trit, right: Trit) -> CGFloat {
    let unit = TritGlyphMetrics.unitSpacing
    switch (left, right) {
    case (.pos, .neg), (.neg, .pos): return 2 * unit
    default:                         return unit
    }
}

/// Center-x of each trit in the design coord system, with the visual extent
/// of the whole group horizontally centered around `center`.
func tritCenters(_ trits: [Trit], center: CGFloat = TritGlyphMetrics.boxSize / 2) -> [CGFloat] {
    guard let first = trits.first, let last = trits.last else { return [] }
    var xs: [CGFloat] = [0]
    for i in 1..<trits.count {
        xs.append(xs[i - 1] + tritPairSpacing(left: trits[i - 1], right: trits[i]))
    }
    let visualLeft  = xs.first! - first.horizontalExtent
    let visualRight = xs.last!  + last.horizontalExtent
    let dx = center - (visualLeft + visualRight) / 2
    return xs.map { $0 + dx }
}

/// Convert an integer to its balanced-ternary trit sequence (most-significant
/// trit first). The natural sequence has no leading zeros — use `padded` if a
/// fixed length is required.
enum BalancedTernaryConversion {
    static func trits(forInteger value: Int) -> [Trit] {
        if value == 0 { return [.zero] }
        var trits: [Trit] = []
        var n = value
        while n != 0 {
            let r = ((n % 3) + 3) % 3   // 0, 1, or 2
            switch r {
            case 0:
                trits.insert(.zero, at: 0); n /= 3
            case 1:
                trits.insert(.pos, at: 0);  n = (n - 1) / 3
            default:
                trits.insert(.neg, at: 0);  n = (n + 1) / 3
            }
        }
        return trits
    }

    static func padded(_ trits: [Trit], toLength length: Int) -> [Trit] {
        guard trits.count < length else { return trits }
        return Array(repeating: .zero, count: length - trits.count) + trits
    }
}
