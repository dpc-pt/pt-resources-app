//
//  MainTabView.swift
//  PT Resources
//
//  Main tab navigation for the PT Resources app
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject private var serviceContainer: ServiceContainer

    var body: some View {
        TabView(selection: $navigationCoordinator.selectedTab) {
            // Home Tab
            HomeView(selectedTab: Binding(
                get: { navigationCoordinator.selectedTab.rawValue },
                set: { navigationCoordinator.selectedTab = TabSelection(rawValue: $0) ?? .home }
            ))
                .withServices(serviceContainer)
                .tabItem {
                    Image(systemName: TabSelection.home.iconName)
                    Text(TabSelection.home.title)
                }
                .tag(TabSelection.home)
                .accessibilityIdentifier(TabSelection.home.accessibilityIdentifier)

            // Resources Tab
            TalksListView()
                .withServices(serviceContainer)
                .tabItem {
                    Image(systemName: TabSelection.resources.iconName)
                    Text(TabSelection.resources.title)
                }
                .tag(TabSelection.resources)
                .accessibilityIdentifier(TabSelection.resources.accessibilityIdentifier)

            // Conferences Tab
            ConferencesListView()
                .withServices(serviceContainer)
                .tabItem {
                    Image(systemName: TabSelection.conferences.iconName)
                    Text(TabSelection.conferences.title)
                }
                .tag(TabSelection.conferences)
                .accessibilityIdentifier(TabSelection.conferences.accessibilityIdentifier)

            // Blog Tab
            BlogListView()
                .withServices(serviceContainer)
                .tabItem {
                    Image(systemName: TabSelection.blog.iconName)
                    Text(TabSelection.blog.title)
                }
                .tag(TabSelection.blog)
                .accessibilityIdentifier(TabSelection.blog.accessibilityIdentifier)

            // Downloads Tab
            DownloadsView()
                .withServices(serviceContainer)
                .tabItem {
                    Image(systemName: TabSelection.downloads.iconName)
                    Text(TabSelection.downloads.title)
                }
                .tag(TabSelection.downloads)
                .accessibilityIdentifier(TabSelection.downloads.accessibilityIdentifier)

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
