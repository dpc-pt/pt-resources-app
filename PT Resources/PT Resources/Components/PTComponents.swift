//
//  PTComponents.swift
//  PT Resources
//
//  Core PT-styled UI components (now imports decomposed components)
//

import SwiftUI

// Re-export the decomposed components for backward compatibility
// Note: Search components are now in PTSearchComponents.swift
// Filter components are now in PTFilterComponents.swift 
// Card components are now in PTCardComponents.swift

// MARK: - Loading Components

struct PTLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: PTDesignTokens.Spacing.lg) {
            PTLogo(size: 48, showText: false)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: isAnimating)
                .onAppear {
                    isAnimating = true
                }
            
            Text("Loading resources...")
                .font(PTFont.ptSectionTitle)
                .foregroundColor(PTDesignTokens.Colors.ink)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PTDesignTokens.Colors.background)
    }
}

// MARK: - Empty State Components

struct PTEmptyStateView: View {
    let title: String
    let message: String
    let iconName: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        title: String = "No Content",
        message: String = "There's nothing here yet.",
        iconName: String = "tray",
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.iconName = iconName
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: PTDesignTokens.Spacing.lg) {
            Image(systemName: iconName)
                .font(.system(size: 60))
                .foregroundColor(PTDesignTokens.Colors.medium)
            
            VStack(spacing: PTDesignTokens.Spacing.sm) {
                Text(title)
                    .font(PTFont.ptSectionTitle)
                    .foregroundColor(PTDesignTokens.Colors.ink)
                
                Text(message)
                    .font(PTFont.ptBodyText)
                    .foregroundColor(PTDesignTokens.Colors.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .font(PTFont.ptButtonText)
                    .foregroundColor(.white)
                    .padding(.horizontal, PTDesignTokens.Spacing.lg)
                    .padding(.vertical, PTDesignTokens.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                            .fill(PTDesignTokens.Colors.tang)
                    )
            }
        }
        .padding(PTDesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PTDesignTokens.Colors.background)
    }
}

// MARK: - Button Components

struct PTPrimaryButton: View {
    let title: String
    let action: () -> Void
    let isEnabled: Bool
    let isLoading: Bool
    
    init(
        _ title: String,
        action: @escaping () -> Void,
        isEnabled: Bool = true,
        isLoading: Bool = false
    ) {
        self.title = title
        self.action = action
        self.isEnabled = isEnabled
        self.isLoading = isLoading
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: PTDesignTokens.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text(title)
                        .font(PTFont.ptButtonText)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, PTDesignTokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                    .fill(isEnabled ? PTDesignTokens.Colors.tang : PTDesignTokens.Colors.medium)
            )
        }
        .disabled(!isEnabled || isLoading)
        .buttonStyle(PlainButtonStyle())
    }
}

struct PTSecondaryButton: View {
    let title: String
    let action: () -> Void
    let isEnabled: Bool
    
    init(
        _ title: String,
        action: @escaping () -> Void,
        isEnabled: Bool = true
    ) {
        self.title = title
        self.action = action
        self.isEnabled = isEnabled
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(PTFont.ptButtonText)
                .foregroundColor(isEnabled ? PTDesignTokens.Colors.tang : PTDesignTokens.Colors.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, PTDesignTokens.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                        .fill(Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                        .stroke(isEnabled ? PTDesignTokens.Colors.tang : PTDesignTokens.Colors.medium, lineWidth: 1)
                )
        }
        .disabled(!isEnabled)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Divider Components

struct PTDivider: View {
    let thickness: CGFloat
    let color: Color
    
    init(thickness: CGFloat = 1, color: Color = PTDesignTokens.Colors.light.opacity(0.3)) {
        self.thickness = thickness
        self.color = color
    }
    
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: thickness)
    }
}

struct PTSectionDivider: View {
    let title: String?
    
    init(_ title: String? = nil) {
        self.title = title
    }
    
    var body: some View {
        HStack {
            PTDivider()
            
            if let title = title {
                Text(title)
                    .font(PTFont.ptCaptionText)
                    .foregroundColor(PTDesignTokens.Colors.medium)
                    .padding(.horizontal, PTDesignTokens.Spacing.sm)
                
                PTDivider()
            }
        }
        .padding(.vertical, PTDesignTokens.Spacing.md)
    }
}

// MARK: - Progress Components
// PTProgressBar is defined in NowPlayingView.swift

// MARK: - Welcome Components

struct PTWelcomeHeader: View {
    let onSettingsTap: () -> Void
    
    var body: some View {
        VStack(spacing: PTDesignTokens.Spacing.lg) {
            // Top row with welcome text and settings
            HStack {
                VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.xs) {
                    Text("Welcome to")
                        .font(PTFont.ptBodyText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                    
                    Text("the Proclamation Trust")
                        .font(PTFont.ptSectionTitle)
                        .foregroundColor(PTDesignTokens.Colors.ink)
                }
                
                Spacer()
                
                Button(action: onSettingsTap) {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                        .padding(PTDesignTokens.Spacing.sm)
                        .background(
                            Circle()
                                .fill(PTDesignTokens.Colors.light.opacity(0.3))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Logo section with enhanced presentation
            HStack {
                Spacer()
                
                VStack(spacing: PTDesignTokens.Spacing.sm) {
                    PTLogo(size: 48, showText: false)
                        .shadow(color: PTDesignTokens.Colors.tang.opacity(0.2), radius: 8, x: 0, y: 4)
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
        .padding(.vertical, PTDesignTokens.Spacing.lg)
        .background(
            LinearGradient(
                colors: [
                    PTDesignTokens.Colors.background,
                    PTDesignTokens.Colors.surface.opacity(0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

struct PTWelcomeLoadingView: View {
    let onSettingsTap: () -> Void
    
    var body: some View {
        VStack(spacing: PTDesignTokens.Spacing.xl) {
            PTWelcomeHeader(onSettingsTap: onSettingsTap)
            
            Spacer()
            
            PTLoadingView()
            
            Spacer()
        }
    }
}

// MARK: - Blog Artwork

private struct BlogArtwork: View {
    let blogPost: BlogPost

    var body: some View {
        AsyncImage(url: URL(string: blogPost.image ?? "")) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.md))
        } placeholder: {
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.md)
                .fill(PTDesignTokens.Colors.light.opacity(0.3))
                .frame(height: 160)
                .overlay(
                    Image(systemName: "doc.text")
                        .foregroundColor(PTDesignTokens.Colors.medium)
                        .font(.title2)
                )
        }
    }
}

// MARK: - Featured Components

struct PTFeaturedBlogCard: View {
    let blogPost: BlogPost
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.md) {
                Text("Latest from the Blog")
                    .font(PTFont.ptCaptionText)
                    .foregroundColor(PTDesignTokens.Colors.tang)
                    .textCase(.uppercase)

                // Blog image if available
                if let image = blogPost.image, !image.isEmpty {
                    BlogArtwork(blogPost: blogPost)
                }

                Text(blogPost.title)
                    .font(PTFont.ptSectionTitle)
                    .foregroundColor(PTDesignTokens.Colors.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let excerpt = blogPost.excerpt {
                    Text(excerpt)
                        .font(PTFont.ptBodyText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }

                HStack {
                    Text("Read More")
                        .font(PTFont.ptButtonText)
                        .foregroundColor(PTDesignTokens.Colors.tang)

                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(PTDesignTokens.Colors.tang)

                    Spacer()
                }
            }
            .padding(PTDesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.lg)
                    .fill(PTDesignTokens.Colors.surface)
                    .shadow(
                        color: Color.black.opacity(0.05),
                        radius: 8,
                        x: 0,
                        y: 2
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity)
    }
}