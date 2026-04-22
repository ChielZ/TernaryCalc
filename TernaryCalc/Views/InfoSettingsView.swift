import SwiftUI

// MARK: - Settings UI fixed colors

/// Fixed colors for the settings screen — independent of the active palette
/// so the settings UI looks the same whichever calc theme is in use.
enum SettingsColors {
    static let foreground = Color(hex: 0xECD9AF)
    static let background = Color.black
}

// MARK: - Flat controls

/// Sliding pill toggle, no system chrome. Animation is driven by the
/// consumer via `.animation(_:value:)` on the underlying value — that's
/// reliable across `@AppStorage` writes (which `withAnimation` is not).
struct FlatToggleStyle: ToggleStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 26)
                Circle()
                    .fill(color)
                    .frame(width: 22, height: 22)
                    .padding(2)
            }
            .onTapGesture { configuration.isOn.toggle() }
        }
    }
}

/// Segmented picker that's just a row of tappable cells with two static
/// background opacities — selected vs unselected. No system styling.
struct FlatPicker<T: Hashable>: View {
    @Binding var selection: T
    let options: [(value: T, label: String)]
    let color: Color

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                Text(option.label)
                    .font(.custom("Comfortaa", size: 14))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        selection == option.value
                            ? color.opacity(0.25)
                            : color.opacity(0.08)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { selection = option.value }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @AppStorage("palette") private var paletteRaw = TernaryPalette.primary.rawValue
    @AppStorage("displayMode") private var displayModeRaw = TernaryDisplayMode.simple.rawValue
    @AppStorage("showPowerOps") private var showPowerOps = false

    @Environment(\.ternaryTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass

    @ObservedObject var state: CalculatorState
    let onClose: () -> Void

    private let uiFg = SettingsColors.foreground

    private var selectedPalette: Binding<TernaryPalette> {
        Binding(
            get: { TernaryPalette(rawValue: paletteRaw) ?? .primary },
            set: { paletteRaw = $0.rawValue }
        )
    }

    private var selectedMode: Binding<TernaryDisplayMode> {
        Binding(
            get: { TernaryDisplayMode(rawValue: displayModeRaw) ?? .simple },
            set: { displayModeRaw = $0.rawValue }
        )
    }

    var body: some View {
        Group {
            if sizeClass == .regular {
                // iPad: side-by-side
                HStack(spacing: 0) {
                    leftPanel.frame(maxWidth: .infinity)
                    Rectangle()
                        .fill(uiFg.opacity(0.15))
                        .frame(width: 1)
                    rightPanel.frame(maxWidth: .infinity)
                }
            } else {
                // iPhone: stacked, scrollable
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        calcPreview
                        controlsContent(compact: true)
                        rightPanel
                    }
                }
            }
        }
        .font(.custom("Comfortaa", size: 16))
        .foregroundStyle(uiFg)
        .tint(uiFg)
        .animation(.easeInOut(duration: 0.1), value: showPowerOps)
    }

    // MARK: Calc preview

    /// Live mini calculator on the active palette's background. Tap to
    /// close the settings screen.
    private var calcPreview: some View {
        let rows = showPowerOps ? 4 : 3
        let previewWidth: CGFloat = 120
        let avail = CGSize(width: previewWidth, height: .infinity)
        let metrics = CalculatorMetrics.fit(
            into: avail,
            maxCalcWidth: previewWidth,
            keypadRows: rows
        )

        return ZStack {
            theme.appBackground
            CalculatorView(state: state, metrics: metrics)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
        .frame(height: metrics.calcHeight + 24)
        .contentShape(Rectangle())
        .onTapGesture { onClose() }
    }

    // MARK: iPad left panel

    private var leftPanel: some View {
        VStack(spacing: 0) {
            calcPreview.frame(maxHeight: .infinity)
            controlsContent(compact: false)
        }
        .ignoresSafeArea()
    }

    // MARK: Controls

    private func controlsContent(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 24 : 20) {
            Text("Colour scheme")
            FlatPicker(
                selection: selectedPalette,
                options: [
                    (TernaryPalette.primary,   "Default"),
                    (TernaryPalette.secondary, "Inverted"),
                ],
                color: uiFg
            )

            Text("Number system")
            FlatPicker(
                selection: selectedMode,
                options: [
                    (TernaryDisplayMode.simple,  "Pure ternary"),
                    (TernaryDisplayMode.triTrit, "Tri-ternary"),
                ],
                color: uiFg
            )

            Toggle("Show power operations", isOn: $showPowerOps)
                .toggleStyle(FlatToggleStyle(color: uiFg))

            Text("tap calculator to close settings screen")
                .font(.custom("Comfortaa", size: 14))
                .foregroundStyle(uiFg.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(24)
    }

    // MARK: Info text

    private var rightPanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                Text("Ternary Calculator")
                    .font(.custom("Comfortaa", size: 24).weight(.bold))
                    .padding(.bottom, 4)

                Text("Info text goes here — to be added.")
                    .font(.custom("Comfortaa", size: 16))
                    .lineSpacing(16 * 0.1)
                    .opacity(0.7)
            }
            .padding(24)
        }
    }
}
