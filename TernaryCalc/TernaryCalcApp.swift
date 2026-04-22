//
//  TernaryCalcApp.swift
//  TernaryCalc
//
//  Created by Chiel Zwinkels on 16/04/2026.
//

import SwiftUI

@main
struct TernaryCalcApp: App {
    // Persisted palette selection. Stored as the raw string so `@AppStorage`
    // can handle it directly. The settings screen writes the same key.
    @AppStorage("palette") private var paletteRaw = TernaryPalette.primary.rawValue
    @AppStorage("displayMode") private var displayModeRaw = TernaryDisplayMode.triTrit.rawValue
    @AppStorage("showPowerOps") private var showPowerOps = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.ternaryTheme, theme)
                .environment(\.ternaryDisplayMode, displayMode)
                .environment(\.showPowerOps, showPowerOps)
        }
    }

    private var theme: TernaryTheme {
        let palette = TernaryPalette(rawValue: paletteRaw) ?? .primary
        return TernaryTheme.forPalette(palette)
    }

    private var displayMode: TernaryDisplayMode {
        TernaryDisplayMode(rawValue: displayModeRaw) ?? .triTrit
    }
}
