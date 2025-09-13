//
//  AppConfiguration.swift
//  PT Resources
//
//  Simplified and secure app configuration management
//

import Foundation

// MARK: - Configuration Protocol

protocol ConfigurationProviding {
    var proclamationAPIBaseURL: String { get }
    var esvAPIKey: String { get }
    var transcriptionAPIURL: String { get }
    var transcriptionAPIKey: String { get }
    var podcastFeedURL: String { get }
    var blogFeedURL: String { get }
    var pushServerEndpoint: String { get }
    var privacyPolicyURL: String { get }
    var termsOfServiceURL: String { get }
    var universalLinkDomain: String { get }
    var analyticsServiceID: String { get }
    
    var useMockServices: Bool { get }
    var useMockESVService: Bool { get }
    var isDebugMode: Bool { get }
    var networkDebuggingEnabled: Bool { get }
    
    var maxConcurrentDownloads: Int { get }
    var defaultAutoDeleteDays: Int { get }
    var maxCacheSize: Int { get }
    var apiCacheExpiration: TimeInterval { get }
    var apiTimeout: TimeInterval { get }
    var maxRetryAttempts: Int { get }
}

// MARK: - App Configuration

struct AppConfiguration: ConfigurationProviding {
    
    // MARK: - API Configuration
    
    let proclamationAPIBaseURL: String
    let esvAPIKey: String
    let transcriptionAPIURL: String
    let transcriptionAPIKey: String
    let podcastFeedURL: String
    let blogFeedURL: String
    let pushServerEndpoint: String
    let privacyPolicyURL: String
    let termsOfServiceURL: String
    let universalLinkDomain: String
    let analyticsServiceID: String
    
    // MARK: - Development Configuration
    
    let useMockServices: Bool
    let useMockESVService: Bool
    let isDebugMode: Bool
    let networkDebuggingEnabled: Bool
    
    // MARK: - App Configuration
    
    let maxConcurrentDownloads: Int
    let defaultAutoDeleteDays: Int
    let maxCacheSize: Int
    let apiCacheExpiration: TimeInterval
    let apiTimeout: TimeInterval
    let maxRetryAttempts: Int
    
    // MARK: - Initialization
    
    init(environment: ConfigurationEnvironment = .production) {
        // Load configuration based on environment
        let loader = ConfigurationLoader()
        
        // API URLs
        self.proclamationAPIBaseURL = loader.getValue(
            key: "PROCLAMATION_API_BASE_URL",
            fallback: "https://www.proctrust.org.uk/api/resources"
        )
        
        self.esvAPIKey = loader.getValue(
            key: "ESV_API_KEY",
            fallback: environment == .development ? "b9674d6b97fecace2abcef4b26abae9b99bd30fe" : ""
        )
        
        self.transcriptionAPIURL = loader.getValue(
            key: "TRANSCRIPTION_API_URL",
            fallback: "https://transcription.yourservice.com/v1"
        )
        
        self.transcriptionAPIKey = loader.getValue(
            key: "TRANSCRIPTION_API_KEY",
            fallback: ""
        )
        
        self.podcastFeedURL = loader.getValue(
            key: "PODCAST_FEED_URL",
            fallback: "https://feeds.proctrust.org.uk/podcast.xml"
        )
        
        self.blogFeedURL = loader.getValue(
            key: "BLOG_FEED_URL",
            fallback: "https://www.proctrust.org.uk/blog/rss.xml"
        )
        
        self.pushServerEndpoint = loader.getValue(
            key: "PUSH_SERVER_ENDPOINT",
            fallback: "https://api.proctrust.org.uk/v1/push"
        )
        
        self.privacyPolicyURL = loader.getValue(
            key: "PRIVACY_POLICY_URL",
            fallback: "https://proctrust.org.uk/privacy"
        )
        
        self.termsOfServiceURL = loader.getValue(
            key: "TERMS_OF_SERVICE_URL",
            fallback: "https://proctrust.org.uk/terms"
        )
        
        self.universalLinkDomain = loader.getValue(
            key: "UNIVERSAL_LINK_DOMAIN",
            fallback: "proctrust.org.uk"
        )
        
        self.analyticsServiceID = loader.getValue(
            key: "ANALYTICS_SERVICE_ID",
            fallback: "pt-resources-analytics"
        )
        
        // Development settings
        self.useMockServices = environment == .development && 
                               ProcessInfo.processInfo.arguments.contains("--use-mock-services")
        
        self.useMockESVService = environment == .development && 
                                 (esvAPIKey.isEmpty || esvAPIKey.hasPrefix("YOUR_"))
        
        self.isDebugMode = environment == .development
        
        self.networkDebuggingEnabled = environment == .development && 
                                       ProcessInfo.processInfo.arguments.contains("--enable-network-debug")
        
        // App configuration
        self.maxConcurrentDownloads = loader.getIntValue(key: "MAX_CONCURRENT_DOWNLOADS", fallback: 3)
        self.defaultAutoDeleteDays = loader.getIntValue(key: "DEFAULT_AUTO_DELETE_DAYS", fallback: 90)
        self.maxCacheSize = loader.getIntValue(key: "MAX_CACHE_SIZE", fallback: 1000)
        self.apiCacheExpiration = loader.getDoubleValue(key: "API_CACHE_EXPIRATION", fallback: 300)
        self.apiTimeout = loader.getDoubleValue(key: "API_TIMEOUT", fallback: 30.0)
        self.maxRetryAttempts = loader.getIntValue(key: "MAX_RETRY_ATTEMPTS", fallback: 3)
    }
}

// MARK: - Configuration Environment

enum ConfigurationEnvironment {
    case development
    case staging
    case production
    
    static var current: ConfigurationEnvironment {
        #if DEBUG
        if ProcessInfo.processInfo.environment["STAGING"] == "1" {
            return .staging
        }
        return .development
        #else
        return .production
        #endif
    }
}

// MARK: - Configuration Loader

private struct ConfigurationLoader {
    
    func getValue(key: String, fallback: String) -> String {
        // Priority: Environment Variables > Config File > Fallback
        if let envValue = ProcessInfo.processInfo.environment[key], !envValue.isEmpty {
            return envValue
        }
        
        if let configValue = getConfigValue(key), !configValue.isEmpty, !isPlaceholderValue(configValue) {
            return configValue
        }
        
        return fallback
    }
    
    func getIntValue(key: String, fallback: Int) -> Int {
        let stringValue = getValue(key: key, fallback: String(fallback))
        return Int(stringValue) ?? fallback
    }
    
    func getDoubleValue(key: String, fallback: Double) -> Double {
        let stringValue = getValue(key: key, fallback: String(fallback))
        return Double(stringValue) ?? fallback
    }
    
    func getBoolValue(key: String, fallback: Bool) -> Bool {
        let stringValue = getValue(key: key, fallback: String(fallback))
        return Bool(stringValue) ?? fallback
    }
    
    private func getConfigValue(_ key: String) -> String? {
        guard let configPath = Bundle.main.path(forResource: "Secrets", ofType: "xcconfig"),
              let configContent = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return nil
        }
        
        let lines = configContent.components(separatedBy: .newlines)
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("//") {
                continue
            }
            
            if trimmedLine.hasPrefix("\\(key) = ") {
                let value = trimmedLine.replacingOccurrences(of: "\\(key) = ", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : value
            }
        }
        
        return nil
    }
    
    private func isPlaceholderValue(_ value: String) -> Bool {
        return value.hasPrefix("YOUR_") || 
               value.hasSuffix("_HERE") || 
               value.contains("your_") ||
               value == "changeme" ||
               value == "placeholder"
    }
}

// MARK: - Singleton Access

extension AppConfiguration {
    static let shared: ConfigurationProviding = AppConfiguration(environment: .current)
}

// MARK: - Constants

extension AppConfiguration {
    
    struct MediaConstants {
        static let playbackSpeedOptions: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]
        static let skipInterval: TimeInterval = 30
        static let sleepTimerOptions = [5, 10, 15, 30, 45, 60]
    }
    
    struct SecurityConstants {
        static let minimumOSVersion = "17.0"
        static let certificatePinningEnabled = true
        static let urlScheme = "ptresources"
    }
}