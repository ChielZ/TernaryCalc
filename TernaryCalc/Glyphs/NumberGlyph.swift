import SwiftUI

/// Decimal-point dot — a small ring glyph (matches the SVG operator dot).
struct PointGlyph: View {
    var color: Color = .black

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let radius = side * 0.07
            let lineWidth = side * 0.04
            Circle()
                .strokeBorder(color, lineWidth: lineWidth)
                .frame(width: radius * 2, height: radius * 2)
                .position(x: geo.size.width / 2, y: geo.size.height - radius - lineWidth)
        }
    }
}

/// Render a number's integer part as a row of tri-trit glyphs:
/// the leading (most-significant) tri-trit shows the stripped form (no
/// leading zeros), all remaining tri-trits show their full 3-trit form so
/// place value is preserved.
struct IntegerPartGlyph: View {
    let trits: [Trit]
    var color: Color = .black

    private var slots: [[Trit]] {
        let raw = trits.isEmpty ? [.zero] : trits
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

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(slots.enumerated()), id: \.offset) { _, trits in
                TritGroupView(trits: trits, color: color)
            }
        }
    }
}

/// Render a number's fractional part: tri-trit groups starting from position
/// -1, with the right-most group possibly truncated to fewer than 3 trits.
struct FractionalPartGlyph: View {
    let trits: [Trit]
    var color: Color = .black

    private var slots: [[Trit]] {
        guard !trits.isEmpty else { return [] }
        var groups: [[Trit]] = []
        var i = 0
        while i < trits.count {
            let end = min(i + 3, trits.count)
            groups.append(Array(trits[i..<end]))
            i += 3
        }
        return groups
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(slots.enumerated()), id: \.offset) { _, trits in
                TritGroupView(trits: trits, color: color)
            }
        }
    }
}

/// Render a complete number (integer + optional decimal point + optional
/// fractional). If `displayTrits.fractional` is empty, no point or fractional
/// section is shown.
struct NumberGlyph: View {
    let display: DisplayTrits
    var color: Color = .black

    var body: some View {
        HStack(spacing: 0) {
            IntegerPartGlyph(trits: display.integer, color: color)
            if !display.fractional.isEmpty {
                PointGlyph(color: color)
                    .aspectRatio(1.0/3.0, contentMode: .fit)
                FractionalPartGlyph(trits: display.fractional, color: color)
            }
        }
    }
}
