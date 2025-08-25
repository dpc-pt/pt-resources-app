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

            // Downloads Tab (Future)
            PTComingSoonView(feature: "Downloads", description: "Access your downloaded talks offline")
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
        .tint(.ptCoral)
        .onAppear {
            // Configure tab bar appearance
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color.ptSurface)
            
            // Selected tab color
            appearance.selectionIndicatorTintColor = UIColor(Color.ptCoral)
            
            // Tab item colors
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color.ptDarkGray)
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .foregroundColor: UIColor(Color.ptDarkGray)
            ]
            
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.ptCoral)
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .foregroundColor: UIColor(Color.ptCoral)
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
                Color.ptBackground.ignoresSafeArea()
                
                VStack(spacing: PTSpacing.xl) {
                    PTLogo(size: 80, showText: false)
                    
                    VStack(spacing: PTSpacing.md) {
                        Text("\(feature) Coming Soon")
                            .font(PTFont.ptSectionTitle)
                            .foregroundColor(.ptPrimary)
                        
                        Text(description)
                            .font(PTFont.ptBodyText)
                            .foregroundColor(.ptDarkGray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, PTSpacing.xl)
                    }
                    
                    Button("Stay Tuned") {
                        // Haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                    }
                    .ptPrimaryButton()
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
