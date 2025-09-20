//
//  PTTheme.swift
//  PT Resources
//
//  Theme configuration following Proclamation Trust brand guidelines
//

import SwiftUI

// MARK: - PT Brand Colors (Matching Website)

extension Color {
    // Core PT Brand Colors (from website CSS variables)
    static let ptInk = Color(hex: "#07324c")           // --pt-ink
    static let ptTang = Color(hex: "#ff4c23")          // --pt-tang
    static let ptKleinBlue = Color(hex: "#4060ab")     // --pt-klein-blue
    static let ptTurmeric = Color(hex: "#ff921c")      // --pt-turmeric
    static let ptLawn = Color(hex: "#0f9679")          // --pt-lawn
    
    // Legacy colors for gradual migration
    static let legacyBaseColor = Color(hex: "#cdd95f")     // legacy base-color
    static let legacyDarkGray = Color(hex: "#313e3b")      // legacy dark-gray
    static let legacyMediumGray = Color(hex: "#828c8a")    // legacy medium-gray
    static let legacyYellow = Color(hex: "#d5d52c")        // legacy yellow
    static let legacyExtraMediumGray = Color(hex: "#e4e4e4") // legacy extra-medium-gray
    
    // Neutral Colors (matching website design system)
    static let ptLightGray = Color(hex: "#f7f7f7")      // very-light from website
    static let ptMediumGray = Color(hex: "#e4e4e4")     // extra-medium from website
    static let ptDarkGray = Color(hex: "#717580")       // medium from website
    static let ptExtraDark = Color(hex: "#232323")      // dark from website
    
    // Semantic Colors (using PT brand colors)
    static let ptBackground = Color.white               // Clean white background like website
    static let ptSurface = Color.white
    static let ptPrimary = Color.ptInk                  // Primary text/elements
    static let ptSecondary = Color.ptTang               // Accent/CTA color
    static let ptAccent = Color.ptKleinBlue            // Links and secondary actions
    static let ptSuccess = Color.ptLawn                 // Success states
    static let ptWarning = Color.ptTurmeric             // Warning states
    
    // Computed properties for hover/pressed states (matching website behavior)
    static var ptTangHover: Color { Color.ptKleinBlue }  // Tang hovers to Klein Blue on website
    static var ptKleinBlueHover: Color { Color.ptTang }  // Klein Blue hovers to Tang on website
}

// Note: Color hex extension is now defined in PTDesignTokens.swift to avoid duplication

// MARK: - Typography (Matching Website Scale)

struct PTFontSizes {
    // Font Sizes (matching website tailwind.config.js fontSize scale)
    static let text9: CGFloat = 9       // '9': '9px'
    static let text10: CGFloat = 10     // '10': '10px'
    static let text11: CGFloat = 11     // '11': '11px'
    static let text13: CGFloat = 13     // '13': '13px'
    static let text15: CGFloat = 15     // '15': '15px'
    static let text17: CGFloat = 17     // '17': '17px'
    static let text19: CGFloat = 19     // '19': '19px'
    static let text22: CGFloat = 22     // '22': '22px'
    static let text26: CGFloat = 26     // '26': ['26px', '38px']
    static let text28: CGFloat = 28     // '28': ['1.75rem', '2.6rem']
    static let text30: CGFloat = 30     // '30': ['1.875rem', '2.8rem']
    static let text32: CGFloat = 32     // '32': ['2rem', '2.5rem']
    static let text40: CGFloat = 40     // '40': ['2.5rem', '2.5rem']
    static let text45: CGFloat = 45     // '45': ['2.813rem', '3rem']
    static let text50: CGFloat = 50     // '50': ['3.125rem', '3.25rem']
    
    // Standard iOS sizes for fallback
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
    
    // Font system function
    static func system(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .system(size: size, weight: weight, design: .default)
    }
    
    // Legacy branded typography (use PTFont from PTTypography.swift instead)
    static let brandTitle = Font.system(size: text28, weight: .bold, design: .default)      // H1 equivalent
    static let sectionTitle = Font.system(size: text22, weight: .semibold, design: .default) // H2 equivalent  
    static let cardTitle = Font.system(size: text17, weight: .semibold, design: .default)   // H3 equivalent
    static let cardSubtitle = Font.system(size: text15, weight: .medium, design: .default)  // Subtitle
    static let bodyText = Font.system(size: text17, weight: .regular, design: .default)     // Body text
    static let captionText = Font.system(size: text13, weight: .medium, design: .default)   // Caption
    static let buttonText = Font.system(size: text15, weight: .medium, design: .default)    // Button text
    static let smallText = Font.system(size: text13, weight: .regular, design: .default)    // Small text
    
    // Display fonts (large headings)
    static let displayLarge = Font.system(size: text40, weight: .bold, design: .default)
    static let displayMedium = Font.system(size: text32, weight: .bold, design: .default)
    static let displaySmall = Font.system(size: text28, weight: .bold, design: .default)
    
    // These are superseded by authentic PT fonts in PTTypography.swift
}

// MARK: - Spacing (Matching Website Scale)

struct PTSpacing {
    // Base spacing scale (matching website 8px, 16px, 24px increments)
    static let xs: CGFloat = 4      // 4px
    static let sm: CGFloat = 8      // 8px - website base unit
    static let md: CGFloat = 16     // 16px - website standard spacing
    static let lg: CGFloat = 24     // 24px - website section spacing
    static let xl: CGFloat = 32     // 32px - website large spacing
    static let xxl: CGFloat = 48    // 48px - website extra large spacing
    static let xxxl: CGFloat = 64   // 64px - hero sections
    
    // Component Specific (matching website patterns)
    static let cardPadding: CGFloat = lg        // 24px like website cards
    static let cardSpacing: CGFloat = md        // 16px between cards
    static let sectionSpacing: CGFloat = xl     // 32px between sections
    static let screenPadding: CGFloat = md      // 16px screen edges
    static let buttonPadding: CGFloat = 12      // Vertical button padding
    static let buttonPaddingHorizontal: CGFloat = 24  // Horizontal button padding
    
    // Container widths (responsive like website)
    static let maxContentWidth: CGFloat = 1200  // Max content width
    static let containerPadding: CGFloat = md   // Container side padding
}

// MARK: - Corner Radius (Matching Website)

struct PTCornerRadius {
    // Base radius scale (matching website border-radius values)
    static let xs: CGFloat = 2      // 2px - xs from website
    static let small: CGFloat = 6   // 6px - default from website
    static let medium: CGFloat = 8  // calc(var(--radius) - 2px) when --radius is 10px
    static let large: CGFloat = 10  // var(--radius) default
    static let xl: CGFloat = 15     // xl from website
    static let xxl: CGFloat = 20    // 2xl from website
    static let xxxl: CGFloat = 30   // 3xl from website
    static let full: CGFloat = 9999 // full border radius
    
    // Component Specific (matching website component styles)
    static let card: CGFloat = small        // 6px like website cards
    static let button: CGFloat = small      // 6px like website buttons
    static let input: CGFloat = small       // 6px like website inputs
    static let sheet: CGFloat = large       // 10px for modals
    static let image: CGFloat = small       // 6px for images
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

struct PTCardStyleModifier: ViewModifier {
    let isPressed: Bool

    init(isPressed: Bool = false) {
        self.isPressed = isPressed
    }

    func body(content: Content) -> some View {
        content
            .background(Color.ptSurface)
            .cornerRadius(PTDesignTokens.BorderRadius.card)
            .shadow(color: Color.black.opacity(isPressed ? 0.05 : 0.1),
                   radius: isPressed ? 4 : 8,
                   x: 0,
                   y: isPressed ? 2 : 4)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isPressed)
    }
}

struct PTPrimaryButtonStyle: ViewModifier {
    let isPressed: Bool
    let isDisabled: Bool
    
    init(isPressed: Bool = false, isDisabled: Bool = false) {
        self.isPressed = isPressed
        self.isDisabled = isDisabled
    }
    
    func body(content: Content) -> some View {
        content
            .font(PTFontSizes.buttonText)
            .foregroundColor(isDisabled ? .white.opacity(0.7) : .white)
            .padding(.horizontal, PTDesignTokens.Spacing.buttonPaddingHorizontal)
            .padding(.vertical, PTDesignTokens.Spacing.buttonPaddingVertical)
            .background(
                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                    .fill(buttonBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                            .stroke(buttonBorderColor, lineWidth: 2)
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isPressed)
            .opacity(isDisabled ? 0.6 : 1.0)
    }
    
    private var buttonBackgroundColor: Color {
        if isDisabled { return Color.ptTang.opacity(0.5) }
        if isPressed { return Color.clear }
        return Color.ptTang
    }
    
    private var buttonBorderColor: Color {
        if isDisabled { return Color.ptTang.opacity(0.5) }
        return Color.ptTang
    }
}

struct PTSecondaryButtonStyle: ViewModifier {
    let isPressed: Bool
    let isDisabled: Bool
    
    init(isPressed: Bool = false, isDisabled: Bool = false) {
        self.isPressed = isPressed
        self.isDisabled = isDisabled
    }
    
    func body(content: Content) -> some View {
        content
            .font(PTFontSizes.buttonText)
            .foregroundColor(buttonTextColor)
            .padding(.horizontal, PTDesignTokens.Spacing.buttonPaddingHorizontal)
            .padding(.vertical, PTDesignTokens.Spacing.buttonPaddingVertical)
            .background(
                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                    .fill(buttonBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                            .stroke(buttonBorderColor, lineWidth: 2)
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isPressed)
            .opacity(isDisabled ? 0.6 : 1.0)
    }
    
    private var buttonTextColor: Color {
        if isDisabled { return Color.ptKleinBlue.opacity(0.5) }
        if isPressed { return Color.white }
        return Color.ptKleinBlue
    }
    
    private var buttonBackgroundColor: Color {
        if isPressed { return Color.ptKleinBlue }
        return Color.clear
    }
    
    private var buttonBorderColor: Color {
        if isDisabled { return Color.ptKleinBlue.opacity(0.5) }
        return Color.ptKleinBlue
    }
}

// MARK: - View Extensions

// MARK: - Additional Modifiers

struct PTOutlineButton: ViewModifier {
    let isPressed: Bool
    let isDisabled: Bool
    
    init(isPressed: Bool = false, isDisabled: Bool = false) {
        self.isPressed = isPressed
        self.isDisabled = isDisabled
    }
    
    func body(content: Content) -> some View {
        content
            .font(PTFontSizes.buttonText)
            .foregroundColor(buttonTextColor)
            .padding(.horizontal, PTDesignTokens.Spacing.buttonPaddingHorizontal)
            .padding(.vertical, PTDesignTokens.Spacing.buttonPaddingVertical)
            .background(
                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                    .fill(buttonBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                            .stroke(buttonBorderColor, lineWidth: 2)
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isPressed)
            .opacity(isDisabled ? 0.6 : 1.0)
    }
    
    private var buttonTextColor: Color {
        if isDisabled { return Color.ptInk.opacity(0.5) }
        if isPressed { return Color.white }
        return Color.ptInk
    }
    
    private var buttonBackgroundColor: Color {
        if isPressed { return Color.ptInk }
        return Color.clear
    }
    
    private var buttonBorderColor: Color {
        if isDisabled { return Color.ptInk.opacity(0.5) }
        return Color.ptInk
    }
}

extension View {
    func ptCardStyle(isPressed: Bool = false) -> some View {
        self.modifier(PTCardStyleModifier(isPressed: isPressed))
    }
    
    func ptPrimaryButton(isPressed: Bool = false, isDisabled: Bool = false) -> some View {
        self.modifier(PTPrimaryButtonStyle(isPressed: isPressed, isDisabled: isDisabled))
    }
    
    func ptSecondaryButton(isPressed: Bool = false, isDisabled: Bool = false) -> some View {
        self.modifier(PTSecondaryButtonStyle(isPressed: isPressed, isDisabled: isDisabled))
    }
    
    func ptOutlineButton(isPressed: Bool = false, isDisabled: Bool = false) -> some View {
        self.modifier(PTOutlineButton(isPressed: isPressed, isDisabled: isDisabled))
    }
}
