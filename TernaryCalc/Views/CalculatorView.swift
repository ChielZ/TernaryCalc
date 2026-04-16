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
            Image(systemName: "info.circle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .foregroundStyle(theme.calculatorBackground)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Info")
    }
}
