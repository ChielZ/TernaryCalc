import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

/// Identifier for the selectable colour palettes. Picked via the settings
/// screen and persisted via `@AppStorage`; the concrete colour values live
/// on `TernaryTheme` below.
enum TernaryPalette: String, CaseIterable, Identifiable {
    case primary
    case secondary

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .primary:   return "Default"
        case .secondary: return "Inverted"
        }
    }
}

/// Display/entry mode. `.triTrit` is the canonical design — 3-trit groups act
/// as base-27 digits with the promote-model entry. `.simple` flattens the
/// system: each typed trit is one positional base-3 digit and the display
/// shows a flat sequence of `/`, `|`, `\` glyphs with no grouping.
enum TernaryDisplayMode: String, CaseIterable, Identifiable {
    case triTrit = "triTrit"
    case simple  = "simple"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .triTrit: return "Tri-ternary"
        case .simple:  return "Pure ternary"
        }
    }

    /// How many glyph columns fit in a display row in this mode. Tri-trit
    /// packs 3 trits per slot into 6 slots; simple keeps the trit glyph at
    /// tri-trit size (so each trit is visually as tall/bold as in tri-trit
    /// mode) and lays them out at a wider pitch — which caps the row at
    /// fewer trits than the `rowCapacity · 3 = 18` a naive scale-down
    /// would allow.
    var rowCapacity: Int {
        switch self {
        case .triTrit: return 6
        case .simple:  return 12
        }
    }
}

struct TernaryTheme {
    var appBackground          = Color(hex: 0x88ACA2)
    var calculatorFrameStroke  = Color(hex: 0x000000)
    var calculatorBackground   = Color(hex: 0x000000)
    var keypadFrameStroke      = Color(hex: 0xECD9AF)
    var keypadBackground       = Color(hex: 0xF08537)
    var keyStroke              = Color(hex: 0xECD9AF)
    var keyBackground          = Color(hex: 0x000000)
    var keyDigit               = Color(hex: 0xECD9AF)
    var displayFrameStroke     = Color(hex: 0xF08537)
    var displayBackground      = Color(hex: 0xECD9AF)
    var displayDigit           = Color(hex: 0x000000)
    var displayOperator        = Color(hex: 0x000000)
    var displayOperatorOpacity = 0.33
    
    

    static let `default` = TernaryTheme()

    /// Primary palette — the original design-spec colours. Uses the struct's
    /// default values declared above; edit those to change the primary.
    static let primary = TernaryTheme()

    /// Secondary palette — every field listed explicitly so each colour can
    /// be tweaked in place. Initial values are a straight copy of primary;
    /// change any hex literal (or replace with a different `Color`) to
    /// distinguish the two schemes.
    static let secondary = TernaryTheme(
        appBackground:          Color(hex: 0xF08537),
        calculatorFrameStroke:  Color(hex: 0xECD9AF),
        calculatorBackground:   Color(hex: 0xECD9AF),
        keypadFrameStroke:      Color(hex: 0x000000),
        keypadBackground:       Color(hex: 0x88ACA2),
        keyStroke:              Color(hex: 0x000000),
        keyBackground:          Color(hex: 0xECD9AF),
        keyDigit:               Color(hex: 0x000000),
        displayFrameStroke:     Color(hex: 0x88ACA2),
        displayBackground:      Color(hex: 0x000000),
        displayDigit:           Color(hex: 0xECD9AF),
        displayOperator:        Color(hex: 0xECD9AF),
        displayOperatorOpacity: 0.33
    )

    static func forPalette(_ palette: TernaryPalette) -> TernaryTheme {
        switch palette {
        case .primary:   return .primary
        case .secondary: return .secondary
        }
    }
}

private struct TernaryThemeKey: EnvironmentKey {
    static let defaultValue = TernaryTheme.default
}

private struct TernaryDisplayModeKey: EnvironmentKey {
    static let defaultValue: TernaryDisplayMode = .simple
}

private struct ShowPowerOpsKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var ternaryTheme: TernaryTheme {
        get { self[TernaryThemeKey.self] }
        set { self[TernaryThemeKey.self] = newValue }
    }

    var ternaryDisplayMode: TernaryDisplayMode {
        get { self[TernaryDisplayModeKey.self] }
        set { self[TernaryDisplayModeKey.self] = newValue }
    }

    var showPowerOps: Bool {
        get { self[ShowPowerOpsKey.self] }
        set { self[ShowPowerOpsKey.self] = newValue }
    }
}
