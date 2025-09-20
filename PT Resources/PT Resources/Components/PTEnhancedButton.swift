//
//  PTEnhancedButton.swift
//  PT Resources
//
//  Enhanced button component with micro-interactions and advanced animations
//

import SwiftUI

// MARK: - Button Style Types

enum PTButtonStyle {
    case primary
    case secondary
    case outline
    case ghost
    case danger
    case success
    case warning

    var backgroundColor: Color {
        switch self {
        case .primary: return PTDesignTokens.Colors.primary
        case .secondary: return PTDesignTokens.Colors.secondary
        case .outline, .ghost: return .clear
        case .danger: return PTDesignTokens.Colors.error
        case .success: return PTDesignTokens.Colors.success
        case .warning: return PTDesignTokens.Colors.warning
        }
    }

    var foregroundColor: Color {
        switch self {
        case .primary, .danger, .success, .warning: return .white
        case .secondary: return .white
        case .outline: return PTDesignTokens.Colors.primary
        case .ghost: return PTDesignTokens.Colors.primary
        }
    }

    var borderColor: Color {
        switch self {
        case .primary, .secondary, .danger, .success, .warning: return .clear
        case .outline: return PTDesignTokens.Colors.primary
        case .ghost: return .clear
        }
    }
}

// MARK: - Button Size Types

enum PTButtonSize {
    case small
    case medium
    case large
    case extraLarge

    var height: CGFloat {
        switch self {
        case .small: return 32
        case .medium: return 44
        case .large: return 52
        case .extraLarge: return 60
        }
    }

    var font: Font {
        switch self {
        case .small: return PTFont.ptSmallText
        case .medium: return PTFont.ptButtonText
        case .large, .extraLarge: return PTFont.ptBodyText
        }
    }

    var padding: EdgeInsets {
        switch self {
        case .small: return EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        case .medium: return EdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24)
        case .large: return EdgeInsets(top: 16, leading: 32, bottom: 16, trailing: 32)
        case .extraLarge: return EdgeInsets(top: 20, leading: 40, bottom: 20, trailing: 40)
        }
    }
}

// MARK: - Enhanced Button Component

struct PTEnhancedButton: View {
    let title: String
    let style: PTButtonStyle
    let size: PTButtonSize
    let isLoading: Bool
    let isDisabled: Bool
    let leftIcon: Image?
    let rightIcon: Image?
    let action: () -> Void

    @State private var isPressed = false
    @State private var scale: CGFloat = 1.0

    private var buttonOpacity: Double {
        isDisabled ? 0.6 : 1.0
    }

    private var shadowRadius: CGFloat {
        isPressed ? PTDesignTokens.Shadows.light.radius / 2 : PTDesignTokens.Shadows.light.radius
    }

    private var shadowOffset: CGSize {
        isPressed ? CGSize(width: 0, height: 1) : CGSize(width: PTDesignTokens.Shadows.light.x, height: PTDesignTokens.Shadows.light.y)
    }

    var body: some View {
        Button(action: performAction) {
            ZStack {
                // Background with gradient
                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                style.backgroundColor.opacity(isPressed ? 0.8 : 1.0),
                                style.backgroundColor.opacity(isPressed ? 0.9 : 1.0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        // Border for outline style
                        RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                            .stroke(style.borderColor, lineWidth: style == .outline ? 2 : 0)
                    )

                // Content
                HStack(spacing: PTDesignTokens.Spacing.sm) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: style.foregroundColor))
                            .scaleEffect(0.8)
                    } else if let leftIcon = leftIcon {
                        leftIcon
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundColor(style.foregroundColor)
                    }

                    Text(title)
                        .font(size.font)
                        .foregroundColor(style.foregroundColor)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)

                    if let rightIcon = rightIcon {
                        rightIcon
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundColor(style.foregroundColor)
                    }
                }
                .padding(size.padding)
            }
            .frame(height: size.height)
            .opacity(buttonOpacity)
        }
        .buttonStyle(PTEnhancedButtonStyle())
        .disabled(isDisabled || isLoading)
        .scaleEffect(scale)
        .shadow(
            color: Color.black.opacity(0.15),
            radius: shadowRadius,
            x: shadowOffset.width,
            y: shadowOffset.height
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityHint(isLoading ? "Loading" : "Tap to \(title.lowercased())")
        .accessibilityAddTraits(isDisabled ? .isButton : .isButton)
    }

    private func performAction() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Animation
        withAnimation(PTDesignTokens.Animation.bouncy) {
            isPressed = true
            scale = 0.95
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(PTDesignTokens.Animation.bouncy) {
                isPressed = false
                scale = 1.0
            }
        }

        action()
    }
}

// MARK: - Custom Button Style

struct PTEnhancedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: PTDesignTokens.Animation.fast), value: configuration.isPressed)
    }
}

// MARK: - Convenience Initializers

extension PTEnhancedButton {
    init(_ title: String, style: PTButtonStyle = .primary, size: PTButtonSize = .medium, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.size = size
        self.isLoading = false
        self.isDisabled = false
        self.leftIcon = nil
        self.rightIcon = nil
        self.action = action
    }

    init(_ title: String, style: PTButtonStyle = .primary, size: PTButtonSize = .medium, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.size = size
        self.isLoading = isLoading
        self.isDisabled = false
        self.leftIcon = nil
        self.rightIcon = nil
        self.action = action
    }

    init(_ title: String, style: PTButtonStyle = .primary, size: PTButtonSize = .medium, leftIcon: Image? = nil, rightIcon: Image? = nil, isLoading: Bool = false, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.size = size
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.leftIcon = leftIcon
        self.rightIcon = rightIcon
        self.action = action
    }
}

// MARK: - Loading Button

struct PTLoadingButton: View {
    let title: String
    let style: PTButtonStyle
    let size: PTButtonSize
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        PTEnhancedButton(title, style: style, size: size, isLoading: isLoading, action: action)
    }
}

// MARK: - Icon Button

struct PTIconButton: View {
    let icon: Image
    let style: PTButtonStyle
    let size: PTButtonSize
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        PTEnhancedButton("", style: style, size: size, isLoading: isLoading) {
            // This is handled by the icon-only button
        }
        .overlay(
            icon
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundColor(style.foregroundColor)
        )
    }
}

// MARK: - Floating Action Button

struct PTFloatingActionButton: View {
    let icon: Image
    let style: PTButtonStyle
    let action: () -> Void

    @State private var isExpanded = false
    @State private var scale: CGFloat = 1.0

    var body: some View {
        Button(action: performAction) {
            ZStack {
                Circle()
                    .fill(style.backgroundColor)
                    .frame(width: 56, height: 56)

                icon
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PTEnhancedButtonStyle())
        .scaleEffect(scale)
        .shadow(
            color: Color.black.opacity(0.25),
            radius: 8,
            x: 0,
            y: 4
        )
        .accessibilityLabel("Floating action button")
        .accessibilityHint("Tap to perform action")
    }

    private func performAction() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        withAnimation(PTDesignTokens.Animation.bouncy) {
            scale = 0.9
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(PTDesignTokens.Animation.bouncy) {
                scale = 1.0
            }
        }

        action()
    }
}

// MARK: - Button Group

struct PTButtonGroup<Content: View>: View {
    let style: PTButtonStyle
    let content: () -> Content

    var body: some View {
        HStack(spacing: PTDesignTokens.Spacing.sm) {
            content()
        }
        .padding(PTDesignTokens.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.base)
                .fill(PTDesignTokens.Colors.surface)
                .shadow(
                    color: Color.black.opacity(0.05),
                    radius: 2,
                    x: 0,
                    y: 1
                )
        )
    }
}

// MARK: - Preview

struct PTEnhancedButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            PTEnhancedButton("Primary Button") {
                print("Primary tapped")
            }

            PTEnhancedButton("Secondary", style: .secondary) {
                print("Secondary tapped")
            }

            PTEnhancedButton("Outline", style: .outline) {
                print("Outline tapped")
            }

            PTEnhancedButton("Loading", isLoading: true) {
                print("Loading tapped")
            }

            PTLoadingButton(title: "Save", style: .success, size: .large, isLoading: false) {
                print("Save tapped")
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
