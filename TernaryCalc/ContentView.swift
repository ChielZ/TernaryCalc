import SwiftUI

struct ContentView: View {
    @StateObject private var state = CalculatorState()
    @Environment(\.ternaryTheme) private var theme

    var body: some View {
        GeometryReader { proxy in
            let safe = proxy.safeAreaInsets
            let topInset = safe.top + proxy.size.height * CalcLayout.extraTopMarginRatio
            let avail = CGSize(
                width:  max(0, proxy.size.width  - safe.leading - safe.trailing),
                height: max(0, proxy.size.height - topInset    - safe.bottom)
            )
            let metrics = CalculatorMetrics.fit(into: avail)
            let infoSize = metrics.calcWidth * CalcLayout.infoButtonRatio
            let infoGap  = metrics.outerPadding

            ZStack {
                theme.appBackground
                    .ignoresSafeArea()

                VStack(spacing: infoGap) {
                    InfoButton(size: infoSize)
                    CalculatorView(state: state, metrics: metrics)
                }
                .padding(.top, topInset)
                .padding(.bottom, safe.bottom)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }
}

#Preview {
    ContentView()
}
