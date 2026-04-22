import SwiftUI

/// Operator and special-key glyphs. All are constructed in the same 1400-unit
/// design box as the trit glyphs so the `/`, `|`, `\` primitives and the
/// composite glyphs share stroke width, line length, and diagonal angles.
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
    case powRight    // backspace mirrored + short vertical bar at tips
    case powLeft     // backspace + short vertical bar at tips
    case logRight    // backspace mirrored + short horizontal bar from tips
    case logLeft     // backspace + short horizontal bar from tips
}

/// Where a point glyph's ring is placed vertically within its frame.
enum PointPlacement: Hashable {
    case centered                // keypad key
    case baseline(CGFloat)       // display: y-fraction of the frame height at
                                 // which the ring's bottom edge should land
}

private let designBox: CGFloat = 1400

struct OperatorShape: Shape {
    let glyph: OperatorGlyph

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let xo = rect.midX - side / 2
        let yo = rect.midY - side / 2

        // P(dx, dy) takes coordinates in 1400-unit design space and maps into
        // the square `side × side` region centered on `rect`.
        func P(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint {
            CGPoint(x: xo + (dx / designBox) * side,
                    y: yo + (dy / designBox) * side)
        }

        var p = Path()
        switch glyph {
        case .plus:
            // `|` + 90°-rotated `|` superimposed.
            p.move(to: P(700, 100));  p.addLine(to: P(700, 1300))
            p.move(to: P(100, 700));  p.addLine(to: P(1300, 700))

        case .xRight:
            // Left half of `<` + vertical base at x=700 + left half of shaft.
            p.move(to: P(1300, 700)); p.addLine(to: P(700, 500))
            p.move(to: P(1300, 700)); p.addLine(to: P(700, 900))
            p.move(to: P(700, 500));  p.addLine(to: P(700, 900))
            p.move(to: P(100, 700));  p.addLine(to: P(700, 700))

        case .xLeft:
            // Mirror of xRight.
            p.move(to: P(100, 700));  p.addLine(to: P(700, 500))
            p.move(to: P(100, 700));  p.addLine(to: P(700, 900))
            p.move(to: P(700, 500));  p.addLine(to: P(700, 900))
            p.move(to: P(700, 700));  p.addLine(to: P(1300, 700))

        case .flip:
            // Horizontal diamond (4 arms from left & right apexes) + the
            // vertical `|` running through its center. The vertical bar IS
            // the zero-trit glyph — flip's fixed point is zero, so the
            // operator is literally labelled by the value it leaves alone.
            p.move(to: P(100, 700));  p.addLine(to: P(700, 500))
            p.move(to: P(100, 700));  p.addLine(to: P(700, 900))
            p.move(to: P(1300, 700)); p.addLine(to: P(700, 500))
            p.move(to: P(1300, 700)); p.addLine(to: P(700, 900))
            p.move(to: P(700, 100));  p.addLine(to: P(700, 1300))

        case .invert:
            // Vertical diamond (4 arms from top & bottom apexes) + a
            // horizontal bar running through its center. The horizontal bar
            // stands in for "one absolute" — invert's fixed point is one,
            // mirroring the flip-zero relationship.
            p.move(to: P(700, 100));  p.addLine(to: P(500, 700))
            p.move(to: P(700, 100));  p.addLine(to: P(900, 700))
            p.move(to: P(700, 1300)); p.addLine(to: P(500, 700))
            p.move(to: P(700, 1300)); p.addLine(to: P(900, 700))
            p.move(to: P(100, 700));  p.addLine(to: P(1300, 700))

        case .backspace:
            // `<`: two arms from a left apex to the right edge, joined at
            // tips. Matches the trit diagonal angle rotated 90°.
            p.move(to: P(100, 700));  p.addLine(to: P(1300, 300))
            p.move(to: P(100, 700));  p.addLine(to: P(1300, 1100))

        case .powLeft:
            // Backspace V (apex left) + short vertical bar bridging the two
            // tips on the right — "power" is the vertical stroke.
            p.move(to: P(100, 700));  p.addLine(to: P(1300, 300))
            p.move(to: P(100, 700));  p.addLine(to: P(1300, 1100))
            p.move(to: P(1300, 560)); p.addLine(to: P(1300, 840))

        case .powRight:
            // Mirrored backspace V (apex right) + short vertical bar at tips.
            p.move(to: P(1300, 700)); p.addLine(to: P(100, 300))
            p.move(to: P(1300, 700)); p.addLine(to: P(100, 1100))
            p.move(to: P(100, 560));  p.addLine(to: P(100, 840))

        case .logLeft:
            // Backspace V + short horizontal bar extending from the tip
            // midpoint inward toward the apex — "log" is the horizontal stroke.
            p.move(to: P(100, 700));  p.addLine(to: P(1300, 300))
            p.move(to: P(100, 700));  p.addLine(to: P(1300, 1100))
            p.move(to: P(1019, 700)); p.addLine(to: P(1300, 700))

        case .logRight:
            // Mirrored backspace V + short horizontal bar from tips inward.
            p.move(to: P(1300, 700)); p.addLine(to: P(100, 300))
            p.move(to: P(1300, 700)); p.addLine(to: P(100, 1100))
            p.move(to: P(100, 700));  p.addLine(to: P(381, 700))

        case .clear:
            // Square outline — four `|`-length sides. Round stroke caps at
            // the corners overlap into smooth quarter-circles.
            p.move(to: P(100, 100));   p.addLine(to: P(1300, 100))
            p.move(to: P(1300, 100));  p.addLine(to: P(1300, 1300))
            p.move(to: P(1300, 1300)); p.addLine(to: P(100, 1300))
            p.move(to: P(100, 1300));  p.addLine(to: P(100, 100))

        case .equals:
            // Two horizontal `|`s separated by a 3×stroke gap (edge-to-edge);
            // centers are 4×stroke apart, i.e. y = 500 and y = 900.
            p.move(to: P(100, 500));  p.addLine(to: P(1300, 500))
            p.move(to: P(100, 900));  p.addLine(to: P(1300, 900))

        case .point:
            // Rendered separately by OperatorGlyphView → PointGlyph so the
            // ring's dimensions stay tied to the chosen stroke width.
            break
        }
        return p
    }
}

struct OperatorGlyphView: View {
    let glyph: OperatorGlyph
    var color: Color = .black
    var strokeFraction: CGFloat = 100.0 / 1400.0
    var pointPlacement: PointPlacement = .centered

    var body: some View {
        if glyph == .point {
            PointGlyph(color: color,
                       strokeFraction: strokeFraction,
                       placement: pointPlacement)
                .aspectRatio(1, contentMode: .fit)
        } else {
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                let lineWidth = side * strokeFraction
                OperatorShape(glyph: glyph)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth,
                                                       lineCap: .round,
                                                       lineJoin: .round))
            }
            .aspectRatio(1, contentMode: .fit)
        }
    }
}
