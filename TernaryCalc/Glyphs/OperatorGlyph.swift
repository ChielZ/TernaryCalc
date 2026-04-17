import SwiftUI

/// Operator and special-key glyphs. All shapes are drawn within a normalized
/// 1×1 box and stroked by an outer view that supplies the line width.
enum OperatorGlyph: Hashable {
    case plus
    case xRight
    case xLeft
    case invert
    case flip
    case clear       // square outline
    case backspace   // chevron `<`
    case point
    case equals
}

struct OperatorShape: Shape {
    let glyph: OperatorGlyph

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let xo = rect.midX - side / 2
        let yo = rect.midY - side / 2

        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: xo + x * side, y: yo + y * side)
        }

        var p = Path()
        switch glyph {
        case .plus:
            // Vertical and horizontal arms, ~56% of box.
            p.move(to: P(0.5, 0.22)); p.addLine(to: P(0.5, 0.78))
            p.move(to: P(0.22, 0.5)); p.addLine(to: P(0.78, 0.5))

        case .xRight:
            // Shaft + open triangle pointing right.
            p.move(to: P(0.20, 0.5)); p.addLine(to: P(0.62, 0.5))
            p.move(to: P(0.62, 0.36))
            p.addLine(to: P(0.84, 0.5))
            p.addLine(to: P(0.62, 0.64))
            p.closeSubpath()

        case .xLeft:
            p.move(to: P(0.80, 0.5)); p.addLine(to: P(0.38, 0.5))
            p.move(to: P(0.38, 0.36))
            p.addLine(to: P(0.16, 0.5))
            p.addLine(to: P(0.38, 0.64))
            p.closeSubpath()

        case .invert:
            // Four arms pointing inward + horizontal-axis diamond at center.
            let outer: CGFloat = 0.18
            let inner: CGFloat = 0.36
            // arms
            p.move(to: P(outer, 0.5)); p.addLine(to: P(inner, 0.5))
            p.move(to: P(1 - outer, 0.5)); p.addLine(to: P(1 - inner, 0.5))
            p.move(to: P(0.5, outer)); p.addLine(to: P(0.5, inner))
            p.move(to: P(0.5, 1 - outer)); p.addLine(to: P(0.5, 1 - inner))
            // diamond (long axis horizontal)
            p.move(to: P(inner, 0.5))
            p.addLine(to: P(0.5, 0.5 - 0.10))
            p.addLine(to: P(1 - inner, 0.5))
            p.addLine(to: P(0.5, 0.5 + 0.10))
            p.closeSubpath()

        case .flip:
            // Same as invert but with diamond's long axis vertical.
            let outer: CGFloat = 0.18
            let inner: CGFloat = 0.36
            p.move(to: P(outer, 0.5)); p.addLine(to: P(inner, 0.5))
            p.move(to: P(1 - outer, 0.5)); p.addLine(to: P(1 - inner, 0.5))
            p.move(to: P(0.5, outer)); p.addLine(to: P(0.5, inner))
            p.move(to: P(0.5, 1 - outer)); p.addLine(to: P(0.5, 1 - inner))
            // diamond (long axis vertical)
            p.move(to: P(0.5, inner))
            p.addLine(to: P(0.5 + 0.10, 0.5))
            p.addLine(to: P(0.5, 1 - inner))
            p.addLine(to: P(0.5 - 0.10, 0.5))
            p.closeSubpath()

        case .backspace:
            // Open chevron `<`.
            p.move(to: P(0.78, 0.22))
            p.addLine(to: P(0.22, 0.5))
            p.addLine(to: P(0.78, 0.78))

        case .clear:
            // Square outline.
            let m: CGFloat = 0.22
            p.addRect(CGRect(x: xo + m * side, y: yo + m * side,
                             width: (1 - 2 * m) * side, height: (1 - 2 * m) * side))

        case .point:
            // Small ring.
            let r: CGFloat = 0.08
            p.addEllipse(in: CGRect(x: xo + (0.5 - r) * side, y: yo + (0.5 - r) * side,
                                    width: 2 * r * side, height: 2 * r * side))

        case .equals:
            // Two horizontal bars.
            p.move(to: P(0.22, 0.38)); p.addLine(to: P(0.78, 0.38))
            p.move(to: P(0.22, 0.62)); p.addLine(to: P(0.78, 0.62))
        }
        return p
    }
}

/// Renders an OperatorGlyph in a square area with a stroke width derived
/// from a design fraction.
struct OperatorGlyphView: View {
    let glyph: OperatorGlyph
    var color: Color = .black
    var strokeFraction: CGFloat = 100.0 / 1600.0

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let lineWidth = side * strokeFraction
            OperatorShape(glyph: glyph)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
