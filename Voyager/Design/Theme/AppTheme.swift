import SwiftUI

// MARK: - Color Palette
//
// Voyager palette: Deep Sage Teal + Warm Amber
//   Primary deep  #1A6B6A  — rich teal, confident & grounding
//   Primary mid   #2A9D8F  — sage teal, fresh & soothing
//   Accent        #E9A84C  — warm amber, energetic & inviting
//   Background    #F5F2EE  — warm cream, softer than iOS grey
//   Surface alt   #EDE9E3  — gentle sand tone

extension Color {
    // Primary — deep sage teal
    static let voyagerPrimary      = Color(hex: "#1A6B6A")
    static let voyagerPrimaryLight = Color(hex: "#2A9D8F")
    // Accent — warm amber
    static let voyagerAccent       = Color(hex: "#E9A84C")
    // Surfaces — warm cream tones
    static let voyagerBackground   = Color(hex: "#F5F2EE")
    static let voyagerSurface      = Color(hex: "#FFFFFF")
    static let voyagerSurfaceAlt   = Color(hex: "#EDE9E3")
    // Text
    static let voyagerTextPrimary  = Color(hex: "#1C2827")
    static let voyagerTextSecondary = Color(hex: "#6B7B78")
    // Semantic
    static let voyagerSuccess      = Color(hex: "#3AAA7A")
    static let voyagerWarning      = Color(hex: "#E9A84C")
    static let voyagerError        = Color(hex: "#E05D5D")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - Typography

struct AppFont {
    // Display
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    // Headings
    static let h1: Font = .system(size: 32, weight: .bold)
    static let h2: Font = .system(size: 24, weight: .bold)
    static let h3: Font = .system(size: 20, weight: .semibold)
    static let h4: Font = .system(size: 17, weight: .semibold)
    // Body
    static let bodyLarge: Font  = .system(size: 17, weight: .regular)
    static let body: Font       = .system(size: 15, weight: .regular)
    static let bodySmall: Font  = .system(size: 13, weight: .regular)
    // Label
    static let label: Font      = .system(size: 12, weight: .medium)
    static let caption: Font    = .system(size: 11, weight: .regular)
}

// MARK: - Spacing

struct AppSpacing {
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius

struct AppRadius {
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 12
    static let lg:  CGFloat = 16
    static let xl:  CGFloat = 24
    static let full: CGFloat = 999
}

// MARK: - Shadows

extension View {
    func cardShadow() -> some View {
        self.shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
    func softShadow() -> some View {
        self.shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}
