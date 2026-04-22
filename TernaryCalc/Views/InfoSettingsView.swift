import SwiftUI

/// The sheet presented when the `i` button above the calculator is tapped.
/// Hosts the app's info text (to be filled in later) and any user-tunable
/// settings. Changes persist across launches via `@AppStorage`.
struct InfoSettingsView: View {
    @AppStorage("palette") private var paletteRaw = TernaryPalette.primary.rawValue
    @AppStorage("displayMode") private var displayModeRaw = TernaryDisplayMode.triTrit.rawValue
    @AppStorage("showPowerOps") private var showPowerOps = false
    @Environment(\.dismiss) private var dismiss

    private var selectedPalette: Binding<TernaryPalette> {
        Binding(
            get: { TernaryPalette(rawValue: paletteRaw) ?? .primary },
            set: { paletteRaw = $0.rawValue }
        )
    }

    private var selectedMode: Binding<TernaryDisplayMode> {
        Binding(
            get: { TernaryDisplayMode(rawValue: displayModeRaw) ?? .triTrit },
            set: { displayModeRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("About") {
                    Text("Info text goes here — to be added.")
                        .foregroundStyle(.secondary)
                }
                Section("Mode") {
                    Picker("Number system", selection: selectedMode) {
                        ForEach(TernaryDisplayMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    Toggle("Show power operations", isOn: $showPowerOps)
                }
                Section("Appearance") {
                    Picker("Colour scheme", selection: selectedPalette) {
                        ForEach(TernaryPalette.allCases) { palette in
                            Text(palette.displayName).tag(palette)
                        }
                    }
                }
            }
            .navigationTitle("Info & Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    InfoSettingsView()
}
