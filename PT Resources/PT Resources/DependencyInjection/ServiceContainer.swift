//
//  ServiceContainer.swift
//  PT Resources
//
//  Dependency injection container for managing app services
//

import Foundation
import SwiftUI
import Combine

// MARK: - Service Container Protocol

@MainActor
protocol ServiceContainerProtocol {
    // Configuration
    var configuration: ConfigurationProviding { get }

    // Core Services
    var mediaManager: MediaManagerProtocol { get }
    var errorCoordinator: any ErrorCoordinatorProtocol { get }
    var filteringService: any FilteringServiceProtocol { get }
    var navigationCoordinator: any NavigationCoordinatorProtocol { get }
    var securityService: any SecurityServiceProtocol { get }
    var latestContentService: LatestContentServiceProtocol { get }
    
    // API Services
    var talksAPIService: TalksAPIServiceProtocol { get }
    var conferencesAPIService: any ConferencesAPIServiceProtocol { get }
    var blogAPIService: any BlogAPIServiceProtocol { get }
    var filtersAPIService: any FiltersAPIServiceProtocol { get }
    
    // Data Services
    var downloadService: DownloadService { get }
    var imageCacheService: ImageCacheServiceProtocol { get }
    
    // Persistence
    var persistenceController: PersistenceController { get }
}

// MARK: - Service Container Implementation

@MainActor
final class ServiceContainer: ObservableObject, ServiceContainerProtocol {
    
    // MARK: - Configuration
    
    lazy var configuration: ConfigurationProviding = {
        AppConfiguration.shared
    }()
    
    // MARK: - Core Services
    
    lazy var mediaManager: MediaManagerProtocol = {
        MediaManager()
    }()
    
    lazy var errorCoordinator: any ErrorCoordinatorProtocol = {
        ErrorCoordinator()
    }()
    
    lazy var filteringService: any FilteringServiceProtocol = {
        FilteringService()
    }()
    
    lazy var navigationCoordinator: any NavigationCoordinatorProtocol = {
        NavigationCoordinator()
    }()

    lazy var securityService: any SecurityServiceProtocol = {
        SecurityService()
    }()

    lazy var latestContentService: LatestContentServiceProtocol = {
        LatestContentService()
    }()
    
    // MARK: - API Services
    
    lazy var talksAPIService: TalksAPIServiceProtocol = {
        TalksAPIService()
    }()
    
    lazy var conferencesAPIService: any ConferencesAPIServiceProtocol = {
        ConferencesAPIService()
    }()
    
    lazy var blogAPIService: any BlogAPIServiceProtocol = {
        BlogAPIService()
    }()
    
    lazy var filtersAPIService: any FiltersAPIServiceProtocol = {
        FiltersAPIService()
    }()
    
    // MARK: - Data Services
    
    lazy var downloadService: DownloadService = {
        let service = DownloadService(apiService: talksAPIService, persistenceController: persistenceController)
        
        // Start preloading downloaded talks in background
        Task {
            await service.preloadDownloadedTalks()
        }
        
        return service
    }()
    
    lazy var imageCacheService: ImageCacheServiceProtocol = {
        ImageCacheService.shared
    }()


    // MARK: - Persistence
    
    lazy var persistenceController: PersistenceController = {
        PersistenceController.shared
    }()
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupServiceBindings()
    }
    
    // MARK: - Service Factory Methods
    
    func makeTalksViewModel(initialFilters: TalkSearchFilters? = nil) -> TalksViewModel {
        TalksViewModel(
            apiService: talksAPIService,
            filtersAPIService: filtersAPIService,
            persistenceController: persistenceController,
            initialFilters: initialFilters
        )
    }
    
    func makeConferencesViewModel() -> ConferencesViewModel {
        ConferencesViewModel(apiService: conferencesAPIService)
    }
    
    func makeBlogViewModel() -> BlogViewModel {
        BlogViewModel(apiService: blogAPIService)
    }
    
    func makePlayerService() -> PlayerService {
        PlayerService.shared
    }
    
    // MARK: - Private Methods
    
    private func setupServiceBindings() {
        // Bind error coordinator to other services
        // This allows services to report errors centrally
        bindErrorHandling()
        
        // Setup inter-service communication
        setupServiceCommunication()
    }
    
    private func bindErrorHandling() {
        // In a more complex implementation, you would bind error publishers
        // from various services to the error coordinator
        
        // Example of how services would report errors:
        // someService.errorPublisher
        //     .sink { [weak errorCoordinator] error in
        //         errorCoordinator?.handle(error, category: .someCategory)
        //     }
        //     .store(in: &cancellables)
    }
    
    private func setupServiceCommunication() {
        // Setup communication between services that need to interact
        // For example, download service might need to notify media manager
        // when downloads complete to update artwork cache
        
        // Download completion notifications
        NotificationCenter.default.publisher(for: .downloadCompleted)
            .sink { [weak self] notification in
                // Handle download completion across services
                self?.handleDownloadCompletion(notification)
            }
            .store(in: &cancellables)
    }
    
    private func handleDownloadCompletion(_ notification: Notification) {
        // Coordinate between services when downloads complete
        // For example, update media artwork, clear caches, etc.
        
        if let talkId = notification.object as? String {
            PTLogger.general.info("Download completed for talk: \(talkId)")
            // Could trigger artwork cache update, etc.
        }
    }
}

// MARK: - Environment Integration

@MainActor
struct ServiceContainerKey: EnvironmentKey {
    @MainActor
    static let defaultValue: ServiceContainer = ServiceContainer()
}

extension EnvironmentValues {
    var serviceContainer: ServiceContainer {
        get { self[ServiceContainerKey.self] }
        set { self[ServiceContainerKey.self] = newValue }
    }
}

// MARK: - View Extensions

extension View {
    func withServices(_ container: ServiceContainer) -> some View {
        self
            .environmentObject(container)
            .environmentObject(container.mediaManager as! MediaManager)
            .environmentObject(container.errorCoordinator as! ErrorCoordinator)
            .environmentObject(container.filteringService as! FilteringService)
            .environmentObject(container.navigationCoordinator as! NavigationCoordinator)
            .environmentObject(container.securityService as! SecurityService)
            .environmentObject(container.latestContentService as! LatestContentService)
            .environmentObject(container.downloadService)
            .environment(\.serviceContainer, container)
    }
}

// MARK: - Protocol Extensions for Dependency Injection

// These protocols will be implemented by the actual service classes
// to ensure they can be dependency injected

protocol DownloadServiceProtocol {
    func downloadTalk(_ talk: Talk) async throws
    func isDownloaded(_ talkId: String) async -> Bool
    func deleteTalk(_ talkId: String) async throws
}

protocol ImageCacheServiceProtocol {
    func loadImage(from url: URL) async -> UIImage?
    func cacheImage(_ image: UIImage, for url: URL)
    func clearCache()
    func preloadImages(for urls: [URL]) async
}

// Protocol declarations are in their respective service files

// MARK: - Service Registration

extension ServiceContainer {
    
    /// Register a custom service implementation
    /// This allows for easy testing and service replacement
    func register<T>(_ service: T, for type: T.Type) {
        // In a more sophisticated DI container, you would store this
        // in a registry and return it when requested
        // For now, this is a placeholder for the concept
    }
    
    /// Resolve a service of the given type
    /// This is useful for services that need to look up other services dynamically
    func resolve<T>(_ type: T.Type) -> T? {
        // In a more sophisticated DI container, you would look up
        // the registered service from the registry
        return nil
    }
}

// MARK: - Testing Support

#if DEBUG
extension ServiceContainer {
    
    /// Create a container configured for testing
    static func makeTestContainer() -> ServiceContainer {
        let container = ServiceContainer()
        
        // In a real implementation, you would replace services with mocks
        // container.register(MockTalksAPIService(), for: TalksAPIServiceProtocol.self)
        // container.register(MockDownloadService(), for: DownloadServiceProtocol.self)
        
        return container
    }
}
#endif

// MARK: - Service Lifecycle

extension ServiceContainer {
    
    /// Called when the app is about to terminate
    func cleanup() {
        cancellables.removeAll()
        
        // Cleanup any services that need explicit cleanup
        // For example, stopping background tasks, saving state, etc.
        
        PTLogger.general.info("Service container cleaned up")
    }
    
    /// Called when the app enters background
    func enterBackground() {
        // Notify services that the app is entering background
        // Services can pause operations, save state, etc.
        
        PTLogger.general.info("Service container entering background")
    }
    
    /// Called when the app becomes active
    func becomeActive() {
        // Notify services that the app is becoming active
        // Services can resume operations, refresh data, etc.
        
        PTLogger.general.info("Service container becoming active")
    }
}