import SwiftUI

enum MindMarginTheme {
    static let background = Color(hex: 0xFAFBFC)
    static let card = Color.white
    static let border = Color.black.opacity(0.08)
    static let textPrimary = Color(hex: 0x1A1A2E)
    static let textSecondary = Color(hex: 0x6B7280)
    static let textTertiary = Color(hex: 0x9CA3AF)

    static let indigo = Color(hex: 0x5B6EF5)
    static let indigoLight = Color(hex: 0x7C8CFA)
    static let indigoDark = Color(hex: 0x4556E6)
    static let teal = Color(hex: 0x14B8A6)
    static let blue = Color(hex: 0x3B82F6)
    static let green = Color(hex: 0x10B981)
    static let yellow = Color(hex: 0xF59E0B)
    static let orange = Color(hex: 0xF97316)
    static let red = Color(hex: 0xEF4444)

    static let lowRiskBackground = Color(hex: 0xECFDF5)
    static let moderateRiskBackground = Color(hex: 0xFEF3C7)
    static let highRiskBackground = Color(hex: 0xFEE2E2)

    static let heroGradient = LinearGradient(
        colors: [indigo, indigoLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardGradient = LinearGradient(
        colors: [indigo.opacity(0.08), indigoLight.opacity(0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Color {
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
