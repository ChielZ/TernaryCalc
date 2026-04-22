import SwiftUI

struct ContentView: View {
    @StateObject private var state = CalculatorState()
    @Environment(\.ternaryTheme) private var theme
    @Environment(\.ternaryDisplayMode) private var displayMode
    @Environment(\.showPowerOps) private var showPowerOps
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            // Background follows the active screen: black for the settings
            // (so the flat settings palette reads cleanly) and the active
            // theme background otherwise. Either way it extends under the
            // notch and home indicator.
            (showingSettings ? SettingsColors.background : theme.appBackground)
                .ignoresSafeArea()

            if showingSettings {
                SettingsView(state: state) { showingSettings = false }
            } else {
                GeometryReader { proxy in
                    let size = proxy.size
                    // Reserve symmetric top/bottom room — sized off the
                    // shorter side of the screen rather than its width, so
                    // the amount of vertical margin is consistent across
                    // portrait and landscape.
                    let shortSide = min(size.width, size.height)
                    let reserve = shortSide * CalcLayout.verticalReserveRatio
                    let avail = CGSize(width: size.width,
                                       height: max(1, size.height - 2 * reserve))
                    let maxCalcWidth = shortSide * CalcLayout.maxCalcWidthRatio
                    let keypadRows = showPowerOps ? 4 : 3
                    let metrics = CalculatorMetrics.fit(into: avail,
                                                        maxCalcWidth: maxCalcWidth,
                                                        keypadRows: keypadRows)
                    let infoSize = metrics.calcWidth * CalcLayout.infoButtonRatio
                    let infoGap  = metrics.outerPadding

                    ZStack {
                        CalculatorView(state: state, metrics: metrics)
                            .position(x: size.width / 2, y: size.height / 2)

                        InfoButton(size: infoSize) { showingSettings = true }
                        .position(x: size.width / 2,
                                  y: size.height / 2 - metrics.calcHeight / 2 - 2 * infoGap - infoSize / 2)
                    }
                    .frame(width: size.width, height: size.height)
                }
            }
        }
        .statusBarHidden(true)
        // View-side animation: triggers reliably on `@AppStorage` changes
        // (where `withAnimation` doesn't, because the binding write happens
        // outside the SwiftUI render cycle).
        .animation(.easeInOut(duration: 0.0), value: showingSettings)
        .animation(.easeInOut(duration: 0.0), value: showPowerOps)
        .onAppear { state.setDisplayMode(displayMode) }
        .onChange(of: displayMode) { _, new in state.setDisplayMode(new) }
    }
}

#Preview {
    ContentView()
}
