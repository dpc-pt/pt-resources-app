//
//  NavigationCoordinator.swift
//  PT Resources
//
//  Centralized navigation coordinator for managing app-wide navigation state
//

import SwiftUI
import Foundation
import Combine

// MARK: - Navigation Destination

enum NavigationDestination: Hashable {
    case talkDetail(Talk)
    case conferenceDetail(String) // conferenceId
    case blogDetail(BlogPost)
    case resourceDetail(ResourceDetail)
    case nowPlaying
    case settings
    case downloads
    case privacySettings
    case aboutApp
    
    // Deep linking destinations
    case deepLink(URL)
    case share(String) // shareId
}

// MARK: - Tab Selection

enum TabSelection: Int, CaseIterable {
    case home = 0
    case resources = 1
    case conferences = 2
    case blog = 3
    case downloads = 4
    
    var title: String {
        switch self {
        case .home: return "Home"
        case .resources: return "Resources"
        case .conferences: return "Conferences"
        case .blog: return "Blog"
        case .downloads: return "Downloads"
        }
    }
    
    var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .resources: return "waveform.circle.fill"
        case .conferences: return "calendar.badge.clock"
        case .blog: return "quote.bubble"
        case .downloads: return "arrow.down.circle.fill"
        }
    }
    
    var accessibilityIdentifier: String {
        switch self {
        case .home: return PTAccessibility.homeTab
        case .resources: return PTAccessibility.talksTab
        case .conferences: return PTAccessibility.conferencesTab
        case .blog: return "BlogTab"
        case .downloads: return "DownloadsTab"
        }
    }
}

// MARK: - Navigation Coordinator Protocol

protocol NavigationCoordinatorProtocol: ObservableObject {
    var selectedTab: TabSelection { get set }
    var navigationPath: NavigationPath { get set }
    var presentedDestination: NavigationDestination? { get set }
    var isShowingModal: Bool { get }
    
    func navigate(to destination: NavigationDestination)
    func navigateToTab(_ tab: TabSelection)
    func present(_ destination: NavigationDestination)
    func dismiss()
    func popToRoot()
    func goBack()
    func handleDeepLink(_ url: URL)
}

// MARK: - Navigation Coordinator Implementation

@MainActor
final class NavigationCoordinator: ObservableObject, NavigationCoordinatorProtocol {
    
    // MARK: - Published Properties
    
    @Published var selectedTab: TabSelection = .home
    @Published var navigationPath = NavigationPath()
    @Published var presentedDestination: NavigationDestination?
    
    // MARK: - Computed Properties
    
    var isShowingModal: Bool {
        presentedDestination != nil
    }
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var navigationHistory: [NavigationDestination] = []
    private let maxHistorySize = 50
    
    // MARK: - Initialization
    
    init() {
        setupDeepLinkHandling()
        setupTabPersistence()
    }
    
    // MARK: - Navigation Methods
    
    func navigate(to destination: NavigationDestination) {
        // Add to history
        addToHistory(destination)
        
        // Handle different destination types
        switch destination {
        case .nowPlaying, .settings, .privacySettings, .aboutApp:
            // Modal presentations
            present(destination)
            
        case .talkDetail, .conferenceDetail, .blogDetail, .resourceDetail:
            // Push to navigation stack
            navigationPath.append(destination)
            
        case .downloads:
            // Navigate to downloads tab
            navigateToTab(.downloads)
            
        case .deepLink(let url):
            handleDeepLink(url)
            
        case .share(let shareId):
            handleShare(shareId: shareId)
        }
        
        PTLogger.general.info("Navigated to: \\(destination)")
    }
    
    func navigateToTab(_ tab: TabSelection) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedTab = tab
        }
        
        // Clear navigation path when switching tabs
        navigationPath = NavigationPath()
        
        PTLogger.general.info("Switched to tab: \\(tab.title)")
    }
    
    func present(_ destination: NavigationDestination) {
        withAnimation(.spring()) {
            presentedDestination = destination
        }
        addToHistory(destination)
    }
    
    func dismiss() {
        withAnimation(.spring()) {
            presentedDestination = nil
        }
    }
    
    func popToRoot() {
        navigationPath = NavigationPath()
    }
    
    func goBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        } else if presentedDestination != nil {
            dismiss()
        }
    }
    
    func handleDeepLink(_ url: URL) {
        PTLogger.general.info("Handling deep link: \\(url.absoluteString)")
        
        guard url.scheme == AppConfiguration.SecurityConstants.urlScheme else {
            PTLogger.general.warning("Invalid URL scheme for deep link: \\(url.scheme ?? \"nil\")")
            return
        }
        
        let path = url.path
        let components = path.components(separatedBy: "/").filter { !$0.isEmpty }
        
        guard !components.isEmpty else {
            // Just open to home
            navigateToTab(.home)
            return
        }
        
        switch components[0] {
        case "talk":
            if components.count > 1 {
                handleTalkDeepLink(talkId: components[1])
            }
            
        case "conference":
            if components.count > 1 {
                handleConferenceDeepLink(conferenceId: components[1])
            }
            
        case "blog":
            if components.count > 1 {
                handleBlogDeepLink(blogId: components[1])
            }
            
        case "resource":
            if components.count > 1 {
                handleResourceDeepLink(resourceId: components[1])
            }
            
        case "downloads":
            navigateToTab(.downloads)
            
        case "settings":
            present(.settings)
            
        case "now-playing":
            present(.nowPlaying)
            
        default:
            PTLogger.general.warning("Unhandled deep link path: \\(path)")
            navigateToTab(.home)
        }
    }
    
    // MARK: - Convenience Methods
    
    func navigateToTalk(_ talk: Talk) {
        navigate(to: .talkDetail(talk))
    }
    
    func navigateToConference(_ conferenceId: String) {
        navigate(to: .conferenceDetail(conferenceId))
    }
    
    func navigateToBlog(_ blogPost: BlogPost) {
        navigate(to: .blogDetail(blogPost))
    }
    
    func navigateToResource(_ resource: ResourceDetail) {
        navigate(to: .resourceDetail(resource))
    }
    
    func showNowPlaying() {
        present(.nowPlaying)
    }
    
    func showSettings() {
        present(.settings)
    }
    
    func showPrivacySettings() {
        present(.privacySettings)
    }
    
    func showAboutApp() {
        present(.aboutApp)
    }
    
    // MARK: - History Management
    
    var canGoBack: Bool {
        !navigationPath.isEmpty || presentedDestination != nil
    }
    
    var navigationHistoryCount: Int {
        navigationHistory.count
    }
    
    func clearHistory() {
        navigationHistory.removeAll()
        PTLogger.general.info("Navigation history cleared")
    }
    
    func getRecentDestinations() -> [NavigationDestination] {
        Array(navigationHistory.reversed().prefix(10))
    }
    
    // MARK: - Private Methods
    
    private func setupDeepLinkHandling() {
        // Listen for deep link notifications
        NotificationCenter.default.publisher(for: .deepLinkReceived)
            .compactMap { $0.object as? URL }
            .sink { [weak self] url in
                self?.handleDeepLink(url)
            }
            .store(in: &cancellables)
    }
    
    private func setupTabPersistence() {
        // Save selected tab to UserDefaults
        $selectedTab
            .sink { tab in
                UserDefaults.standard.set(tab.rawValue, forKey: "SelectedTab")
            }
            .store(in: &cancellables)
        
        // Load persisted tab on init
        let savedTab = UserDefaults.standard.integer(forKey: "SelectedTab")
        if let tab = TabSelection(rawValue: savedTab) {
            selectedTab = tab
        }
    }
    
    private func addToHistory(_ destination: NavigationDestination) {
        navigationHistory.append(destination)
        
        // Trim history if needed
        if navigationHistory.count > maxHistorySize {
            navigationHistory.removeFirst(navigationHistory.count - maxHistorySize)
        }
    }
    
    private func handleTalkDeepLink(talkId: String) {
        // Would need to fetch talk details first in a real implementation
        // For now, navigate to resources tab and search
        navigateToTab(.resources)
        
        // Post notification for search
        NotificationCenter.default.post(
            name: .searchForTalk,
            object: talkId
        )
    }
    
    private func handleConferenceDeepLink(conferenceId: String) {
        navigateToTab(.conferences)
        navigate(to: .conferenceDetail(conferenceId))
    }
    
    private func handleBlogDeepLink(blogId: String) {
        // Would need to fetch blog post details first
        navigateToTab(.blog)
        
        NotificationCenter.default.post(
            name: .searchForBlogPost,
            object: blogId
        )
    }
    
    private func handleResourceDeepLink(resourceId: String) {
        // Would need to fetch resource details first
        navigateToTab(.resources)
        
        NotificationCenter.default.post(
            name: .searchForResource,
            object: resourceId
        )
    }
    
    private func handleShare(shareId: String) {
        // Handle shared content
        PTLogger.general.info("Handling shared content: \\(shareId)")
        // Implementation would depend on share format
    }
}

// MARK: - Environment Integration

struct NavigationCoordinatorKey: EnvironmentKey {
    @MainActor
    static let defaultValue: NavigationCoordinator = NavigationCoordinator()
}

extension EnvironmentValues {
    var navigationCoordinator: NavigationCoordinator {
        get { self[NavigationCoordinatorKey.self] }
        set { self[NavigationCoordinatorKey.self] = newValue }
    }
}

// MARK: - View Extensions

extension View {
    func withNavigationCoordinator(_ coordinator: NavigationCoordinator) -> some View {
        environmentObject(coordinator)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let deepLinkReceived = Notification.Name("deepLinkReceived")
    static let searchForTalk = Notification.Name("searchForTalk")
    static let searchForBlogPost = Notification.Name("searchForBlogPost")
    static let searchForResource = Notification.Name("searchForResource")
}

// MARK: - Navigation Path Extensions

extension NavigationPath {
    var isEmpty: Bool {
        count == 0
    }
}

// MARK: - Deep Link URL Handling

extension NavigationCoordinator {
    
    static func createDeepLink(for destination: NavigationDestination) -> URL? {
        let baseURL = "\\(AppConfiguration.SecurityConstants.urlScheme)://"
        
        let path: String
        switch destination {
        case .talkDetail(let talk):
            path = "talk/\\(talk.id)"
        case .conferenceDetail(let conferenceId):
            path = "conference/\\(conferenceId)"
        case .blogDetail(let blogPost):
            path = "blog/\\(blogPost.id)"
        case .resourceDetail(let resource):
            path = "resource/\\(resource.id)"
        case .nowPlaying:
            path = "now-playing"
        case .settings:
            path = "settings"
        case .downloads:
            path = "downloads"
        case .privacySettings:
            path = "settings/privacy"
        case .aboutApp:
            path = "settings/about"
        case .deepLink(let url):
            return url
        case .share(let shareId):
            path = "share/\\(shareId)"
        }
        
        return URL(string: baseURL + path)
    }
    
    func generateShareURL(for destination: NavigationDestination) -> URL? {
        // Convert internal deep link to universal link
        guard let deepLink = Self.createDeepLink(for: destination) else { return nil }
        
        let universalBase = "https://\\(AppConfiguration.shared.universalLinkDomain)"
        let path = deepLink.path
        
        return URL(string: universalBase + path)
    }
}