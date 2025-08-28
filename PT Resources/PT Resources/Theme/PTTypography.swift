//
//  PTTypography.swift
//  PT Resources
//
//  Typography system using authentic PT fonts
//

import SwiftUI

// MARK: - PT Font Manager (Matching Website Font System)

struct PTFonts {
    // PT Font Names (matching website font-face declarations)
    // Fields Display (for headings) - pt-heading font family
    static let fieldsDisplayMedium = "FieldsDisplay-Medium"     // Medium weight
    static let fieldsDisplayBlack = "FieldsDisplay-Black"       // Black weight
    
    // Optima (for body text) - pt-body font family 
    static let optimaRoman = "OptimaLTPro-Roman"                 // Regular weight
    static let optimaBold = "OptimaLTPro-Bold"                   // Bold weight
    static let optimaMedium = "OptimaLTPro-Medium"               // Medium weight
    static let optimaItalic = "OptimaLTPro-Italic"               // Italic style
    static let optimaBoldItalic = "OptimaLTPro-BoldItalic"       // Bold italic
    
    // Agenda One (for special typography) - matching website
    static let agendaMedium = "AgendaOne-Medium"                // Medium weight
    static let agendaBold = "AgendaOne-Bold"                    // Bold weight
    
    // Font fallback system
    static func font(name: String, size: CGFloat, fallback: Font.Weight = .regular) -> Font {
        if UIFont(name: name, size: size) != nil {
            return Font.custom(name, size: size)
        } else {
            // Fallback to system font with equivalent weight
            return Font.system(size: size, weight: fallback, design: .default)
        }
    }

    // Dynamic Type support version
    static func dynamicFont(name: String, size: CGFloat, fallback: Font.Weight = .regular, maxSize: DynamicTypeSize = .xxxLarge) -> Font {
        if UIFont(name: name, size: size) != nil {
            return Font.custom(name, size: size)
        } else {
            // Fallback to system font with equivalent weight
            return Font.system(size: size, weight: fallback, design: .default)
        }
    }
}

// MARK: - PT Typography System (Matching Website)

extension PTFont {
    // Primary Brand Typography (Fields Display for headings)
    static let ptBrandTitle = PTFonts.font(name: PTFonts.fieldsDisplayBlack, size: text28, fallback: .bold)         // Large titles
    static let ptDisplayLarge = PTFonts.font(name: PTFonts.fieldsDisplayBlack, size: text40, fallback: .bold)       // Hero titles
    static let ptDisplayMedium = PTFonts.font(name: PTFonts.fieldsDisplayMedium, size: text32, fallback: .semibold) // Section heroes
    static let ptDisplaySmall = PTFonts.font(name: PTFonts.fieldsDisplayMedium, size: text28, fallback: .semibold)  // Page titles
    
    // Agenda One Typography (for special headings, matching website h2, h3 styles)
    static let ptSectionTitle = PTFonts.font(name: PTFonts.agendaBold, size: text22, fallback: .bold)              // H2 - website style
    static let ptCardTitle = PTFonts.font(name: PTFonts.agendaBold, size: text17, fallback: .bold)                 // H3 - website style
    static let ptSubheading = PTFonts.font(name: PTFonts.agendaMedium, size: text19, fallback: .semibold)          // H4 equivalent
    
    // Optima Typography (body text, matching website pt-body font family)
    static let ptBodyText = PTFonts.font(name: PTFonts.optimaRoman, size: text17, fallback: .regular)              // Body text
    static let ptBodyMedium = PTFonts.font(name: PTFonts.optimaMedium, size: text17, fallback: .medium)            // Emphasized body
    static let ptBodyBold = PTFonts.font(name: PTFonts.optimaBold, size: text17, fallback: .bold)                  // Strong text
    static let ptCardSubtitle = PTFonts.font(name: PTFonts.optimaMedium, size: text15, fallback: .medium)          // Subtitle text
    static let ptCaptionText = PTFonts.font(name: PTFonts.optimaMedium, size: text13, fallback: .medium)           // Caption text
    static let ptSmallText = PTFonts.font(name: PTFonts.optimaRoman, size: text13, fallback: .regular)             // Small body text
    
    // Button and UI Typography
    static let ptButtonText = PTFonts.font(name: PTFonts.agendaMedium, size: text15, fallback: .medium)            // Button text
    static let ptTabBarText = PTFonts.font(name: PTFonts.optimaRoman, size: text13, fallback: .regular)            // Tab bar labels
    static let ptNavigationTitle = PTFonts.font(name: PTFonts.agendaBold, size: text19, fallback: .bold)           // Navigation titles
    
    // Logo Typography (matching website pt-logo font family)
    static let ptLogoText = PTFonts.font(name: PTFonts.optimaRoman, size: text17, fallback: .regular)              // Logo text
    static let ptLogoTextLarge = PTFonts.font(name: PTFonts.optimaMedium, size: text19, fallback: .medium)         // Large logo
    
    // Dynamic Type versions for accessibility (iOS system scaling)
    static let ptBrandTitleDynamic = PTFonts.dynamicFont(name: PTFonts.fieldsDisplayBlack, size: text28, fallback: .bold)
    static let ptSectionTitleDynamic = PTFonts.dynamicFont(name: PTFonts.agendaBold, size: text22, fallback: .bold)
    static let ptCardTitleDynamic = PTFonts.dynamicFont(name: PTFonts.agendaBold, size: text17, fallback: .bold)
    static let ptBodyTextDynamic = PTFonts.dynamicFont(name: PTFonts.optimaRoman, size: text17, fallback: .regular)
    static let ptCardSubtitleDynamic = PTFonts.dynamicFont(name: PTFonts.optimaMedium, size: text15, fallback: .medium)
    static let ptCaptionTextDynamic = PTFonts.dynamicFont(name: PTFonts.optimaMedium, size: text13, fallback: .medium)
}

// MARK: - Font Registration Helper

class FontManager {
    static let shared = FontManager()
    
    private var registeredFonts: Set<String> = []
    
    func registerFonts() {
        // With Info.plist registration, fonts are automatically available
        // Just verify they're loaded and log available fonts
        verifyFonts()
    }

    /// Async version of font registration for modern concurrency
    func registerFontsAsync() async throws {
        // Fonts are automatically loaded via Info.plist
        // Just verify they're available
        await MainActor.run {
            verifyFonts()
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
                registeredFonts.insert(fontName)
                print("✅ Font available: \(fontName)")
            } else {
                print("❌ Font not available: \(fontName)")
            }
        }
    }
    
    func listAvailableFonts() {
        print("\n📝 Available PT Fonts:")
        for fontName in registeredFonts.sorted() {
            print("   • \(fontName)")
        }
        print()
    }
}

// MARK: - SwiftUI View Extension for Font Registration

extension View {
    func registerPTFonts() -> some View {
        self.onAppear {
            FontManager.shared.registerFonts()
            #if DEBUG
            FontManager.shared.listAvailableFonts()
            #endif
        }
    }
}
