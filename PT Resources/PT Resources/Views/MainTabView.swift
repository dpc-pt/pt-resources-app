//
//  MainTabView.swift
//  PT Resources
//
//  Main tab navigation for the PT Resources app
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            HomeView(selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
                .accessibilityIdentifier(PTAccessibility.homeTab)

            // Resources Tab
            TalksListView()
                .tabItem {
                    Image(systemName: "waveform.circle.fill")
                    Text("Resources")
                }
                .tag(1)
                .accessibilityIdentifier(PTAccessibility.talksTab)

            // Blog Tab
            BlogListView()
                .tabItem {
                    Image(systemName: "newspaper.fill")
                    Text("Blog")
                }
                .tag(2)
                .accessibilityIdentifier(PTAccessibility.blogTab)

            // Settings Tab
            SettingsView()
                .tabItem {
                    Image(systemName: "gear.circle.fill")
                    Text("Settings")
                }
                .tag(3)
                .accessibilityIdentifier("SettingsTab")
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



// MARK: - Previews

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
