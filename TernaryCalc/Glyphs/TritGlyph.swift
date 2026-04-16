import SwiftUI

/// Shape that renders a sequence of trits within a rect, scaled to fit while
/// preserving the design aspect ratio (1400×1400 design units per slot).
struct TritGroupShape: Shape {
    let trits: [Trit]
    let designWidth: CGFloat = TritGlyphMetrics.boxSize

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !trits.isEmpty else { return path }
        let m = TritGlyphMetrics.self
        let scale = min(rect.width / designWidth, rect.height / m.boxSize)
        let drawnW = designWidth * scale
        let drawnH = m.boxSize * scale
        let xOffset = rect.midX - drawnW / 2
        let yOffset = rect.midY - drawnH / 2
        let centers = tritCenters(trits, center: designWidth / 2)
        let yTop = yOffset + m.yTop * scale
        let yBot = yOffset + m.yBottom * scale
        for (i, trit) in trits.enumerated() {
            let cx = centers[i]
            let topX = xOffset + (cx + trit.topOffset)    * scale
            let botX = xOffset + (cx + trit.bottomOffset) * scale
            path.move(to:    CGPoint(x: topX, y: yTop))
            path.addLine(to: CGPoint(x: botX, y: yBot))
        }
        return path
    }
}

/// View that renders a trit sequence as a stroked group, with line width
/// scaled from the design coords. `slots` gives the number of tri-trit-wide
/// slots the glyph should occupy (default 1). `strokeFraction` overrides the
/// default stroke thickness — keys use a thicker fraction than display numbers.
struct TritGroupView: View {
    let trits: [Trit]
    var color: Color = .black
    var slots: CGFloat = 1
    var strokeFraction: CGFloat = TritGlyphMetrics.strokeWidth / TritGlyphMetrics.boxSize

    var body: some View {
        GeometryReader { geo in
            let designWidth = TritGlyphMetrics.boxSize * slots
            let scale = min(geo.size.width / designWidth, geo.size.height / TritGlyphMetrics.boxSize)
            let lineWidth = TritGlyphMetrics.boxSize * strokeFraction * scale
            TritGroupShape(trits: trits)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
        .aspectRatio(slots * TritGlyphMetrics.boxSize / TritGlyphMetrics.boxSize, contentMode: .fit)
    }
}

/// Renders an integer value's stripped (no leading zeros) glyph in a single
/// tri-trit-wide slot.
struct StrippedValueGlyph: View {
    let value: Int
    var color: Color = .black
    var body: some View {
        TritGroupView(trits: BalancedTernaryConversion.trits(forInteger: value), color: color)
    }
}

/// Renders an integer as a row of tri-trit slot glyphs:
/// the leading tri-trit shows the stripped form (no leading zeros), every
/// trailing tri-trit shows its full 3-trit form so place value is preserved.
struct IntegerNumberGlyph: View {
    let value: Int
    var color: Color = .black

    private var triTrits: [[Trit]] {
        let raw = BalancedTernaryConversion.trits(forInteger: value)
        let padCount = (3 - raw.count % 3) % 3
        let padded = Array(repeating: Trit.zero, count: padCount) + raw
        var groups: [[Trit]] = []
        for start in stride(from: 0, to: padded.count, by: 3) {
            groups.append(Array(padded[start..<start + 3]))
        }
        if let leading = groups.first {
            var stripped = leading
            while stripped.count > 1, stripped.first == .zero { stripped.removeFirst() }
            groups[0] = stripped
        }
        return groups
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(triTrits.enumerated()), id: \.offset) { _, trits in
                TritGroupView(trits: trits, color: color)
            }
        }
    }
}
