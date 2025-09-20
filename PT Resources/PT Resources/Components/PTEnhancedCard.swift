//
//  PTEnhancedCard.swift
//  PT Resources
//
//  Enhanced card component with advanced animations and micro-interactions
//

import SwiftUI

// MARK: - Card Style Types

enum PTCardStyle {
    case standard
    case elevated
    case outlined
    case filled
    case gradient

    var backgroundColor: Color {
        switch self {
        case .standard, .elevated: return PTDesignTokens.Colors.surface
        case .outlined: return .clear
        case .filled: return PTDesignTokens.Colors.veryLight
        case .gradient: return .clear
        }
    }

    var borderColor: Color {
        switch self {
        case .standard, .elevated, .filled, .gradient: return PTDesignTokens.Colors.border
        case .outlined: return PTDesignTokens.Colors.medium
        }
    }

    var shadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        switch self {
        case .standard: 
            let s = PTDesignTokens.Shadows.light
            return (color: s.color, radius: CGFloat(s.radius), x: CGFloat(s.x), y: CGFloat(s.y))
        case .elevated:
            let s = PTDesignTokens.Shadows.large
            return (color: s.color, radius: CGFloat(s.radius), x: CGFloat(s.x), y: CGFloat(s.y))
        case .outlined, .filled, .gradient:
            let s = PTDesignTokens.Shadows.light
            return (color: s.color, radius: CGFloat(s.radius), x: CGFloat(s.x), y: CGFloat(s.y))
        }
    }
}

// MARK: - Card Size Types

enum PTCardSize {
    case small
    case medium
    case large
    case extraLarge

    var padding: EdgeInsets {
        switch self {
        case .small: return EdgeInsets(top: PTDesignTokens.Spacing.sm, leading: PTDesignTokens.Spacing.sm, bottom: PTDesignTokens.Spacing.sm, trailing: PTDesignTokens.Spacing.sm)
        case .medium: return EdgeInsets(top: PTDesignTokens.Spacing.md, leading: PTDesignTokens.Spacing.md, bottom: PTDesignTokens.Spacing.md, trailing: PTDesignTokens.Spacing.md)
        case .large: return EdgeInsets(top: PTDesignTokens.Spacing.lg, leading: PTDesignTokens.Spacing.lg, bottom: PTDesignTokens.Spacing.lg, trailing: PTDesignTokens.Spacing.lg)
        case .extraLarge: return EdgeInsets(top: PTDesignTokens.Spacing.xl, leading: PTDesignTokens.Spacing.xl, bottom: PTDesignTokens.Spacing.xl, trailing: PTDesignTokens.Spacing.xl)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .small: return PTDesignTokens.BorderRadius.sm
        case .medium: return PTDesignTokens.BorderRadius.base
        case .large, .extraLarge: return PTDesignTokens.BorderRadius.lg
        }
    }
}

// MARK: - Enhanced Card Component

struct PTEnhancedCard<Content: View>: View {
    let style: PTCardStyle
    let size: PTCardSize
    let isInteractive: Bool
    let onTap: (() -> Void)?
    let content: () -> Content

    @State private var isPressed = false
    @State private var isHovered = false
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    private var shadowRadius: CGFloat {
        if isInteractive && isPressed {
            return style.shadow.radius / 2
        } else if isInteractive && isHovered {
            return style.shadow.radius * 1.5
        } else {
            return style.shadow.radius
        }
    }

    private var shadowOffset: CGSize {
        if isInteractive && isPressed {
            return CGSize(width: 0, height: 1)
        } else {
            return CGSize(width: style.shadow.x, height: style.shadow.y)
        }
    }

    private var backgroundView: some View {
        Group {
            switch style {
            case .standard, .elevated, .outlined, .filled:
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .fill(style.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: size.cornerRadius)
                            .stroke(style.borderColor, lineWidth: style != .outlined ? 0.5 : 1.5)
                    )

            case .gradient:
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                PTDesignTokens.Colors.primary.opacity(0.1),
                                PTDesignTokens.Colors.secondary.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: size.cornerRadius)
                            .stroke(PTDesignTokens.Colors.primary.opacity(0.2), lineWidth: 1)
                    )
            }
        }
    }

    var body: some View {
        Group {
            if let onTap = onTap {
                Button(action: performTap) {
                    cardContent
                }
                .buttonStyle(PTCardButtonStyle())
            } else {
                cardContent
            }
        }
    }

    private var cardContent: some View {
        ZStack {
            backgroundView

            content()
                .padding(size.padding)
        }
        .scaleEffect(scale)
        .offset(offset)
        .shadow(
            color: Color.black.opacity(isInteractive && isHovered ? 0.2 : 0.1),
            radius: shadowRadius,
            x: shadowOffset.width,
            y: shadowOffset.height
        )
        .gesture(
            isInteractive ?
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if isInteractive {
                            isPressed = true
                            scale = 0.98
                            offset = value.translation
                        }
                    }
                    .onEnded { value in
                        if isInteractive {
                            isPressed = false
                            scale = 1.0
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                offset = .zero
                            }
                        }
                    }
            : nil
        )
        .onHover { hovering in
            if isInteractive {
                withAnimation(.easeOut(duration: 0.2)) {
                    isHovered = hovering
                    if hovering {
                        scale = 1.02
                    } else {
                        scale = 1.0
                    }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    }

    private func performTap() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        // Animation
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            isPressed = true
            scale = 0.95
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = false
                scale = 1.0
            }
        }

        onTap?()
    }
}

// MARK: - Custom Card Button Style

struct PTCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Specialized Card Types

struct PTMediaCard: View {
    let imageURL: URL?
    let title: String
    let subtitle: String?
    let description: String?
    let style: PTCardStyle
    let onTap: () -> Void

    var body: some View {
        PTEnhancedCard(style: style, size: .medium, isInteractive: true, onTap: onTap) {
            VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.sm) {
                if let imageURL = imageURL {
                    PTAsyncImage(url: imageURL, targetSize: CGSize(width: 300, height: 200)) {
                        RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.sm)
                            .fill(PTDesignTokens.Colors.veryLight)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(PTDesignTokens.Colors.medium)
                            )
                    }
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.sm))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(PTFont.ptCardTitle)
                        .foregroundColor(PTDesignTokens.Colors.ink)
                        .lineLimit(2)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(PTFont.ptCardSubtitle)
                            .foregroundColor(PTDesignTokens.Colors.tang)
                            .lineLimit(1)
                    }

                    if let description = description {
                        Text(description)
                            .font(PTFont.ptSmallText)
                            .foregroundColor(PTDesignTokens.Colors.medium)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
        }
    }
}

struct PTStatsCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: Image?
    let trend: Trend?
    let style: PTCardStyle

    enum Trend {
        case up(Double)
        case down(Double)
        case neutral

        var color: Color {
            switch self {
            case .up: return PTDesignTokens.Colors.success
            case .down: return PTDesignTokens.Colors.error
            case .neutral: return PTDesignTokens.Colors.medium
            }
        }

        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .neutral: return "minus"
            }
        }
    }

    var body: some View {
        PTEnhancedCard(style: style, size: .medium, isInteractive: false, onTap: nil) {
            HStack(alignment: .top, spacing: PTDesignTokens.Spacing.md) {
                if let icon = icon {
                    icon
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .foregroundColor(PTDesignTokens.Colors.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(PTDesignTokens.Colors.medium)

                    Text(value)
                        .font(PTFont.ptDisplayMedium)
                        .foregroundColor(PTDesignTokens.Colors.ink)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(PTFont.ptSmallText)
                            .foregroundColor(PTDesignTokens.Colors.medium)
                    }
                }

                Spacer()

                if let trend = trend {
                    VStack(alignment: .trailing, spacing: 2) {
                        Image(systemName: trend.icon)
                            .foregroundColor(trend.color)
                            .font(.system(size: 12))

                        switch trend {
                        case .up(let percentage), .down(let percentage):
                            Text("\(String(format: "%.1f", percentage))%")
                                .font(PTFont.ptCaptionText)
                                .foregroundColor(trend.color)
                        case .neutral:
                            EmptyView()
                        }
                    }
                }
            }
        }
    }
}

struct PTActionCard: View {
    let title: String
    let description: String?
    let icon: Image
    let actionTitle: String
    let style: PTCardStyle
    let onAction: () -> Void

    var body: some View {
        PTEnhancedCard(style: style, size: .large, isInteractive: true, onTap: onAction) {
            VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.md) {
                HStack(spacing: PTDesignTokens.Spacing.md) {
                    icon
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .foregroundColor(PTDesignTokens.Colors.primary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(PTFont.ptSectionTitle)
                            .foregroundColor(PTDesignTokens.Colors.ink)

                        if let description = description {
                            Text(description)
                                .font(PTFont.ptBodyText)
                                .foregroundColor(PTDesignTokens.Colors.medium)
                        }
                    }
                }

                PTEnhancedButton(actionTitle, style: .primary, size: .medium) {
                    onAction()
                }
            }
        }
    }
}

// MARK: - Card Grid

struct PTCardGrid<Content: View>: View {
    let columns: Int
    let spacing: CGFloat
    let content: () -> Content

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns),
            spacing: spacing
        ) {
            content()
        }
    }
}

// MARK: - Preview

struct PTEnhancedCard_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                PTMediaCard(
                    imageURL: URL(string: "https://example.com/image.jpg"),
                    title: "The Gospel According to John",
                    subtitle: "John Smith",
                    description: "A comprehensive study of the fourth Gospel",
                    style: .elevated
                ) {
                    print("Card tapped")
                }

                PTStatsCard(
                    title: "Total Talks",
                    value: "1,247",
                    subtitle: "12% increase",
                    icon: Image(systemName: "headphones"),
                    trend: .up(12.5),
                    style: .standard
                )

                PTActionCard(
                    title: "Download Latest",
                    description: "Get the most recent talks and conferences",
                    icon: Image(systemName: "arrow.down.circle.fill"),
                    actionTitle: "Download Now",
                    style: .gradient
                ) {
                    print("Download action")
                }
            }
            .padding()
        }
        .previewLayout(.sizeThatFits)
    }
}
