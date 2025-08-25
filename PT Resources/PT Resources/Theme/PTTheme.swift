//
//  PTTheme.swift
//  PT Resources
//
//  Theme configuration following Proclamation Trust brand guidelines
//

import SwiftUI

// MARK: - Brand Colors

extension Color {
    // Primary Brand Colors
    static let ptNavy = Color(red: 0.11, green: 0.16, blue: 0.24)           // #1C2A3D
    static let ptCoral = Color(red: 0.95, green: 0.35, blue: 0.24)          // #F35A3D
    
    // Supporting Colors
    static let ptRoyalBlue = Color(red: 0.22, green: 0.31, blue: 0.67)      // #384FAB
    static let ptTurquoise = Color(red: 0.11, green: 0.67, blue: 0.76)      // #1CABC2
    static let ptGreen = Color(red: 0.13, green: 0.69, blue: 0.58)          // #21B094
    
    // Neutral Colors
    static let ptLightGray = Color(red: 0.97, green: 0.97, blue: 0.97)      // #F7F7F7
    static let ptMediumGray = Color(red: 0.85, green: 0.85, blue: 0.85)     // #D9D9D9
    static let ptDarkGray = Color(red: 0.31, green: 0.31, blue: 0.31)       // #4F4F4F
    
    // Semantic Colors
    static let ptBackground = Color.ptLightGray
    static let ptSurface = Color.white
    static let ptPrimary = Color.ptNavy
    static let ptSecondary = Color.ptCoral
    static let ptAccent = Color.ptTurquoise
    static let ptSuccess = Color.ptGreen
}

// MARK: - Typography

struct PTFont {
    // Font Sizes
    static let largeTitle: CGFloat = 34
    static let title1: CGFloat = 28
    static let title2: CGFloat = 22
    static let title3: CGFloat = 20
    static let headline: CGFloat = 17
    static let body: CGFloat = 17
    static let callout: CGFloat = 16
    static let subheadline: CGFloat = 15
    static let footnote: CGFloat = 13
    static let caption1: CGFloat = 12
    static let caption2: CGFloat = 11
    
    // Font Weights
    static func system(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .system(size: size, weight: weight, design: .default)
    }
    
    // Branded Typography (fallback system)
    static let brandTitle = Font.system(size: title1, weight: .bold, design: .default)
    static let sectionTitle = Font.system(size: title2, weight: .semibold, design: .default)
    static let cardTitle = Font.system(size: headline, weight: .semibold, design: .default)
    static let cardSubtitle = Font.system(size: subheadline, weight: .medium, design: .default)
    static let bodyText = Font.system(size: body, weight: .regular, design: .default)
    static let captionText = Font.system(size: caption1, weight: .medium, design: .default)
    
    // These will be overridden by authentic PT fonts in PTTypography.swift if available
}

// MARK: - Spacing

struct PTSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    
    // Component Specific
    static let cardPadding: CGFloat = md
    static let cardSpacing: CGFloat = md
    static let sectionSpacing: CGFloat = lg
    static let screenPadding: CGFloat = md
}

// MARK: - Corner Radius

struct PTCornerRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let extraLarge: CGFloat = 24
    
    // Component Specific
    static let card: CGFloat = medium
    static let button: CGFloat = small
    static let sheet: CGFloat = large
}

// MARK: - Shadows

struct PTShadow {
    static let light = Shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    static let medium = Shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    static let heavy = Shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Modifiers

struct PTCardStyle: ViewModifier {
    let isPressed: Bool
    
    init(isPressed: Bool = false) {
        self.isPressed = isPressed
    }
    
    func body(content: Content) -> some View {
        content
            .background(Color.ptSurface)
            .cornerRadius(PTCornerRadius.card)
            .shadow(color: Color.black.opacity(isPressed ? 0.05 : 0.1), 
                   radius: isPressed ? 4 : 8, 
                   x: 0, 
                   y: isPressed ? 2 : 4)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isPressed)
    }
}

struct PTPrimaryButton: ViewModifier {
    let isPressed: Bool
    
    init(isPressed: Bool = false) {
        self.isPressed = isPressed
    }
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(.white)
            .padding(.horizontal, PTSpacing.lg)
            .padding(.vertical, PTSpacing.md)
            .background(Color.ptSecondary)
            .cornerRadius(PTCornerRadius.button)
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isPressed)
    }
}

struct PTSecondaryButton: ViewModifier {
    let isPressed: Bool
    
    init(isPressed: Bool = false) {
        self.isPressed = isPressed
    }
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(.ptPrimary)
            .padding(.horizontal, PTSpacing.lg)
            .padding(.vertical, PTSpacing.md)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: PTCornerRadius.button)
                    .stroke(Color.ptPrimary, lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isPressed)
    }
}

// MARK: - View Extensions

extension View {
    func ptCardStyle(isPressed: Bool = false) -> some View {
        self.modifier(PTCardStyle(isPressed: isPressed))
    }
    
    func ptPrimaryButton(isPressed: Bool = false) -> some View {
        self.modifier(PTPrimaryButton(isPressed: isPressed))
    }
    
    func ptSecondaryButton(isPressed: Bool = false) -> some View {
        self.modifier(PTSecondaryButton(isPressed: isPressed))
    }
}