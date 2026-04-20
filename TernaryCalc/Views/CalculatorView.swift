import SwiftUI

struct CalculatorView: View {
    @ObservedObject var state: CalculatorState
    let metrics: CalculatorMetrics
    @Environment(\.ternaryTheme) private var theme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: metrics.calcCorner, style: .continuous)
                .fill(theme.calculatorBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: metrics.calcCorner, style: .continuous)
                        .strokeBorder(theme.calculatorFrameStroke, lineWidth: metrics.calcStroke)
                )

            VStack(spacing: metrics.panelGap) {
                DisplayView(state: state, metrics: metrics)
                KeypadView(state: state, metrics: metrics)
            }
            .padding(metrics.outerPadding)
        }
        .frame(width: metrics.calcWidth, height: metrics.calcHeight)
    }
}

struct InfoButton: View {
    let size: CGFloat
    @Environment(\.ternaryTheme) private var theme
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(theme.calculatorBackground,
                                  lineWidth: size * 0.08)
                Text("i")
                    .font(.custom("Comfortaa", size: size * 0.7))
                    .foregroundStyle(theme.calculatorBackground)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Info")
    }
}
