//
//  PTTypography.swift
//  PT Resources
//
//  Typography system using authentic PT fonts
//

import SwiftUI

// MARK: - PT Font Manager

struct PTFonts {
    // PT Font Names (matching website font-face declarations)
    // Fields Display (for headings) - pt-heading font family
    static let fieldsDisplayMedium = "FieldsDisplay-Medium"
    static let fieldsDisplayBlack = "FieldsDisplay-Black"
    
    // Optima (for body text) - pt-body font family 
    static let optimaRoman = "OptimaLTPro-Roman"
    static let optimaBold = "OptimaLTPro-Bold"
    static let optimaMedium = "OptimaLTPro-Medium"
    static let optimaItalic = "OptimaLTPro-Italic"
    static let optimaBoldItalic = "OptimaLTPro-BoldItalic"
    
    // Agenda One (for special typography) - matching website
    static let agendaMedium = "AgendaOne-Medium"
    static let agendaBold = "AgendaOne-Bold"
    
    // Font fallback system with proper error handling
    static func font(name: String, size: CGFloat, fallback: Font.Weight = .regular) -> Font {
        guard UIFont(name: name, size: size) != nil else {
            PTLogger.general.warning("Font '\(name)' not available, using system fallback")
            return Font.system(size: size, weight: fallback, design: .default)
        }
        return Font.custom(name, size: size)
    }

    // Dynamic Type support version
    static func dynamicFont(name: String, size: CGFloat, fallback: Font.Weight = .regular, maxSize: DynamicTypeSize = .xxxLarge) -> Font {
        guard UIFont(name: name, size: size) != nil else {
            PTLogger.general.warning("Font '\(name)' not available, using system fallback")
            return Font.system(size: size, weight: fallback, design: .default)
        }
        return Font.custom(name, size: size)
    }
}

// MARK: - PT Typography System (Matching Website)

struct PTFont {
    // Primary Brand Typography (Fields Display for headings)
    static let ptBrandTitle = PTFonts.font(name: PTFonts.fieldsDisplayBlack, size: PTFontSizes.text28, fallback: .bold)         // Large titles
    static let ptDisplayLarge = PTFonts.font(name: PTFonts.fieldsDisplayBlack, size: PTFontSizes.text40, fallback: .bold)       // Hero titles
    static let ptDisplayMedium = PTFonts.font(name: PTFonts.fieldsDisplayMedium, size: PTFontSizes.text32, fallback: .semibold) // Section heroes
    static let ptDisplaySmall = PTFonts.font(name: PTFonts.fieldsDisplayMedium, size: PTFontSizes.text28, fallback: .semibold)  // Page titles
    
    // Agenda One Typography (for special headings, matching website h2, h3 styles)
    static let ptSectionTitle = PTFonts.font(name: PTFonts.agendaBold, size: PTFontSizes.text22, fallback: .bold)              // H2 - website style
    static let ptCardTitle = PTFonts.font(name: PTFonts.agendaBold, size: PTFontSizes.text17, fallback: .bold)                 // H3 - website style
    static let ptSubheading = PTFonts.font(name: PTFonts.agendaMedium, size: PTFontSizes.text19, fallback: .semibold)          // H4 equivalent
    
    // Optima Typography (body text, matching website pt-body font family)
    static let ptBodyText = PTFonts.font(name: PTFonts.optimaRoman, size: PTFontSizes.text17, fallback: .regular)              // Body text
    static let ptBodyMedium = PTFonts.font(name: PTFonts.optimaMedium, size: PTFontSizes.text17, fallback: .medium)            // Emphasized body
    static let ptBodyBold = PTFonts.font(name: PTFonts.optimaBold, size: PTFontSizes.text17, fallback: .bold)                  // Strong text
    static let ptCardSubtitle = PTFonts.font(name: PTFonts.optimaMedium, size: PTFontSizes.text15, fallback: .medium)          // Subtitle text
    static let ptCaptionText = PTFonts.font(name: PTFonts.optimaMedium, size: PTFontSizes.text13, fallback: .medium)           // Caption text
    static let ptSmallText = PTFonts.font(name: PTFonts.optimaRoman, size: PTFontSizes.text13, fallback: .regular)             // Small body text
    
    // Button and UI Typography
    static let ptButtonText = PTFonts.font(name: PTFonts.agendaMedium, size: PTFontSizes.text15, fallback: .medium)            // Button text
    static let ptTabBarText = PTFonts.font(name: PTFonts.optimaRoman, size: PTFontSizes.text13, fallback: .regular)            // Tab bar labels
    static let ptNavigationTitle = PTFonts.font(name: PTFonts.agendaBold, size: PTFontSizes.text19, fallback: .bold)           // Navigation titles
    
    // Logo Typography (matching website pt-logo font family)
    static let ptLogoText = PTFonts.font(name: PTFonts.optimaRoman, size: PTFontSizes.text17, fallback: .regular)              // Logo text
    static let ptLogoTextLarge = PTFonts.font(name: PTFonts.optimaMedium, size: PTFontSizes.text19, fallback: .medium)         // Large logo
    
    // Dynamic Type versions for accessibility (iOS system scaling)
    static let ptBrandTitleDynamic = PTFonts.dynamicFont(name: PTFonts.fieldsDisplayBlack, size: PTFontSizes.text28, fallback: .bold)
    static let ptSectionTitleDynamic = PTFonts.dynamicFont(name: PTFonts.agendaBold, size: PTFontSizes.text22, fallback: .bold)
    static let ptCardTitleDynamic = PTFonts.dynamicFont(name: PTFonts.agendaBold, size: PTFontSizes.text17, fallback: .bold)
    static let ptBodyTextDynamic = PTFonts.dynamicFont(name: PTFonts.optimaRoman, size: PTFontSizes.text17, fallback: .regular)
    static let ptCardSubtitleDynamic = PTFonts.dynamicFont(name: PTFonts.optimaMedium, size: PTFontSizes.text15, fallback: .medium)
    static let ptCaptionTextDynamic = PTFonts.dynamicFont(name: PTFonts.optimaMedium, size: PTFontSizes.text13, fallback: .medium)
}

// MARK: - Font Registration Helper

class FontManager {
    static let shared = FontManager()
    
    private var isInitialized = false
    private var availableFonts: Set<String> = []
    
    func registerFonts() {
        guard !isInitialized else { return }
        
        // Fonts are automatically loaded via Info.plist
        // Verify they're available for production use
        verifyFonts()
        isInitialized = true
    }

    /// Async version of font registration for modern concurrency
    func registerFontsAsync() async {
        guard !isInitialized else { return }
        
        await MainActor.run {
            verifyFonts()
            isInitialized = true
        }
    }
    
    private func verifyFonts() {
        let expectedFonts = [
            // Agenda One Fonts
            "Agenda-One-Bold",
            "Agenda-One-Medium",
            
            // Fields Display Fonts
            "Fields-Display-Black",
            "fields-display-medium",
            
            // Optima Fonts
            "OptimaLTPro-BlackItalic",
            "OptimaLTPro-Bold",
            "OptimaLTPro-BoldItalic",
            "OptimaLTPro-Italic",
            "OptimaLTPro-Medium",
            "OptimaLTPro-MediumItalic",
            "OptimaLTPro-Roman"
        ]
        
        for fontName in expectedFonts {
            if UIFont(name: fontName, size: 17) != nil {
                availableFonts.insert(fontName)
            }
        }
        
        let missingFonts = expectedFonts.filter { !availableFonts.contains($0) }
        if !missingFonts.isEmpty {
            PTLogger.general.warning("Missing fonts: \(missingFonts.joined(separator: ", "))")
        } else {
            PTLogger.general.info("All PT fonts loaded successfully")
        }
    }
    
    func isFontAvailable(_ fontName: String) -> Bool {
        return availableFonts.contains(fontName)
    }
}

// MARK: - SwiftUI View Extension for Font Registration

extension View {
    func registerPTFonts() -> some View {
        self.onAppear {
            FontManager.shared.registerFonts()
        }
    }
}
