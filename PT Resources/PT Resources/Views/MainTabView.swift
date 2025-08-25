//
//  MainTabView.swift
//  PT Resources
//
//  Main tab navigation for the PT Resources app
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            // Home Tab
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
                .accessibilityIdentifier(PTAccessibility.homeTab)

            // Resources Tab
            TalksListView()
                .tabItem {
                    Image(systemName: "play.rectangle.stack.fill")
                    Text("Resources")
                }
                .tag(1)
                .accessibilityIdentifier(PTAccessibility.talksTab)

            // Downloads Tab
            DownloadsView()
                .tabItem {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("Downloads")
                }
                .tag(2)
                .accessibilityIdentifier(PTAccessibility.downloadsTab)

            // More Tab (Future)
            PTComingSoonView(feature: "More", description: "Settings, about, and additional features")
                .tabItem {
                    Image(systemName: "ellipsis.circle.fill")
                    Text("More")
                }
                .tag(3)
                .accessibilityIdentifier(PTAccessibility.moreTab)
        }
        .tint(PTDesignTokens.Colors.tang)  // Using PT Tang for selected state
        .onAppear {
            // Configure tab bar appearance with PT design tokens
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(PTDesignTokens.Colors.surface)
            
            // Selected tab color (PT Tang)
            appearance.selectionIndicatorTintColor = UIColor(PTDesignTokens.Colors.tang)
            
            // Tab item colors using PT design tokens
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor(PTDesignTokens.Colors.medium)
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .foregroundColor: UIColor(PTDesignTokens.Colors.medium)
            ]
            
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor(PTDesignTokens.Colors.tang)
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .foregroundColor: UIColor(PTDesignTokens.Colors.tang)
            ]
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

// MARK: - Coming Soon View

struct PTComingSoonView: View {
    let feature: String
    let description: String
    
    var body: some View {
        NavigationStack {
            ZStack {
                PTDesignTokens.Colors.background.ignoresSafeArea()  // Using PT background color
                
                VStack(spacing: PTDesignTokens.Spacing.xl) {
                    PTLogo(size: 80, showText: false)
                    
                    VStack(spacing: PTDesignTokens.Spacing.md) {
                        Text("\(feature) Coming Soon")
                            .font(PTFont.ptSectionTitle)  // Using PT section title typography
                            .foregroundColor(PTDesignTokens.Colors.ink)  // Using PT Ink for primary text
                        
                        Text(description)
                            .font(PTFont.ptBodyText)  // Using PT body typography
                            .foregroundColor(PTDesignTokens.Colors.medium)  // Using consistent medium gray
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, PTDesignTokens.Spacing.xl)
                    }
                    
                    Button("Stay Tuned") {
                        // Haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(PTDesignTokens.Colors.tang)
                    .clipShape(RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button))
                }
            }
            .navigationTitle(feature)
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Previews

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
