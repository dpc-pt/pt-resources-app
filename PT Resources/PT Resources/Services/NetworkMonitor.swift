//
//  NetworkMonitor.swift
//  PT Resources
//
//  Service for monitoring network connectivity and managing offline mode
//

import Foundation
import Network
import Combine

@MainActor
final class NetworkMonitor: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isConnected = true
    @Published var connectionType: ConnectionType = .unknown
    @Published var isOfflineMode = false
    
    // MARK: - Private Properties
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupNetworkMonitoring()
    }
    
    deinit {
        monitor.cancel()
    }
    
    // MARK: - Public Methods
    
    func toggleOfflineMode() {
        isOfflineMode.toggle()
        UserDefaults.standard.set(isOfflineMode, forKey: "offline_mode_enabled")
    }
    
    func enableOfflineMode() {
        isOfflineMode = true
        UserDefaults.standard.set(true, forKey: "offline_mode_enabled")
    }
    
    func disableOfflineMode() {
        isOfflineMode = false
        UserDefaults.standard.set(false, forKey: "offline_mode_enabled")
    }
    
    var shouldShowOfflineContent: Bool {
        return isOfflineMode || !isConnected
    }
    
    var connectionStatusDescription: String {
        if isOfflineMode {
            return "Offline Mode"
        } else if !isConnected {
            return "No Connection"
        } else {
            return connectionType.displayName
        }
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkMonitoring() {
        // Load saved offline mode preference
        isOfflineMode = UserDefaults.standard.bool(forKey: "offline_mode_enabled")
        
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handlePathUpdate(path)
            }
        }
        
        monitor.start(queue: queue)
    }
    
    private func handlePathUpdate(_ path: NWPath) {
        isConnected = path.status == .satisfied
        
        // Determine connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else if path.usesInterfaceType(.loopback) {
            connectionType = .loopback
        } else {
            connectionType = .unknown
        }
        
        // Log connection changes
        PTLogger.general.info("Network status changed: \(self.connectionStatusDescription)")
    }
}

// MARK: - Supporting Types

enum ConnectionType: String, CaseIterable {
    case wifi = "wifi"
    case cellular = "cellular"
    case ethernet = "ethernet"
    case loopback = "loopback"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .wifi: return "Wi-Fi"
        case .cellular: return "Cellular"
        case .ethernet: return "Ethernet"
        case .loopback: return "Local"
        case .unknown: return "Unknown"
        }
    }
    
    var iconName: String {
        switch self {
        case .wifi: return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .ethernet: return "network"
        case .loopback: return "house"
        case .unknown: return "questionmark.circle"
        }
    }
}
