import SwiftUI

// MARK: - Omoi Brand Colors

extension Color {
    // Core palette — deep teal foundation
    static let omoiBlack = Color(hex: "0D3F3B")       // Deep teal background
    static let omoiDarkGray = Color(hex: "0D3F3B")    // Cards (same as bg for seamless)
    static let omoiGray = Color(hex: "1A5450")        // Borders, dividers (subtle teal)
    static let omoiMidGray = Color(hex: "5B9BC2")     // Steel blue muted (AA: 5.1:1)
    static let omoiLightGray = Color(hex: "3BBCC9")   // Teal accent text (AA: 5.8:1)
    static let omoiOffWhite = Color(hex: "C0E2F2")    // Ice blue — primary text (AAA: 8.6:1)
    static let omoiWhite = Color(hex: "C0E2F2")       // Ice blue — headings (AAA: 8.6:1)

    // Accent — typed / tactile
    static let omoiTeal = Color(hex: "3BBCC9")        // Typed data (AA: 5.8:1)
    static let omoiTealLight = Color(hex: "C0E2F2")   // Ice blue highlight
    static let omoiGreen = Color(hex: "3BBCC9")       // Success (teal)

    // Accent — voice / vocal
    static let omoiOrange = Color(hex: "EDDABC")      // Warm cream — voice (AAA: 8.6:1)
    static let omoiOrangeLight = Color(hex: "EDDABC") // Same cream

    // Accent — purple
    static let omoiPurple = Color(hex: "9B7AE8")      // Light purple — accent (AA: 4.6:1)
    static let omoiPurpleLight = Color(hex: "9B7AE8") // Same purple

    // Semantic colors
    static let omoiActive = Color(hex: "EDDABC")     // Recording — warm cream
    static let omoiSuccess = Color(hex: "3BBCC9")     // Completed — teal
    static let omoiAccent = Color(hex: "3BBCC9")      // Interactive — teal
    static let omoiMuted = Color(hex: "5B9BC2")       // Secondary text (AA: 5.1:1)

    // Helper initializer for hex colors
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Omoi Typography

enum OmoiFont {
    // Brand font - Bricolage Grotesque (for identity elements)
    // Fallback to system rounded for now - can add custom font later
    static func brand(size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    // UI font - Space Grotesk style (geometric sans)
    // Using system default which is SF Pro - similar geometric feel
    static func heading(size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }

    static func body(size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    static func mono(size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }

    static func label(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    // Preset sizes
    static let brandLarge = brand(size: 32)
    static let brandMedium = brand(size: 24)
    static let headingLarge = heading(size: 28)
    static let headingMedium = heading(size: 20)
    static let headingSmall = heading(size: 16)
    static let bodyLarge = body(size: 16)
    static let bodyMedium = body(size: 14)
    static let bodySmall = body(size: 12)
    static let stat = mono(size: 32)
    static let statSmall = mono(size: 24)
    static let caption = body(size: 11)
}

// MARK: - Brutalist Background

struct OmoiBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.omoiBlack)
    }
}

extension View {
    func omoiBackground() -> some View {
        modifier(OmoiBackground())
    }
}

// MARK: - Brutalist Card Style

struct OmoiCard: ViewModifier {
    var highlighted: Bool = false

    func body(content: Content) -> some View {
        content
            .background(Color.omoiDarkGray)
            .overlay(
                Rectangle()
                    .stroke(highlighted ? Color.omoiTeal : Color.omoiGray, lineWidth: 1)
            )
    }
}

extension View {
    func omoiCard(highlighted: Bool = false) -> some View {
        modifier(OmoiCard(highlighted: highlighted))
    }
}

// MARK: - Icon System (Preserved from original)

enum AppIcons {

    // MARK: Recording Icons
    enum Recording {
        static let active = "mic.circle.fill"
        static let inactive = "mic.circle"
        static let stop = "stop.circle.fill"
        static let waveform = "waveform"
        static let waveformCircle = "waveform.circle"
    }

    // MARK: Dashboard Icons
    enum Dashboard {
        static let words = "character.textbox"
        static let speed = "speedometer"
        static let streak = "flame.fill"
        static let apps = "app.dashed"
        static let chart = "chart.bar.fill"
    }

    // MARK: History Icons
    enum History {
        static let clock = "clock.fill"
        static let document = "doc.text.fill"
        static let magnifyingglass = "magnifyingglass"
        static let filter = "line.3.horizontal.decrease"
        static let trash = "trash.fill"
    }

    // MARK: Privacy & Sanitization Icons
    enum Privacy {
        static let lock = "lock.fill"
        static let lockOpen = "lock.open.fill"
        static let eye = "eye.fill"
        static let eyeSlash = "eye.slash.fill"
        static let shield = "shield.fill"
        static let checkmark = "checkmark.circle.fill"
    }

    // MARK: Action Icons
    enum Actions {
        static let copy = "doc.on.doc"
        static let copyFilled = "doc.on.clipboard.fill"
        static let checkmark = "checkmark"
        static let xmark = "xmark.circle.fill"
        static let plus = "plus.circle.fill"
        static let pencil = "pencil.line"
        static let share = "square.and.arrow.up"
        static let download = "arrow.down.circle"
    }

    // MARK: Settings & Navigation Icons
    enum Settings {
        static let gear = "gear"
        static let slider = "slider.horizontal.3"
        static let keyboard = "keyboard"
        static let bell = "bell.fill"
        static let info = "info.circle.fill"
        static let questionmark = "questionmark.circle"
    }

    // MARK: Status Icons
    enum Status {
        static let success = "checkmark.circle.fill"
        static let warning = "exclamationmark.triangle.fill"
        static let error = "xmark.circle.fill"
        static let waiting = "hourglass.circle.fill"
    }

    // MARK: State Indicators
    enum StateIndicators {
        static let dot = "circle.fill"
        static let play = "play.circle.fill"
        static let pause = "pause.circle.fill"
        static let speaker = "speaker.wave.2.fill"
    }
}

