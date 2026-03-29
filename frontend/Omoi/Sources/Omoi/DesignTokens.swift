import SwiftUI

/// Design Tokens: Single source of truth for visual consistency across Omoi
/// Eliminates magic numbers and ensures coordinated design decisions
enum DesignTokens {

    // MARK: - Spacing
    /// All spacing values for consistent layouts
    enum Spacing {
        static let xs: CGFloat = 4      // Compact spacing (rare)
        static let sm: CGFloat = 8      // Small (input padding, etc.)
        static let md: CGFloat = 12     // Medium (default spacing)
        static let lg: CGFloat = 16     // Large (component spacing)
        static let xl: CGFloat = 20     // Extra large (section spacing)
        static let xxl: CGFloat = 24    // Double extra large (major sections)
    }

    // MARK: - Corner Radius
    /// Corner radius values for consistent roundedness
    enum CornerRadius {
        static let sm: CGFloat = 6      // Input fields, small buttons
        static let md: CGFloat = 12     // Cards, sections
        static let lg: CGFloat = 16     // Large containers, premium cards
    }

    // MARK: - Shadows
    /// Shadow definitions for depth and hierarchy
    enum Shadow {
        // Subtle shadow for small, secondary elements
        static let subtle = (
            color: Color.black.opacity(0.1),
            radius: CGFloat(4),
            x: CGFloat(0),
            y: CGFloat(2)
        )

        // Standard shadow for primary cards and containers
        static let standard = (
            color: Color.black.opacity(0.2),
            radius: CGFloat(10),
            x: CGFloat(0),
            y: CGFloat(5)
        )

        // Strong shadow for emphasis (HUD, modals)
        static let strong = (
            color: Color.black.opacity(0.3),
            radius: CGFloat(15),
            x: CGFloat(0),
            y: CGFloat(8)
        )
    }

    // MARK: - Animation Timing
    /// Durations for consistent animation feel
    enum Timing {
        static let fast: Double = 0.15      // Quick micro-interactions (button press)
        static let normal: Double = 0.30    // Standard transitions
        static let slow: Double = 0.50      // Intro/outro sequences
    }

    // MARK: - Typography Sizes
    /// Standard text sizes for hierarchy
    enum Typography {
        // Large values for emphasis
        static let pageTitle: CGFloat = 32  // Main headers
        static let cardValue: CGFloat = 28  // Stats values

        // Standard sizes
        static let sectionTitle: CGFloat = 18
        static let body: CGFloat = 16
        static let label: CGFloat = 14
        static let caption: CGFloat = 12
        static let micro: CGFloat = 10
    }

    // MARK: - Component Sizing
    /// Standard sizes for UI elements
    enum Component {
        // Button sizing
        static let buttonHeight: CGFloat = 40
        static let compactButtonHeight: CGFloat = 32

        // Icon sizing
        static let iconSmall: CGFloat = 16
        static let iconMedium: CGFloat = 20
        static let iconLarge: CGFloat = 24
        static let iconXLarge: CGFloat = 28

        // Window dimensions
        static let mainWindowWidth: CGFloat = 500
        static let mainWindowHeight: CGFloat = 630
        static let settingsWindowWidth: CGFloat = 400
        static let settingsWindowHeight: CGFloat = 280
        static let menuBarHeight: CGFloat = 500

        // Card dimensions
        static let statCardMinHeight: CGFloat = 120
        static let historyRowHeight: CGFloat = 60
        static let historyRowCompactHeight: CGFloat = 44
    }

    // MARK: - Opacity Values
    /// Consistent opacity for semantic meaning
    enum Opacity {
        static let disabled: Double = 0.5      // Disabled state
        static let secondary: Double = 0.7     // Secondary text
        static let hover: Double = 0.15        // Hover tint
        static let divider: Double = 0.2       // Divider lines
        static let overlay: Double = 0.85      // Semi-opaque overlay (HUD)
    }

    // MARK: - Commonly Used Modifiers
    /// Pre-built ViewModifiers for common patterns

    /// Standard card shadow + blur effect
    static func cardShadow() -> AnyView {
        AnyView(
            EmptyView()
                .shadow(
                    color: Color.black.opacity(0.2),
                    radius: 10,
                    x: 0,
                    y: 5
                )
        )
    }

    /// Default card background with glass effect
    static func cardBackground() -> some View {
        RoundedRectangle(cornerRadius: CornerRadius.lg)
            .fill(.ultraThinMaterial)
            .stroke(Color.white.opacity(0.2), lineWidth: 1)
    }
}

// MARK: - View Extensions for Token Usage

extension View {
    /// Apply standard card styling (background + shadow)
    func cardStyle() -> some View {
        self
            .background(DesignTokens.cardBackground())
            .shadow(
                color: DesignTokens.Shadow.standard.color,
                radius: DesignTokens.Shadow.standard.radius,
                x: DesignTokens.Shadow.standard.x,
                y: DesignTokens.Shadow.standard.y
            )
    }

    /// Apply subtle shadow for secondary elements
    func subtleShadow() -> some View {
        self.shadow(
            color: DesignTokens.Shadow.subtle.color,
            radius: DesignTokens.Shadow.subtle.radius,
            x: DesignTokens.Shadow.subtle.x,
            y: DesignTokens.Shadow.subtle.y
        )
    }

    /// Apply standard container padding
    func containerPadding(_ edges: Edge.Set = .all) -> some View {
        self.padding(edges, DesignTokens.Spacing.md)
    }

    /// Apply tight/compact spacing
    func compactPadding(_ edges: Edge.Set = .all) -> some View {
        self.padding(edges, DesignTokens.Spacing.sm)
    }

    /// Apply generous spacing (sections)
    func generousPadding(_ edges: Edge.Set = .all) -> some View {
        self.padding(edges, DesignTokens.Spacing.lg)
    }
}
