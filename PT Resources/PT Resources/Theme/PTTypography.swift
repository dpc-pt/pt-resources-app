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
    static let fieldsDisplayMedium = "fields-display-medium"     // Medium weight
    static let fieldsDisplayBlack = "Fields-Display-Black"       // Black weight
    
    // Optima (for body text) - pt-body font family 
    static let optimaRoman = "OptimaLTPro-Roman"                 // Regular weight
    static let optimaBold = "OptimaLTPro-Bold"                   // Bold weight
    static let optimaMedium = "OptimaLTPro-Medium"               // Medium weight
    static let optimaItalic = "OptimaLTPro-Italic"               // Italic style
    static let optimaBoldItalic = "OptimaLTPro-BoldItalic"       // Bold italic
    
    // Agenda One (for special typography) - matching website
    static let agendaMedium = "Agenda-One-Medium"                // Medium weight
    static let agendaBold = "Agenda-One-Bold"                    // Bold weight
    
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
    static let ptButtonText = PTFonts.font(name: PTFonts.optimaMedium, size: text15, fallback: .medium)            // Button text
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
        registerFontFamily("Agenda-One")
        registerFontFamily("Fields")
        registerFontFamily("Optima")
    }

    /// Async version of font registration for modern concurrency
    func registerFontsAsync() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                self.registerFonts()
                continuation.resume()
            }
        }
    }
    
    private func registerFontFamily(_ familyName: String) {
        guard let fontURLs = Bundle.main.urls(forResourcesWithExtension: nil, subdirectory: "Fonts/\(familyName)") else {
            print("⚠️ No fonts found for family: \(familyName)")
            return
        }
        
        for fontURL in fontURLs {
            registerFont(from: fontURL)
        }
    }
    
    private func registerFont(from url: URL) {
        guard let fontDataProvider = CGDataProvider(url: url as CFURL) else {
            print("⚠️ Could not create data provider for: \(url.lastPathComponent)")
            return
        }
        
        guard let font = CGFont(fontDataProvider) else {
            print("⚠️ Could not create font from: \(url.lastPathComponent)")
            return
        }
        
        var error: Unmanaged<CFError>?
        let success = CTFontManagerRegisterGraphicsFont(font, &error)
        
        if success {
            if let fontName = font.postScriptName as String? {
                registeredFonts.insert(fontName)
                print("✅ Registered font: \(fontName)")
            }
        } else {
            if let error = error?.takeRetainedValue() {
                let errorDescription = CFErrorCopyDescription(error)
                print("❌ Failed to register font \(url.lastPathComponent): \(String(describing: errorDescription))")
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