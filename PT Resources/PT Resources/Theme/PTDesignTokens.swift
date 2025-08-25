//
//  PTDesignTokens.swift
//  PT Resources
//
//  Centralized design tokens matching the Proclamation Trust website design system
//  This file mirrors the website's tailwind.config.js and CSS variables
//

import SwiftUI

// MARK: - Design Tokens Namespace

enum PTDesignTokens {
    
    // MARK: - Colors (Direct from website CSS variables)
    
    enum Colors {
        // Core PT Brand Colors (--pt-* variables from website)
        static let ink = Color(hex: "#07324c")           // --pt-ink: Primary text, headers
        static let tang = Color(hex: "#ff4c23")          // --pt-tang: Primary CTA, accent
        static let kleinBlue = Color(hex: "#4060ab")     // --pt-klein-blue: Links, secondary actions
        static let turmeric = Color(hex: "#ff921c")      // --pt-turmeric: Warning states
        static let lawn = Color(hex: "#0f9679")          // --pt-lawn: Success states
        
        // Semantic mappings (from website CSS variables)
        static let primary = tang                        // --pt-primary
        static let secondary = kleinBlue                 // --pt-secondary
        static let success = lawn                        // --pt-success
        static let warning = turmeric                    // --pt-warning
        static let text = ink                           // --pt-text
        
        // Neutral scale (from website gray/slate system)
        static let background = Color.white              // Clean white background
        static let surface = Color.white                 // Card/component backgrounds
        static let veryLight = Color(hex: "#f7f7f7")    // gray.very-light
        static let lightMedium = Color(hex: "#eaeaeb")  // gray.light-medium
        static let extraMedium = Color(hex: "#e4e4e4")  // gray.extra-medium
        static let light = Color(hex: "#a8a8a8")        // gray.light
        static let medium = Color(hex: "#717580")       // gray.medium
        static let dark = Color(hex: "#232323")         // gray.dark
        
        // Interactive states (hover colors from website)
        static let tangHover = kleinBlue                // Tang buttons hover to Klein Blue
        static let kleinBlueHover = tang                // Klein Blue elements hover to Tang
        static let inkHover = Color(hex: "#0a4a6b")     // Slightly lighter ink for hover
        
        // Status colors (from website design system)
        static let error = Color(hex: "#dc3131")        // red.DEFAULT
        static let errorLight = Color(hex: "#feedec")   // red.light
        
        // Border and divider colors
        static let border = extraMedium.opacity(0.3)    // Subtle borders
        static let divider = extraMedium.opacity(0.5)   // Section dividers
        
        // Overlay colors for patterns and backgrounds
        static let overlayLight = Color.white.opacity(0.85)     // Pattern overlay light
        static let overlayMedium = Color.white.opacity(0.7)     // Pattern overlay medium  
        static let overlaySubtle = ink.opacity(0.15)            // Pattern overlay subtle
        static let overlayDark = ink.opacity(0.3)               // Pattern overlay dark
    }
    
    // MARK: - Typography Scale (Matching website fontSize scale)
    
    enum Typography {
        // Size scale (from tailwind.config.js fontSize)
        static let text9: CGFloat = 9        // '9': '9px'
        static let text10: CGFloat = 10      // '10': '10px'
        static let text11: CGFloat = 11      // '11': '11px'
        static let text13: CGFloat = 13      // '13': '13px'
        static let text15: CGFloat = 15      // '15': '15px'
        static let text17: CGFloat = 17      // '17': '17px'
        static let text19: CGFloat = 19      // '19': '19px'
        static let text22: CGFloat = 22      // '22': '22px'
        static let text26: CGFloat = 26      // '26': ['26px', '38px']
        static let text28: CGFloat = 28      // '28': ['1.75rem', '2.6rem']
        static let text30: CGFloat = 30      // '30': ['1.875rem', '2.8rem']
        static let text32: CGFloat = 32      // '32': ['2rem', '2.5rem']
        static let text40: CGFloat = 40      // '40': ['2.5rem', '2.5rem']
        static let text45: CGFloat = 45      // '45': ['2.813rem', '3rem']
        static let text50: CGFloat = 50      // '50': ['3.125rem', '3.25rem']
        
        // Line heights (from website with line-height values)
        static let lineHeightTight: CGFloat = 1.2
        static let lineHeightNormal: CGFloat = 1.5
        static let lineHeightRelaxed: CGFloat = 1.7      // Body text line-height from website
        static let lineHeightLoose: CGFloat = 2.0
        
        // Font weights (standard system weights)
        static let weightRegular: Font.Weight = .regular
        static let weightMedium: Font.Weight = .medium
        static let weightSemibold: Font.Weight = .semibold
        static let weightBold: Font.Weight = .bold
        static let weightBlack: Font.Weight = .black
    }
    
    // MARK: - Spacing Scale (8px base unit system)
    
    enum Spacing {
        // Base scale (matching website 8px, 16px, 24px system)
        static let xs: CGFloat = 4       // 0.25rem
        static let sm: CGFloat = 8       // 0.5rem - website base unit
        static let md: CGFloat = 16      // 1rem - standard spacing
        static let lg: CGFloat = 24      // 1.5rem - section spacing
        static let xl: CGFloat = 32      // 2rem - large spacing
        static let xxl: CGFloat = 48     // 3rem - extra large spacing
        static let xxxl: CGFloat = 64    // 4rem - hero sections
        static let huge: CGFloat = 96    // 6rem - major sections
        
        // Component-specific spacing
        static let cardPadding = lg              // 24px internal card padding
        static let cardSpacing = md              // 16px between cards
        static let sectionSpacing = xl           // 32px between sections
        static let screenEdges = md              // 16px screen edge padding
        static let screenPadding = screenEdges   // Legacy alias for screenEdges
        static let buttonPaddingVertical: CGFloat = 12    // Button vertical padding (0.75rem)
        static let buttonPaddingHorizontal: CGFloat = 24  // Button horizontal padding (1.5rem)
        
        // Container spacing (responsive design)
        static let containerPadding = md         // 16px container side padding
        static let maxContentWidth: CGFloat = 1200  // Max content width (1200px)
    }
    
    // MARK: - Border Radius (Matching website borderRadius scale)
    
    enum BorderRadius {
        // Scale (from tailwind.config.js borderRadius)
        static let xs: CGFloat = 2       // 'xs': '2px'
        static let sm: CGFloat = 4       // sm: calc(var(--radius) - 4px) when --radius is 8px
        static let base: CGFloat = 6     // DEFAULT: '6px'
        static let md: CGFloat = 8       // md: calc(var(--radius) - 2px) when --radius is 10px
        static let lg: CGFloat = 10      // lg: var(--radius) default (0.5rem)
        static let xl: CGFloat = 15      // 'xl': '15px'
        static let xxl: CGFloat = 20     // '2xl': '20px'
        static let xxxl: CGFloat = 30    // '3xl': '30px'
        static let huge: CGFloat = 40    // '4xl': '40px'
        static let full: CGFloat = 9999  // 'full': '9999px'
        
        // Component-specific radius
        static let card = base           // 6px for cards
        static let button = base         // 6px for buttons
        static let input = base          // 6px for inputs
        static let image = base          // 6px for images
        static let modal = lg            // 10px for modals
    }
    
    // MARK: - Shadows (Matching website shadow system)
    
    enum Shadows {
        // Shadow definitions (box-shadow values)
        static let light = (color: Color.black.opacity(0.05), radius: 2.0, x: 0.0, y: 1.0)
        static let medium = (color: Color.black.opacity(0.1), radius: 8.0, x: 0.0, y: 4.0)
        static let large = (color: Color.black.opacity(0.15), radius: 16.0, x: 0.0, y: 8.0)
        static let extraLarge = (color: Color.black.opacity(0.2), radius: 24.0, x: 0.0, y: 12.0)
        
        // Component-specific shadows
        static let card = medium         // Standard card shadow
        static let cardPressed = light   // Pressed card shadow
        static let modal = extraLarge    // Modal/sheet shadow
        static let button = light        // Button shadow
    }
    
    // MARK: - Animation Durations (Website interaction timings)
    
    enum Animation {
        static let fast: Double = 0.15           // Quick interactions
        static let normal: Double = 0.2          // Standard transitions (website default)
        static let slow: Double = 0.3            // Slow transitions
        static let pageTransition: Double = 0.4  // Page/screen transitions
        
        // Easing curves
        static let easeInOut = SwiftUI.Animation.easeInOut(duration: normal)
        static let easeOut = SwiftUI.Animation.easeOut(duration: normal)
        static let bouncy = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
    }
    
    // MARK: - Z-Index (Layout stacking)
    
    enum ZIndex {
        static let base: Double = 0
        static let raised: Double = 10      // Cards, buttons
        static let dropdown: Double = 100   // Dropdowns, popovers  
        static let overlay: Double = 500    // Overlays
        static let modal: Double = 1000     // Modals, sheets
        static let toast: Double = 2000     // Toast notifications
        static let tooltip: Double = 5000   // Tooltips
    }
    
    // MARK: - Accessibility
    
    enum Accessibility {
        static let minTouchTarget: CGFloat = 44  // Minimum iOS touch target
        static let focusOutlineWidth: CGFloat = 2
        static let focusOutlineColor = Colors.primary
        static let focusOutlineOffset: CGFloat = 2
    }
    
    // MARK: - Breakpoints (for responsive design logic)
    
    enum Breakpoints {
        static let compact: CGFloat = 414    // iPhone width
        static let regular: CGFloat = 768    // iPad portrait width
        static let large: CGFloat = 1024     // iPad landscape width
        static let extraLarge: CGFloat = 1200 // Large screens
    }
}

// MARK: - Color Extension (for hex initialization)

extension Color {
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
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}