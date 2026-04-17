import SwiftUI

enum KeyContent: Hashable {
    case trit(Trit)
    case op(OperatorGlyph)
}

struct KeypadView: View {
    @ObservedObject var state: CalculatorState
    let metrics: CalculatorMetrics
    @Environment(\.ternaryTheme) private var theme

    private let layout: [[KeyContent]] = [
        [.trit(.pos),  .op(.xRight), .op(.invert), .op(.clear)],
        [.trit(.zero), .op(.plus),   .op(.flip),   .op(.backspace)],
        [.trit(.neg),  .op(.xLeft),  .op(.point),  .op(.equals)]
    ]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: metrics.panelCorner, style: .continuous)
                .fill(theme.keypadBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: metrics.panelCorner, style: .continuous)
                        .strokeBorder(theme.keypadFrameStroke, lineWidth: metrics.panelStroke)
                )
            grid
                .padding(metrics.keypadInnerPadding)
        }
        .frame(width: metrics.panelWidth, height: metrics.keypadHeight)
    }

    private var grid: some View {
        VStack(spacing: metrics.keyGap) {
            ForEach(0..<3) { row in
                HStack(spacing: metrics.keyGap) {
                    ForEach(0..<4) { col in
                        keyButton(layout[row][col])
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keyButton(_ content: KeyContent) -> some View {
        Button(action: { handleTap(content) }) {
            ZStack {
                RoundedRectangle(cornerRadius: metrics.keyCorner, style: .continuous)
                    .fill(theme.keyBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: metrics.keyCorner, style: .continuous)
                            .strokeBorder(theme.keyStroke, lineWidth: metrics.keyStroke)
                    )
                glyph(content)
                    .padding(metrics.keySize * 0.18)
            }
            .frame(width: metrics.keySize, height: metrics.keySize)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func glyph(_ content: KeyContent) -> some View {
        switch content {
        case .trit(let t):
            TritGroupView(trits: [t],
                          color: theme.keyDigit,
                          strokeFraction: 100.0 / 1400.0)
        case .op(let g):
            OperatorGlyphView(glyph: g, color: theme.keyDigit)
        }
    }

    private func handleTap(_ content: KeyContent) {
        switch content {
        case .trit(let t):  state.type(t)
        case .op(let g):
            switch g {
            case .plus:    state.operation(.add)
            case .xRight:  state.operation(.xRight)
            case .xLeft:   state.operation(.xLeft)
            case .invert:    state.invert()
            case .flip:      state.flip()
            case .clear:     state.clear()
            case .backspace: state.backspace()
            case .point:     state.point()
            case .equals:    state.equals()
            }
        }
    }
}
