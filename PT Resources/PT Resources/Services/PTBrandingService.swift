//
//  PTBrandingService.swift
//  PT Resources
//
//  Comprehensive PT branding service for consistent visual identity throughout the app
//

import Foundation
import UIKit
import SwiftUI

// MARK: - PT Content Type Enum

enum PTContentType {
    case video
    case audio
    case general
    case conference
}

@MainActor
final class PTBrandingService: ObservableObject {
    
    // MARK: - Singleton Instance
    
    static let shared = PTBrandingService()
    
    // MARK: - Brand Colors
    
    let ptBlue = UIColor(red: 0.0, green: 0.48, blue: 0.8, alpha: 1.0) // Klein Blue
    let ptOrange = UIColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0) // Tang Orange
    let ptRed = UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1.0) // PT Red
    let ptGray = UIColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1.0) // Dark Gray
    let ptLightGray = UIColor(red: 0.9, green: 0.9, blue: 0.92, alpha: 1.0) // Light Gray
    
    // SwiftUI Color equivalents
    var ptBlueSwiftUI: Color { Color(ptBlue) }
    var ptOrangeSwiftUI: Color { Color(ptOrange) }
    var ptRedSwiftUI: Color { Color(ptRed) }
    var ptGraySwiftUI: Color { Color(ptGray) }
    var ptLightGraySwiftUI: Color { Color(ptLightGray) }
    
    // MARK: - Private Properties
    
    private var logoCache: UIImage?
    private var patternCache: [String: UIImage] = [:]
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Logo Methods
    
    /// Load PT logo with proper scaling
    func loadPTLogo() -> UIImage? {
        if let cachedLogo = logoCache {
            return cachedLogo
        }
        
        // Try loading from imagesets first
        if let logoImage = UIImage(named: "pt-logo-icon") {
            logoCache = logoImage
            return logoImage
        }
        
        // Fallback to PNG version
        if let logoImage = UIImage(named: "pt-logo-square") {
            logoCache = logoImage
            return logoImage
        }
        
        return nil
    }
    
    /// Check if PT logo is available
    func hasLogo() -> Bool {
        return loadPTLogo() != nil
    }
    
    // MARK: - Pattern Methods
    
    /// Load PT pattern with caching and proper scaling
    func loadPattern(named patternName: String) -> UIImage? {
        if let cachedPattern = patternCache[patternName] {
            return cachedPattern
        }
        
        // Try loading from imagesets
        if let patternImage = UIImage(named: patternName) {
            patternCache[patternName] = patternImage
            return patternImage
        }
        
        return nil
    }
    
    /// Get the appropriate pattern based on branding strategy
    func getStrategicPattern(hasLogo: Bool) -> UIImage? {
        let patternName = hasLogo ? "color-dots" : "pt-icon-pattern"
        return loadPattern(named: patternName)
    }
    
    // MARK: - Branding Strategy Methods
    
    /// Apply PT branding pattern to a view
    func applyPatternBackground(
        to view: UIView,
        hasLogo: Bool = false,
        opacity: CGFloat = 0.1
    ) {
        guard let pattern = getStrategicPattern(hasLogo: hasLogo) else { return }
        
        let patternView = UIImageView(image: pattern)
        patternView.contentMode = .scaleAspectFill
        patternView.alpha = opacity
        patternView.translatesAutoresizingMaskIntoConstraints = false
        
        view.insertSubview(patternView, at: 0)
        NSLayoutConstraint.activate([
            patternView.topAnchor.constraint(equalTo: view.topAnchor),
            patternView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            patternView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            patternView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    /// Create PT branded gradient (using solid colors as stops)
    func createBrandGradient(for contentType: PTContentType) -> [Color] {
        switch contentType {
        case .video:
            return [ptBlueSwiftUI, ptBlueSwiftUI.opacity(0.8)]
        case .audio:
            return [ptOrangeSwiftUI, ptOrangeSwiftUI.opacity(0.8)]
        case .general:
            return [ptGraySwiftUI, ptLightGraySwiftUI]
        case .conference:
            return [ptRedSwiftUI, ptRedSwiftUI.opacity(0.8)]
        }
    }
    
    /// Get primary brand color for content type
    func getPrimaryColor(for contentType: PTContentType) -> UIColor {
        switch contentType {
        case .video:
            return ptBlue
        case .audio:
            return ptOrange
        case .general:
            return ptGray
        case .conference:
            return ptRed  // Use PT Red for conferences to distinguish them
        }
    }
    
    // MARK: - SwiftUI Extensions
    
    /// Create a branded background view
    func createBrandedBackground(
        for contentType: PTContentType,
        hasLogo: Bool = false
    ) -> some View {
        ZStack {
            // Solid color background
            getPrimaryColor(for: contentType).swiftUIColor
            
            // Pattern overlay
            if let pattern = getStrategicPattern(hasLogo: hasLogo) {
                Image(uiImage: pattern)
                    .resizable(resizingMode: .tile)
                    .opacity(hasLogo ? 0.08 : 0.12)
                    .allowsHitTesting(false)
            }
        }
    }
    
    // MARK: - Website-Style Background Patterns
    
    /// Create corner pattern overlay like website
    func createCornerPatternOverlay(
        position: CornerPosition = .topLeft,
        size: PatternSize = .medium,
        hasLogo: Bool = false
    ) -> some View {
        GeometryReader { geometry in
            if let pattern = self.getStrategicPattern(hasLogo: hasLogo) {
                Image(uiImage: pattern)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.dimension, height: size.dimension)
                    .opacity(0.06)
                    .position(
                        x: position.xPosition(in: geometry.size, patternSize: size.dimension),
                        y: position.yPosition(in: geometry.size, patternSize: size.dimension)
                    )
                    .allowsHitTesting(false)
            }
        }
    }
    
    /// Create section background with subtle pattern like website
    func createSectionBackground(
        baseColor: Color = Color.clear,
        hasLogo: Bool = false,
        patternOpacity: Double = 0.04
    ) -> some View {
        ZStack {
            baseColor
            
            if let pattern = self.getStrategicPattern(hasLogo: hasLogo) {
                Image(uiImage: pattern)
                    .resizable(resizingMode: .tile)
                    .opacity(patternOpacity)
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Supporting Types

enum CornerPosition {
    case topLeft, topRight, bottomLeft, bottomRight
    
    func xPosition(in size: CGSize, patternSize: CGFloat) -> CGFloat {
        switch self {
        case .topLeft, .bottomLeft:
            return patternSize / 2
        case .topRight, .bottomRight:
            return size.width - patternSize / 2
        }
    }
    
    func yPosition(in size: CGSize, patternSize: CGFloat) -> CGFloat {
        switch self {
        case .topLeft, .topRight:
            return patternSize / 2
        case .bottomLeft, .bottomRight:
            return size.height - patternSize / 2
        }
    }
}

enum PatternSize {
    case small, medium, large
    
    var dimension: CGFloat {
        switch self {
        case .small: return 80
        case .medium: return 120
        case .large: return 160
        }
    }
}

// MARK: - UIColor SwiftUI Extension

extension UIColor {
    var swiftUIColor: Color {
        Color(self)
    }
}

// MARK: - SwiftUI View Modifier

struct PTBrandedBackground: ViewModifier {
    let contentType: PTContentType
    let hasLogo: Bool
    
    func body(content: Content) -> some View {
        content
            .background(
                PTBrandingService.shared.createBrandedBackground(
                    for: contentType,
                    hasLogo: hasLogo
                )
            )
    }
}

extension View {
    func ptBrandedBackground(
        for contentType: PTContentType,
        hasLogo: Bool = false
    ) -> some View {
        modifier(PTBrandedBackground(contentType: contentType, hasLogo: hasLogo))
    }
    
    /// Add corner pattern overlay like website
    func ptCornerPattern(
        position: CornerPosition = .topLeft,
        size: PatternSize = .medium,
        hasLogo: Bool = false
    ) -> some View {
        overlay(
            PTBrandingService.shared.createCornerPatternOverlay(
                position: position,
                size: size,
                hasLogo: hasLogo
            )
        )
    }
    
    /// Add section background with subtle pattern like website
    func ptSectionBackground(
        baseColor: Color = Color.clear,
        hasLogo: Bool = false,
        patternOpacity: Double = 0.04
    ) -> some View {
        background(
            PTBrandingService.shared.createSectionBackground(
                baseColor: baseColor,
                hasLogo: hasLogo,
                patternOpacity: patternOpacity
            )
        )
    }
}

// MARK: - Pattern Usage Examples

/*
 Usage Examples:
 
 1. In SwiftUI Views:
    VStack {
        // Content
    }
    .ptBrandedBackground(for: .audio, hasLogo: false) // Uses pt-icon-pattern
    
 2. In UIKit:
    let brandingService = PTBrandingService.shared
    brandingService.applyPatternBackground(to: myView, hasLogo: true) // Uses color-dots
    
 3. For Media Artwork:
    - When PT logo is visible: use color-dots pattern at 8% opacity
    - When no PT logo: use pt-icon-pattern at 12% opacity for stronger branding
 */