import SwiftUI

/// Decimal-point / ring glyph. Line width is `strokeFraction × frame height`
/// — intentionally tied to the frame *height* (not its short side) so the
/// ring's stroke matches the trit stroke at the given size. The inner
/// opening diameter equals the line width (per design spec), which fixes the
/// ring's outer diameter at 3 × line width.
struct PointGlyph: View {
    var color: Color = .black
    var strokeFraction: CGFloat = TritGlyphMetrics.strokeWidth / TritGlyphMetrics.boxSize
    var placement: PointPlacement = .centered

    var body: some View {
        GeometryReader { geo in
            let refHeight = geo.size.height
            let lineWidth = refHeight * strokeFraction
            let r = 1.5 * lineWidth                // → inner ∅ = 1 × lineWidth
            let cx = geo.size.width / 2
            let cy: CGFloat = {
                switch placement {
                case .centered:
                    return geo.size.height / 2
                case .baseline(let b):
                    // Outer edge of the ring sits on the baseline.
                    return geo.size.height * b - r
                }
            }()
            Circle()
                .strokeBorder(color, lineWidth: lineWidth)
                .frame(width: 2 * r, height: 2 * r)
                .position(x: cx, y: cy)
        }
    }
}

/// One row of `maxSlots` fixed-size tri-trit slots, right-aligned. Empty
/// leading slots are blank. A decimal-point glyph sits on the boundary
/// between the integer and fractional slots without consuming a slot.
struct FixedNumberRow: View {
    let display: DisplayTrits
    let slotSize: CGFloat
    var color: Color = .black
    var maxSlots: Int = 6
    var strokeFraction: CGFloat = TritGlyphMetrics.strokeWidth / TritGlyphMetrics.boxSize

    private var integerSlots: [[Trit]] {
        let raw = display.integer.isEmpty ? [Trit.zero] : display.integer
        let padCount = (3 - raw.count % 3) % 3
        let padded = Array(repeating: Trit.zero, count: padCount) + raw
        var groups: [[Trit]] = []
        for start in stride(from: 0, to: padded.count, by: 3) {
            groups.append(Array(padded[start..<start + 3]))
        }
        if var leading = groups.first {
            while leading.count > 1, leading.first == .zero { leading.removeFirst() }
            groups[0] = leading
        }
        return groups
    }

    private var fractionalSlots: [[Trit]] {
        guard !display.fractional.isEmpty else { return [] }
        var groups: [[Trit]] = []
        var i = 0
        while i < display.fractional.count {
            let end = min(i + 3, display.fractional.count)
            groups.append(Array(display.fractional[i..<end]))
            i += 3
        }
        return groups
    }

    var body: some View {
        let ints  = integerSlots
        let fracs = fractionalSlots
        // When the decimal is shown but no fractional tri-trits exist yet
        // (user just pressed `.`), reserve one slot's worth of space to the
        // right of the integer so the decimal has somewhere to sit.
        let reservePlaceholder = display.showDecimal && fracs.isEmpty
        let used  = ints.count + fracs.count + (reservePlaceholder ? 1 : 0)
        let empty = max(0, maxSlots - used)
        let pointFrameW = slotSize * 0.4
        let boundaryX = slotSize * CGFloat(empty + ints.count)

        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                ForEach(0..<empty, id: \.self) { _ in
                    Color.clear.frame(width: slotSize, height: slotSize)
                }
                ForEach(ints.indices, id: \.self) { i in
                    TritGroupView(trits: ints[i], color: color, strokeFraction: strokeFraction)
                        .frame(width: slotSize, height: slotSize)
                }
                ForEach(fracs.indices, id: \.self) { i in
                    TritGroupView(trits: fracs[i], color: color, strokeFraction: strokeFraction)
                        .frame(width: slotSize, height: slotSize)
                }
                if reservePlaceholder {
                    Color.clear.frame(width: slotSize, height: slotSize)
                }
            }
            if display.showDecimal {
                PointGlyph(color: color,
                           strokeFraction: strokeFraction,
                           placement: .centered)
                    .frame(width: pointFrameW, height: slotSize)
                    .offset(x: boundaryX - pointFrameW / 2)
            }
        }
        .frame(width: slotSize * CGFloat(maxSlots), height: slotSize, alignment: .leading)
    }
}

/// Overflow row — rendered when an operation produces a value that won't fit.
/// Each of the six tri-trit slots draws `///` overlaid with `\\\` so every
/// trit position reads as an `X`, keeping the row in the same stroke / slot
/// language as the number rows.
struct OverflowRow: View {
    let slotSize: CGFloat
    var color: Color = .black
    var maxSlots: Int = 6
    var strokeFraction: CGFloat = TritGlyphMetrics.strokeWidth / TritGlyphMetrics.boxSize

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<maxSlots, id: \.self) { _ in
                ZStack {
                    TritGroupView(trits: [.pos, .pos, .pos],
                                  color: color,
                                  strokeFraction: strokeFraction)
                    TritGroupView(trits: [.neg, .neg, .neg],
                                  color: color,
                                  strokeFraction: strokeFraction)
                }
                .frame(width: slotSize, height: slotSize)
            }
        }
        .frame(width: slotSize * CGFloat(maxSlots), height: slotSize)
    }
}

/// Compute a DisplayTrits that fits `maxSlots` tri-trit slots — truncating
/// the fractional expansion (re-running the from-below conversion at a
/// shorter precision) whenever the integer eats into the space available.
/// Returns nil if even the integer alone doesn't fit.
enum DisplayFit {
    static func fit(_ value: BalancedTernary, maxSlots: Int = 6) -> DisplayTrits? {
        guard let initial = value.toDisplayTrits(maxFractionalTrits: maxSlots * 3) else { return nil }
        let intSlots = triTritCount(initial.integer)
        if intSlots > maxSlots { return nil }
        let availableFracTrits = max(0, (maxSlots - intSlots) * 3)
        if initial.fractional.count <= availableFracTrits {
            return initial
        }
        guard let shorter = value.toDisplayTrits(maxFractionalTrits: availableFracTrits) else { return nil }
        if triTritCount(shorter.integer) > maxSlots { return nil }
        return shorter
    }

    static func triTritCount(_ trits: [Trit]) -> Int {
        trits.isEmpty ? 0 : (trits.count + 2) / 3
    }
}
