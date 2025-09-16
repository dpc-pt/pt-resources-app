//
//  ResponsiveArtworkView.swift
//  PT Resources
//
//  A responsive artwork view that maintains proper proportions and makes optimal use of available space
//

import SwiftUI

struct ResponsiveArtworkView: View {
    let imageURL: URL?
    let fallbackView: AnyView
    let maxSize: CGFloat
    let aspectRatio: CGFloat
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    
    @State private var imageSize: CGSize = .zero
    
    init<FallbackContent: View>(
        imageURL: URL?,
        maxSize: CGFloat = 400,
        aspectRatio: CGFloat = 1.0, // 1.0 for square, 1.33 for 4:3, 1.78 for 16:9, etc.
        cornerRadius: CGFloat = 16,
        shadowRadius: CGFloat = 8,
        @ViewBuilder fallbackContent: () -> FallbackContent
    ) {
        self.imageURL = imageURL
        self.fallbackView = AnyView(fallbackContent())
        self.maxSize = maxSize
        self.aspectRatio = aspectRatio
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
    }
    
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let availableHeight = geometry.size.height
            
            // Calculate optimal size maintaining aspect ratio
            let maxWidth = min(availableWidth * 0.9, maxSize)
            let maxHeight = min(availableHeight, maxSize / aspectRatio)
            
            let finalWidth = min(maxWidth, maxHeight * aspectRatio)
            let finalHeight = finalWidth / aspectRatio
            
            ZStack {
                if let imageURL = imageURL {
                    PTAsyncImage(url: imageURL, targetSize: CGSize(width: finalWidth, height: finalHeight)) {
                        fallbackView
                    }
                    .aspectRatio(aspectRatio, contentMode: .fit)
                    .frame(width: finalWidth, height: finalHeight)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .shadow(
                        color: Color.black.opacity(0.2), 
                        radius: shadowRadius, 
                        x: 0, 
                        y: shadowRadius * 0.5
                    )
                } else {
                    fallbackView
                        .frame(width: finalWidth, height: finalHeight)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        .shadow(
                            color: Color.black.opacity(0.2), 
                            radius: shadowRadius, 
                            x: 0, 
                            y: shadowRadius * 0.5
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .clipped()
        }
    }
}

// MARK: - Convenience Extensions

extension ResponsiveArtworkView {
    /// Creates a square artwork view with PT design defaults
    static func square(
        imageURL: URL?,
        maxSize: CGFloat = 350,
        @ViewBuilder fallbackContent: @escaping () -> some View
    ) -> ResponsiveArtworkView {
        ResponsiveArtworkView(
            imageURL: imageURL,
            maxSize: maxSize,
            aspectRatio: 1.0,
            cornerRadius: PTDesignTokens.BorderRadius.xl,
            shadowRadius: 12,
            fallbackContent: fallbackContent
        )
    }
    
    /// Creates a 16:9 artwork view for video content
    static func widescreen(
        imageURL: URL?,
        maxSize: CGFloat = 400,
        @ViewBuilder fallbackContent: @escaping () -> some View
    ) -> ResponsiveArtworkView {
        ResponsiveArtworkView(
            imageURL: imageURL,
            maxSize: maxSize,
            aspectRatio: 16/9,
            cornerRadius: PTDesignTokens.BorderRadius.lg,
            shadowRadius: 8,
            fallbackContent: fallbackContent
        )
    }
    
    /// Creates a 4:3 artwork view for traditional media
    static func traditional(
        imageURL: URL?,
        maxSize: CGFloat = 380,
        @ViewBuilder fallbackContent: @escaping () -> some View
    ) -> ResponsiveArtworkView {
        ResponsiveArtworkView(
            imageURL: imageURL,
            maxSize: maxSize,
            aspectRatio: 4/3,
            cornerRadius: PTDesignTokens.BorderRadius.lg,
            shadowRadius: 10,
            fallbackContent: fallbackContent
        )
    }
}

// MARK: - Media Artwork View for Player

struct MediaArtworkView: View {
    let imageURL: URL?
    let fallbackImage: UIImage?
    let isInteractive: Bool
    let onTap: (() -> Void)?
    let onLongPress: (() -> Void)?
    
    @State private var isPressed = false
    @State private var rotation: Double = 0
    
    init(
        imageURL: URL?,
        fallbackImage: UIImage? = nil,
        isInteractive: Bool = true,
        onTap: (() -> Void)? = nil,
        onLongPress: (() -> Void)? = nil
    ) {
        self.imageURL = imageURL
        self.fallbackImage = fallbackImage
        self.isInteractive = isInteractive
        self.onTap = onTap
        self.onLongPress = onLongPress
    }
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height) * 0.85
            
            VStack {
                Spacer()
                
                ZStack {
                    // Drop shadow
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.black.opacity(0.25))
                        .frame(width: size, height: size)
                        .offset(x: 0, y: 6)
                        .blur(radius: 12)
                    
                    // Main artwork
                    Group {
                        if let fallbackImage = fallbackImage {
                            Image(uiImage: fallbackImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else if let imageURL = imageURL {
                            PTAsyncImage(url: imageURL) {
                                defaultArtworkPlaceholder
                            }
                            .aspectRatio(contentMode: .fill)
                        } else {
                            defaultArtworkPlaceholder
                        }
                    }
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .scaleEffect(isPressed ? 0.95 : 1.0)
                    .rotationEffect(.degrees(rotation))
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                if isInteractive {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        rotation += 180
                    }
                    onTap?()
                }
            }
            .onLongPressGesture(minimumDuration: 0.1) {
                onLongPress?()
            } onPressingChanged: { pressing in
                if isInteractive {
                    withAnimation(.easeOut(duration: 0.1)) {
                        isPressed = pressing
                    }
                }
            }
        }
    }
    
    private var defaultArtworkPlaceholder: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            
            VStack(spacing: 8) {
                Image(systemName: "music.note")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                
                Text("Loading...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview

struct ResponsiveArtworkView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Square artwork
            ResponsiveArtworkView.square(imageURL: nil) {
                Rectangle()
                    .fill(.blue.opacity(0.3))
                    .overlay(
                        Text("Square\nArtwork")
                            .multilineTextAlignment(.center)
                    )
            }
            .frame(height: 200)
            
            // Widescreen artwork
            ResponsiveArtworkView.widescreen(imageURL: nil) {
                Rectangle()
                    .fill(.green.opacity(0.3))
                    .overlay(
                        Text("16:9 Artwork")
                    )
            }
            .frame(height: 150)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
