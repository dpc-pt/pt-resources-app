//
//  Config.swift
//  PT Resources
//
//  Configuration and secrets management for PT Resources app
//

import Foundation

/// Configuration management for the PT Resources app.
/// 
/// To set up for production:
/// 1. Create a Secrets.xcconfig file in the project root with your real API keys
/// 2. Add the following keys to Secrets.xcconfig:
///    - PROCLAMATION_API_BASE_URL = your_api_base_url
///    - ESV_API_KEY = your_esv_api_key
///    - TRANSCRIPTION_API_URL = your_transcription_service_url
///    - TRANSCRIPTION_API_KEY = your_transcription_api_key
///    - PODCAST_FEED_URL = your_podcast_rss_url
///    - PUSH_SERVER_ENDPOINT = your_push_notification_server
/// 3. Add Secrets.xcconfig to your .gitignore
/// 4. Configure your Xcode project to use the config file in Build Settings
struct Config {
    
    // MARK: - API Configuration
    
    /// Base URL for the Proclamation Trust API
    static let proclamationAPIBaseURL: String = {
        if let envURL = ProcessInfo.processInfo.environment["PROCLAMATION_API_BASE_URL"] {
            return envURL
        }
        
        if let configValue = getConfigValue("PROCLAMATION_API_BASE_URL") {
            return configValue
        }
        
        return "https://www.proctrust.org.uk/api/resources"
    }()
    
    /// ESV API key for Bible passage lookup
    /// Get your key from https://api.esv.org/
    static let esvAPIKey: String = {
        if let envKey = ProcessInfo.processInfo.environment["ESV_API_KEY"] {
            return envKey
        }
        
        if let configValue = getConfigValue("ESV_API_KEY") {
            return configValue
        }
        
        // Fallback to test key for development only
        #if DEBUG
        return "b9674d6b97fecace2abcef4b26abae9b99bd30fe"
        #else
        return ""
        #endif
    }()
    
    /// Server-side transcription service URL
    static let transcriptionAPIURL: String = {
        if let envURL = ProcessInfo.processInfo.environment["TRANSCRIPTION_API_URL"] {
            return envURL
        }
        
        if let configValue = getConfigValue("TRANSCRIPTION_API_URL") {
            return configValue
        }
        
        return "https://transcription.yourservice.com/v1"
    }()
    
    /// API key for transcription service
    static let transcriptionAPIKey: String = {
        if let envKey = ProcessInfo.processInfo.environment["TRANSCRIPTION_API_KEY"] {
            return envKey
        }
        
        if let configValue = getConfigValue("TRANSCRIPTION_API_KEY") {
            return configValue
        }
        
        return "YOUR_TRANSCRIPTION_API_KEY_HERE"
    }()
    
    /// Podcast RSS feed URL
    static let podcastFeedURL: String = {
        if let configValue = getConfigValue("PODCAST_FEED_URL") {
            return configValue
        }
        return "https://feeds.proctrust.org.uk/podcast.xml"
    }()
    
    /// Blog RSS feed URL
    static let blogFeedURL: String = {
        if let configValue = getConfigValue("BLOG_FEED_URL") {
            return configValue
        }
        return "https://www.proctrust.org.uk/blog/rss.xml"
    }()
    
    /// Push notification server endpoint
    static let pushServerEndpoint: String = {
        if let configValue = getConfigValue("PUSH_SERVER_ENDPOINT") {
            return configValue
        }
        return "https://api.proctrust.org.uk/v1/push"
    }()
    
    // MARK: - App Configuration
    
    /// Maximum number of concurrent downloads
    static let maxConcurrentDownloads = 3
    
    /// Default auto-delete policy for downloaded talks (in days)
    static let defaultAutoDeleteDays = 90
    
    /// Maximum transcription queue size
    static let maxTranscriptionQueueSize = 10
    
    /// Playback speed options
    static let playbackSpeedOptions: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]
    
    /// Skip forward/backward interval in seconds
    static let skipInterval: TimeInterval = 30
    
    /// Sleep timer options (in minutes)
    static let sleepTimerOptions = [5, 10, 15, 30, 45, 60]
    
    // MARK: - Development & Testing
    
    /// Whether to use mock services (for testing and development)
    static var useMockServices: Bool {
        #if DEBUG
        // Use real APIs by default now that we have access to public APIs
        // Only use mock services if explicitly requested for testing
        return ProcessInfo.processInfo.arguments.contains("--use-mock-services")
        #else
        return false
        #endif
    }
    
    /// Whether to use mock ESV service (separate from main API)
    static var useMockESVService: Bool {
        #if DEBUG
        return esvAPIKey == "YOUR_ESV_API_KEY_HERE" || esvAPIKey.isEmpty
        #else
        return false
        #endif
    }
    
    /// Whether to enable debug features
    static var isDebugMode: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - URL Scheme
    
    /// Custom URL scheme for deep linking
    static let urlScheme = "ptresources"
    
    /// Universal link domain
    static let universalLinkDomain: String = {
        if let configValue = getConfigValue("UNIVERSAL_LINK_DOMAIN") {
            return configValue
        }
        return "proctrust.org.uk"
    }()
    
    // MARK: - Cache Configuration
    
    /// Maximum cache size for downloaded audio (in MB)
    static let maxCacheSize = 1000
    
    /// Cache expiration for API responses (in seconds)
    static let apiCacheExpiration: TimeInterval = 300 // 5 minutes
    
    /// ESV passage cache expiration (in seconds)
    static let esvCacheExpiration: TimeInterval = 86400 // 24 hours
    
    // MARK: - Analytics

    /// Analytics service identifier
    static let analyticsServiceID: String = {
        if let configValue = getConfigValue("ANALYTICS_SERVICE_ID") {
            return configValue
        }
        return "pt-resources-analytics"
    }()

    /// Whether analytics is enabled (opt-in by default)
    static var analyticsEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: "analytics_enabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "analytics_enabled")
            PTLogger.general.info("Analytics \(newValue ? "enabled" : "disabled")")
        }
    }

    // MARK: - Security

    /// Minimum iOS version supported
    static let minimumOSVersion = "17.0"

    /// Whether to enable network debugging in debug builds
    static var networkDebuggingEnabled: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--enable-network-debug")
        #else
        return false
        #endif
    }

    /// Whether to use certificate pinning for API requests
    static let certificatePinningEnabled = true

    /// Timeout for API requests (in seconds)
    static let apiTimeout: TimeInterval = 30.0

    /// Maximum number of retries for failed requests
    static let maxRetryAttempts = 3
    
    // MARK: - Helper Functions
    
    /// Helper function to read values from Secrets.xcconfig
    private static func getConfigValue(_ key: String) -> String? {
        guard let configPath = Bundle.main.path(forResource: "Secrets", ofType: "xcconfig"),
              let configContent = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return nil
        }
        
        let lines = configContent.components(separatedBy: .newlines)
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip comments and empty lines
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("//") {
                continue
            }
            
            if trimmedLine.hasPrefix("\(key) = ") {
                let value = trimmedLine.replacingOccurrences(of: "\(key) = ", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Don't return placeholder values
                if !value.isEmpty && !value.hasPrefix("YOUR_") && value != "your_\(key.lowercased())_here" {
                    return value
                }
            }
        }
        
        return nil
    }

    // MARK: - Privacy

    /// Privacy policy URL
    static let privacyPolicyURL: String = {
        if let configValue = getConfigValue("PRIVACY_POLICY_URL") {
            return configValue
        }
        return "https://proctrust.org.uk/privacy"
    }()

    /// Terms of service URL
    static let termsOfServiceURL: String = {
        if let configValue = getConfigValue("TERMS_OF_SERVICE_URL") {
            return configValue
        }
        return "https://proctrust.org.uk/terms"
    }()
}

// MARK: - Environment Detection

extension Config {
    
    /// Detect if running in CI environment
    static var isRunningInCI: Bool {
        return ProcessInfo.processInfo.environment["CI"] != nil ||
               ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil
    }
    
    /// Detect if running in Xcode previews
    static var isRunningInPreview: Bool {
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

// MARK: - API Endpoints

extension Config {
    
    enum APIEndpoint {
        case resources(filters: TalkSearchFilters = TalkSearchFilters(), page: Int = 1, limit: Int = 12, sortOption: TalkSortOption = .dateNewest)
        case resourceDetail(id: String)
        case resourceDownload(id: String)
        case blogPosts(limit: Int = 100, offset: Int = 0)
        case blogPostDetail(id: String)
        case filters
        case latest
        case stats
        case esvPassage(reference: String)
        case createTranscription(audioURL: String, talkID: String)
        case transcriptionStatus(jobID: String)
        
        var url: String {
            switch self {
            case .resources(let filters, let page, let limit, let sortOption):
                var components = URLComponents(string: proclamationAPIBaseURL)!
                var queryItems: [URLQueryItem] = [
                    URLQueryItem(name: "page", value: "\(page)"),
                    URLQueryItem(name: "limit", value: "\(limit)"),
                    URLQueryItem(name: "sort", value: sortOption.rawValue)
                ]
                
                // Basic search query
                if !filters.query.isEmpty {
                    queryItems.append(URLQueryItem(name: "search", value: filters.query))
                }
                
                // Legacy speaker support
                if let speaker = filters.speaker, !speaker.isEmpty {
                    queryItems.append(URLQueryItem(name: "speaker", value: speaker))
                }
                
                // Note: API doesn't support series filtering directly
                // if let series = filters.series, !series.isEmpty {
                //     queryItems.append(URLQueryItem(name: "series", value: series))
                // }
                
                // Speaker ID filter (API supports single speaker_id only)
                if let speakerId = filters.speakerIds.first {
                    queryItems.append(URLQueryItem(name: "speaker_id", value: speakerId))
                }
                
                // Conference ID filter (API supports single conference_id only)
                if let conferenceId = filters.conferenceIds.first {
                    queryItems.append(URLQueryItem(name: "conference_id", value: conferenceId))
                }
                
                // Conference Type filter (API supports single conference_type only)
                if let conferenceType = filters.conferenceTypes.first {
                    queryItems.append(URLQueryItem(name: "conference_type", value: conferenceType))
                }
                
                // Bible Book filter (API supports single book_id only)
                if let bookId = filters.bibleBookIds.first {
                    queryItems.append(URLQueryItem(name: "book_id", value: bookId))
                }
                
                // Year filter (API supports single year_id only)
                if let year = filters.years.first {
                    queryItems.append(URLQueryItem(name: "year_id", value: year))
                }
                
                // Collection filter (API supports single collection_id only)
                if let collection = filters.collections.first {
                    queryItems.append(URLQueryItem(name: "collection_id", value: collection))
                }
                
                // Note: API doesn't support date range filters - these will be handled client-side
                // if let dateFrom = filters.dateFrom { ... }
                // if let dateTo = filters.dateTo { ... }
                
                components.queryItems = queryItems.isEmpty ? nil : queryItems
                return components.url?.absoluteString ?? proclamationAPIBaseURL
                
            case .resourceDetail(let id):
                return "\(proclamationAPIBaseURL)/\(id)"
                
            case .resourceDownload(let id):
                // Assuming download URL is available in the resource detail
                return "\(proclamationAPIBaseURL)/\(id)/download"
                
            case .blogPosts(let limit, let offset):
                var components = URLComponents(string: "https://www.proctrust.org.uk/api/blog")!
                var queryItems: [URLQueryItem] = [
                    URLQueryItem(name: "limit", value: "\(limit)"),
                    URLQueryItem(name: "offset", value: "\(offset)")
                ]
                components.queryItems = queryItems
                return components.url?.absoluteString ?? "https://www.proctrust.org.uk/api/blog"

            case .blogPostDetail(let id):
                return "https://www.proctrust.org.uk/api/blog/\(id)"
                
            case .filters:
                return "\(proclamationAPIBaseURL)/filters"
                
            case .latest:
                return "\(proclamationAPIBaseURL)/latest"
                
            case .stats:
                return "\(proclamationAPIBaseURL)/stats"
                
            case .esvPassage(let reference):
                let encodedRef = reference.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? reference
                return "https://api.esv.org/v3/passage/html/?q=\(encodedRef)&include-headings=false&include-footnotes=false&include-verse-numbers=true&include-short-copyright=true&include-copyright=false"
                
            case .createTranscription(let audioURL, let talkID):
                return "\(transcriptionAPIURL)/transcriptions"
                
            case .transcriptionStatus(let jobID):
                return "\(transcriptionAPIURL)/transcriptions/\(jobID)"
            }
        }
    }
}
