//
//  PTLogo.swift
//  PT Resources
//
//  Proclamation Trust logo and brand elements
//

import SwiftUI

struct PTLogo: View {
    let size: CGFloat
    let showText: Bool

    init(size: CGFloat = 32, showText: Bool = true) {
        self.size = size
        self.showText = showText
    }

    var body: some View {
        if showText {
            // Use the full logo with text from SVG
            Image("pt-logo-primary-dark")
                .resizable()
                .scaledToFit()
                .frame(height: size)
                .foregroundColor(PTDesignTokens.Colors.ink)
        } else {
            // Use just the icon
            Image("pt-logo-icon")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundColor(PTDesignTokens.Colors.tang)
        }
    }
}

struct PTStarSymbol: View {
    let size: CGFloat

    init(size: CGFloat = 32) {
        self.size = size
    }

    var body: some View {
        Image("pt-logo-icon")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundColor(PTDesignTokens.Colors.tang)
    }
}

struct PTBrandHeader: View {
    let title: String
    let subtitle: String?
    
    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.sm) {
            HStack {
                PTLogo(size: 28)
                Spacer()
            }
            
            Text(title)
                .font(PTFont.ptBrandTitle)
                .foregroundColor(PTDesignTokens.Colors.ink)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(PTFont.ptBodyText)
                    .foregroundColor(PTDesignTokens.Colors.medium)
            }
        }
        .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
        .padding(.top, PTDesignTokens.Spacing.lg)
        .background(PTDesignTokens.Colors.background)
    }
}

// MARK: - Previews

struct PTLogo_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 32) {
            PTLogo(size: 48, showText: true)
            PTLogo(size: 32, showText: true)
            PTLogo(size: 24, showText: false)
            PTStarSymbol(size: 64)
            
            PTBrandHeader("Resources", subtitle: "Sermons and talks from Proclamation Trust")
        }
        .padding()
        .background(PTDesignTokens.Colors.background)
        .previewLayout(.sizeThatFits)
    }
}