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
    @State private var backgroundOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            // Solid PT Blue Background
            PTDesignTokens.Colors.kleinBlue
                .opacity(backgroundOpacity)
                .ignoresSafeArea()
            
            // Background pattern using authentic PT icon pattern
            PTIconPattern()
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // PT Logo with proper padding
                VStack(spacing: 24) {
                    // Authentic PT logo icon from SVG with padding
                    PTLogo(size: 120, showText: true)
                        .padding(.all, 32) // Padding on all sides
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                }
                
                Spacer()
                
                // Loading indicator
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        PTLogo(size: 16, showText: false)
                            .padding(.all, 4) // Small padding around loading logo
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
    }
    
    private func startAnimationSequence() {
        // Background appears first
        withAnimation(.easeOut(duration: 0.5)) {
            backgroundOpacity = 1.0
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
                    .fill(PTDesignTokens.Colors.tang)
                    .frame(
                        width: size * (index % 2 == 0 ? 0.08 : 0.06),
                        height: size * (index % 2 == 0 ? 0.5 : 0.3)
                    )
                    .offset(y: -size * 0.2)
                    .rotationEffect(.degrees(Double(index) * 30))
            }
            
            // Center circle with inner detail
            Circle()
                .fill(PTDesignTokens.Colors.tang)
                .frame(width: size * 0.15, height: size * 0.15)
                .overlay(
                    Circle()
                        .fill(PTDesignTokens.Colors.tang.opacity(0.8))
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

// MARK: - PT Icon Pattern Background

struct PTIconPattern: View {
    var body: some View {
        GeometryReader { geometry in
            // Single PT icon pattern at bottom right
            Image("pt-icon-pattern")
                .resizable()
                .scaledToFit()
                .frame(width: 280, height: 280)
                .position(
                    x: geometry.size.width * 0.85,
                    y: geometry.size.height * 0.85
                )
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
