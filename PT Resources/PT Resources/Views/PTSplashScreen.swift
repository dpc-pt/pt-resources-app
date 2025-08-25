//
//  PTSplashScreen.swift
//  PT Resources
//
//  Beautiful loading screen with authentic PT branding
//

import SwiftUI

struct PTSplashScreen: View {
    @State private var isAnimating = false
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.0
    @State private var textOpacity: Double = 0.0
    @State private var backgroundGradientOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.ptNavy,
                    Color.ptNavy.opacity(0.9),
                    Color.ptPrimary.opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(backgroundGradientOpacity)
            .ignoresSafeArea()
            
            // Background pattern (subtle)
            PTBackgroundPattern()
                .opacity(0.1)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // PT Logo
                VStack(spacing: 24) {
                    // Authentic PT logo icon from SVG
                    PTLogo(size: 120, showText: true)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                    
                    // PT Resources text
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Text("pt")
                                .font(PTFont.ptDisplayLarge)
                                .foregroundColor(.ptCoral)
                            Text("resources")
                                .font(PTFont.ptDisplayMedium)
                                .foregroundColor(.white)
                        }
                        
                        Text("Proclamation Trust")
                            .font(PTFont.ptLogoText)
                            .foregroundColor(.white.opacity(0.8))
                            .tracking(2)
                    }
                    .opacity(textOpacity)
                }
                
                Spacer()
                
                // Loading indicator
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        PTLogo(size: 16, showText: false)
                            .rotationEffect(.degrees(isAnimating ? 360 : 0))
                            .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: isAnimating)
                        
                        PTLoadingDots()
                    }
                    .opacity(isAnimating ? 1.0 : 0.0)
                    
                    Text("Loading resources...")
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(.white.opacity(0.7))
                        .opacity(isAnimating ? 1.0 : 0.0)
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            startAnimationSequence()
        }
        .registerPTFonts()
    }
    
    private func startAnimationSequence() {
        // Background appears first
        withAnimation(.easeOut(duration: 0.5)) {
            backgroundGradientOpacity = 1.0
        }
        
        // Logo appears and scales up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.6)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
        }
        
        // Text appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.8)) {
                textOpacity = 1.0
            }
        }
        
        // Loading animation starts
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.5)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Authentic PT Star Symbol

struct PTAuthenticStarSymbol: View {
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Main star burst - more authentic to PT branding
            ForEach(0..<12, id: \.self) { index in
                RoundedRectangle(cornerRadius: size * 0.02)
                    .fill(Color.ptCoral)
                    .frame(
                        width: size * (index % 2 == 0 ? 0.08 : 0.06),
                        height: size * (index % 2 == 0 ? 0.5 : 0.3)
                    )
                    .offset(y: -size * 0.2)
                    .rotationEffect(.degrees(Double(index) * 30))
            }
            
            // Center circle with inner detail
            Circle()
                .fill(Color.ptCoral)
                .frame(width: size * 0.15, height: size * 0.15)
                .overlay(
                    Circle()
                        .fill(Color.ptCoral.opacity(0.8))
                        .frame(width: size * 0.08, height: size * 0.08)
                )
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Loading Dots Animation

struct PTLoadingDots: View {
    @State private var animationPhase = 0
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 8, height: 8)
                    .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                    .opacity(animationPhase == index ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: false),
                        value: animationPhase
                    )
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
                withAnimation {
                    animationPhase = (animationPhase + 1) % 3
                }
            }
        }
    }
}

// MARK: - Background Pattern

struct PTBackgroundPattern: View {
    var body: some View {
        Canvas { context, size in
            let dotSize: CGFloat = 2
            let spacing: CGFloat = 20
            
            for x in stride(from: 0, through: size.width, by: spacing) {
                for y in stride(from: 0, through: size.height, by: spacing) {
                    let opacity = Double.random(in: 0.1...0.3)
                    context.fill(
                        Circle()
                            .path(in: CGRect(x: x, y: y, width: dotSize, height: dotSize)),
                        with: .color(.white.opacity(opacity))
                    )
                }
            }
        }
    }
}

// MARK: - Preview

struct PTSplashScreen_Previews: PreviewProvider {
    static var previews: some View {
        PTSplashScreen()
            .preferredColorScheme(.dark)
    }
}
