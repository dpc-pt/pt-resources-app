//
//  PTTypography.swift
//  PT Resources
//
//  Typography system using authentic PT fonts
//

import SwiftUI

// MARK: - PT Font Manager

struct PTFonts {
    // PT Font Names (these will need to be registered in Info.plist)
    static let agenda = "Agenda-One"
    static let agendaBold = "Agenda-One-Bold"
    static let agendaMedium = "Agenda-One-Medium"
    
    static let fieldsDisplayMedium = "fields-display-medium"
    static let fieldsDisplayBlack = "Fields-Display-Black"
    
    static let optimaRoman = "OptimaLTPro-Roman"
    static let optimaBold = "OptimaLTPro-Bold"
    static let optimaMedium = "OptimaLTPro-Medium"
    static let optimaItalic = "OptimaLTPro-Italic"
    
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

// MARK: - Updated PT Typography

extension PTFont {
    // Brand Typography using PT Fonts
    static let ptBrandTitle = PTFonts.font(name: PTFonts.fieldsDisplayBlack, size: 28, fallback: .bold)
    static let ptSectionTitle = PTFonts.font(name: PTFonts.agendaBold, size: 22, fallback: .semibold)
    static let ptCardTitle = PTFonts.font(name: PTFonts.agendaMedium, size: 17, fallback: .semibold)
    static let ptCardSubtitle = PTFonts.font(name: PTFonts.optimaMedium, size: 15, fallback: .medium)
    static let ptBodyText = PTFonts.font(name: PTFonts.optimaRoman, size: 17, fallback: .regular)
    static let ptCaptionText = PTFonts.font(name: PTFonts.optimaMedium, size: 12, fallback: .medium)
    
    // Logo Typography
    static let ptLogoText = PTFonts.font(name: PTFonts.optimaRoman, size: 16, fallback: .regular)
    
    // Specialized Typography
    static let ptDisplayLarge = PTFonts.font(name: PTFonts.fieldsDisplayBlack, size: 34, fallback: .bold)
    static let ptDisplayMedium = PTFonts.font(name: PTFonts.fieldsDisplayMedium, size: 24, fallback: .semibold)

    // Dynamic Type versions for accessibility
    static let ptBrandTitleDynamic = PTFonts.dynamicFont(name: PTFonts.fieldsDisplayBlack, size: 28, fallback: .bold)
    static let ptSectionTitleDynamic = PTFonts.dynamicFont(name: PTFonts.agendaBold, size: 22, fallback: .semibold)
    static let ptCardTitleDynamic = PTFonts.dynamicFont(name: PTFonts.agendaMedium, size: 17, fallback: .semibold)
    static let ptCardSubtitleDynamic = PTFonts.dynamicFont(name: PTFonts.optimaMedium, size: 15, fallback: .medium)
    static let ptBodyTextDynamic = PTFonts.dynamicFont(name: PTFonts.optimaRoman, size: 17, fallback: .regular)
    static let ptCaptionTextDynamic = PTFonts.dynamicFont(name: PTFonts.optimaMedium, size: 12, fallback: .medium)
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