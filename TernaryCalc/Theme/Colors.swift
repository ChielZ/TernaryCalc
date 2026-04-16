import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
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
}

private struct TernaryThemeKey: EnvironmentKey {
    static let defaultValue = TernaryTheme.default
}

extension EnvironmentValues {
    var ternaryTheme: TernaryTheme {
        get { self[TernaryThemeKey.self] }
        set { self[TernaryThemeKey.self] = newValue }
    }
}
