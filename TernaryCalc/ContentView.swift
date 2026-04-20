import SwiftUI

struct ContentView: View {
    @StateObject private var state = CalculatorState()
    @Environment(\.ternaryTheme) private var theme
    @Environment(\.ternaryDisplayMode) private var displayMode
    @State private var showingSettings = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            // Reserve symmetric top/bottom room — sized off the shorter side
            // of the screen rather than its width, so the amount of vertical
            // margin is consistent across portrait and landscape.
            let shortSide = min(size.width, size.height)
            let reserve = shortSide * CalcLayout.verticalReserveRatio
            let avail = CGSize(width: size.width,
                               height: max(1, size.height - 2 * reserve))
            let maxCalcWidth = shortSide * CalcLayout.maxCalcWidthRatio
            let metrics = CalculatorMetrics.fit(into: avail, maxCalcWidth: maxCalcWidth)
            let infoSize = metrics.calcWidth * CalcLayout.infoButtonRatio
            let infoGap  = metrics.outerPadding

            ZStack {
                theme.appBackground

                CalculatorView(state: state, metrics: metrics)
                    .position(x: size.width / 2, y: size.height / 2)

                InfoButton(size: infoSize) {
                    showingSettings = true
                }
                .position(x: size.width / 2,
                          y: size.height / 2 - metrics.calcHeight / 2 - 2 * infoGap - infoSize / 2)
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .sheet(isPresented: $showingSettings) {
            InfoSettingsView()
        }
        .onAppear { state.setDisplayMode(displayMode) }
        .onChange(of: displayMode) { _, new in state.setDisplayMode(new) }
    }
}

#Preview {
    ContentView()
}
