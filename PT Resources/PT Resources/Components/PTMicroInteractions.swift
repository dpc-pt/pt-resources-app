//
//  PTMicroInteractions.swift
//  PT Resources
//
//  Advanced micro-interactions and animations for enhanced UX
//

import SwiftUI

// MARK: - Pulse Animation

struct PTPulseAnimation: ViewModifier {
    let scale: CGFloat
    let duration: Double
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? scale : 1.0)
            .opacity(isAnimating ? 0.7 : 1.0)
            .animation(
                Animation.easeInOut(duration: duration)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

extension View {
    func ptPulse(scale: CGFloat = 1.1, duration: Double = 1.0) -> some View {
        self.modifier(PTPulseAnimation(scale: scale, duration: duration))
    }
}

// MARK: - Bounce Animation

struct PTBounceAnimation: ViewModifier {
    let count: Int
    let duration: Double
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.0 : 0.8)
            .animation(
                Animation.spring(response: 0.4, dampingFraction: 0.6)
                    .repeatCount(count, autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

extension View {
    func ptBounce(count: Int = 1, duration: Double = 0.6) -> some View {
        self.modifier(PTBounceAnimation(count: count, duration: duration))
    }
}

// MARK: - Shimmer Effect

struct PTShimmerEffect: ViewModifier {
    let duration: Double
    let gradient: Gradient
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(gradient: gradient, startPoint: .leading, endPoint: .trailing)
                        .frame(width: geometry.size.width * 2)
                        .offset(x: isAnimating ? geometry.size.width * 2 : -geometry.size.width * 2)
                        .animation(
                            Animation.linear(duration: duration).repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                        .mask(content)
                        .blendMode(.overlay)
                }
            )
            .onAppear {
                isAnimating = true
            }
    }
}

extension View {
    func ptShimmer(duration: Double = 2.0) -> some View {
        let gradient = Gradient(colors: [
            Color.clear,
            Color.white.opacity(0.4),
            Color.clear
        ])
        return self.modifier(PTShimmerEffect(duration: duration, gradient: gradient))
    }
}

// MARK: - Slide In Animation

struct PTSlideInAnimation: ViewModifier {
    let direction: Edge
    let distance: CGFloat
    let duration: Double
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .offset(
                x: isAnimating ? 0 : (direction == .leading ? -distance : distance),
                y: isAnimating ? 0 : (direction == .top ? -distance : distance)
            )
            .opacity(isAnimating ? 1.0 : 0.0)
            .animation(
                Animation.spring(response: 0.6, dampingFraction: 0.8)
                    .delay(duration),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

extension View {
    func ptSlideIn(from direction: Edge = .leading, distance: CGFloat = 50, delay: Double = 0.0) -> some View {
        self.modifier(PTSlideInAnimation(direction: direction, distance: distance, duration: delay))
    }
}

// MARK: - Scale On Tap

struct PTScaleOnTap: ViewModifier {
    let scale: CGFloat
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isPressed = false
                            }
                        }
                    }
            )
    }
}

extension View {
    func ptScaleOnTap(scale: CGFloat = 0.95) -> some View {
        self.modifier(PTScaleOnTap(scale: scale))
    }
}

// MARK: - Rotation Animation

struct PTRotationAnimation: ViewModifier {
    let degrees: Double
    let duration: Double
    let clockwise: Bool
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isAnimating ? degrees : 0))
            .animation(
                Animation.linear(duration: duration).repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

extension View {
    func ptRotate(degrees: Double = 360, duration: Double = 2.0, clockwise: Bool = true) -> some View {
        self.modifier(PTRotationAnimation(degrees: degrees, duration: duration, clockwise: clockwise))
    }
}

// MARK: - Floating Animation

struct PTFloatingAnimation: ViewModifier {
    let distance: CGFloat
    let duration: Double
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .offset(y: isAnimating ? -distance : distance)
            .animation(
                Animation.easeInOut(duration: duration)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

extension View {
    func ptFloat(distance: CGFloat = 10, duration: Double = 2.0) -> some View {
        self.modifier(PTFloatingAnimation(distance: distance, duration: duration))
    }
}

// MARK: - Staggered Animation Container

struct PTStaggeredAnimation<Content: View>: View {
    let content: () -> Content
    let count: Int
    let delay: Double

    var body: some View {
        ForEach(0..<count, id: \.self) { index in
            content()
                .ptSlideIn(delay: Double(index) * delay)
        }
    }
}

// MARK: - Enhanced Loading Indicators


struct PTLoadingSpinner: View {
    let lineWidth: CGFloat
    let color: Color

    @State private var isAnimating = false

    var body: some View {
        Circle()
            .trim(from: 0.0, to: 0.7)
            .stroke(color, lineWidth: lineWidth)
            .frame(width: lineWidth * 4, height: lineWidth * 4)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(
                Animation.linear(duration: 1.0).repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Interactive Feedback

struct PTInteractiveFeedback: ViewModifier {
    let onTap: () -> Void
    let onLongPress: (() -> Void)?
    let hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle

    @State private var isPressed = false
    @State private var showRipple = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .overlay(
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .scaleEffect(showRipple ? 2.0 : 0.0)
                    .opacity(showRipple ? 0.0 : 1.0)
                    .animation(.easeOut(duration: 0.3), value: showRipple)
            )
            .gesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        UIImpactFeedbackGenerator(style: hapticStyle).impactOccurred()
                        onLongPress?()
                        showRippleEffect()
                    }
                    .sequenced(before:
                        TapGesture()
                            .onEnded { _ in
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onTap()
                                showRippleEffect()
                            }
                    )
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }

    private func showRippleEffect() {
        showRipple = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showRipple = false
        }
    }
}

extension View {
    func ptInteractiveFeedback(
        onTap: @escaping () -> Void,
        onLongPress: (() -> Void)? = nil,
        hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle = .medium
    ) -> some View {
        self.modifier(PTInteractiveFeedback(onTap: onTap, onLongPress: onLongPress, hapticStyle: hapticStyle))
    }
}

// MARK: - Success/Error Animations

struct PTSuccessAnimation: View {
    let onComplete: () -> Void

    @State private var scale: CGFloat = 0.0
    @State private var opacity: Double = 0.0

    var body: some View {
        ZStack {
            Circle()
                .fill(PTDesignTokens.Colors.success.opacity(0.2))
                .frame(width: 80, height: 80)
                .scaleEffect(scale)

            Circle()
                .fill(PTDesignTokens.Colors.success)
                .frame(width: 40, height: 40)
                .scaleEffect(scale * 0.8)

            Image(systemName: "checkmark")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .scaleEffect(scale)
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    opacity = 0.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onComplete()
                }
            }
        }
    }
}

struct PTErrorAnimation: View {
    let onComplete: () -> Void

    @State private var shakeOffset: CGFloat = 0.0
    @State private var opacity: Double = 1.0

    var body: some View {
        Image(systemName: "xmark.octagon.fill")
            .font(.system(size: 48))
            .foregroundColor(PTDesignTokens.Colors.error)
            .offset(x: shakeOffset)
            .opacity(opacity)
            .onAppear {
                // Shake animation
                withAnimation(Animation.easeInOut(duration: 0.1).repeatCount(3, autoreverses: true)) {
                    shakeOffset = 10
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        opacity = 0.0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onComplete()
                    }
                }
            }
    }
}

