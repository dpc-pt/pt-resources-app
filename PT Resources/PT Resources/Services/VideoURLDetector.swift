//
//  VideoURLDetector.swift
//  PT Resources
//
//  Service for detecting, validating, and preprocessing video URLs
//

import Foundation
import AVFoundation

final class VideoURLDetector {
    
    // MARK: - Singleton Instance
    
    static let shared = VideoURLDetector()
    
    // MARK: - Private Properties
    
    private let urlSession: URLSession
    private let cache = NSCache<NSString, NSString>()
    
    // Supported video formats
    private let supportedVideoFormats: Set<String> = [
        "mp4", "mov", "m4v", "avi", "mkv", "webm"
    ]
    
    // Supported streaming protocols
    private let supportedStreamingProtocols: Set<String> = [
        "http", "https", "hls"
    ]
    
    // MARK: - Initialization
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        urlSession = URLSession(configuration: config)
        
        // Configure cache
        cache.countLimit = 100
        cache.totalCostLimit = 1024 * 1024 * 10 // 10MB
    }
    
    // MARK: - Public Methods
    
    /// Detect if a URL is a video URL
    func isValidVideoURL(_ url: URL) -> Bool {
        // Check for direct video file URLs
        if isDirectVideoFileURL(url) {
            return true
        }
        
        // Check for known video platform URLs
        if isKnownVideoPlatformURL(url) {
            return true
        }
        
        // Check for streaming URLs
        if isStreamingURL(url) {
            return true
        }
        
        return false
    }
    
    /// Process and validate a video URL, returning a playable URL
    func processVideoURL(_ url: URL) async throws -> URL {
        PTLogger.general.info("Processing video URL: \(url.absoluteString)")
        
        // Check cache first
        let cacheKey = url.absoluteString as NSString
        if let cachedURLString = cache.object(forKey: cacheKey) as String?,
           let cachedURL = URL(string: cachedURLString) {
            PTLogger.general.debug("Using cached video URL")
            return cachedURL
        }
        
        // Validate URL format
        guard isValidVideoURL(url) else {
            throw VideoError.invalidURL("URL is not a supported video format")
        }
        
        // Process different URL types
        let processedURL: URL
        
        if isVimeoURL(url) {
            processedURL = try await processVimeoURL(url)
        } else if isDirectVideoFileURL(url) {
            processedURL = try await validateDirectVideoURL(url)
        } else if isStreamingURL(url) {
            processedURL = try await validateStreamingURL(url)
        } else {
            // Generic URL validation
            processedURL = try await validateGenericVideoURL(url)
        }
        
        // Cache the result
        cache.setObject(processedURL.absoluteString as NSString, forKey: cacheKey)
        
        PTLogger.general.info("Successfully processed video URL")
        return processedURL
    }
    
    /// Extract video metadata from URL
    func extractVideoMetadata(_ url: URL) async -> VideoURLMetadata? {
        do {
            let processedURL = try await processVideoURL(url)
            
            // For now, return basic metadata without loading complex metadata
            let videoMetadata = VideoURLMetadata(
                url: processedURL,
                title: nil, // Could be enhanced to extract from URL or other sources
                duration: nil, // Could be enhanced to load duration asynchronously
                isLive: false // Could be enhanced to detect live streams
            )
            
            return videoMetadata
        } catch {
            PTLogger.general.error("Failed to extract video metadata: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Private URL Detection Methods
    
    private func isDirectVideoFileURL(_ url: URL) -> Bool {
        let pathExtension = url.pathExtension.lowercased()
        return supportedVideoFormats.contains(pathExtension)
    }
    
    private func isKnownVideoPlatformURL(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        
        return host.contains("vimeo.com") ||
               host.contains("youtube.com") ||
               host.contains("youtu.be") ||
               host.contains("player.vimeo.com")
    }
    
    private func isVimeoURL(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return host.contains("vimeo.com") || host.contains("player.vimeo.com")
    }
    
    private func isStreamingURL(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased() ?? ""
        let pathExtension = url.pathExtension.lowercased()
        
        return supportedStreamingProtocols.contains(scheme) &&
               (pathExtension == "m3u8" || url.absoluteString.contains("playlist.m3u8"))
    }
    
    // MARK: - Private URL Processing Methods
    
    private func processVimeoURL(_ url: URL) async throws -> URL {
        PTLogger.general.debug("Processing Vimeo URL")
        
        // If it's already a player URL, use it directly
        if url.host?.contains("player.vimeo.com") == true {
            return url
        }
        
        // Extract video ID from various Vimeo URL formats
        let videoID = extractVimeoVideoID(from: url)
        
        guard !videoID.isEmpty else {
            throw VideoError.invalidURL("Unable to extract Vimeo video ID")
        }
        
        // For now, return the player URL directly
        // In a production app, you might want to call Vimeo's API to get direct video URLs
        guard let playerURL = URL(string: "https://player.vimeo.com/video/\(videoID)") else {
            throw VideoError.invalidURL("Unable to construct Vimeo player URL")
        }
        
        return playerURL
    }
    
    private func extractVimeoVideoID(from url: URL) -> String {
        let urlString = url.absoluteString
        
        // Handle different Vimeo URL formats
        if let range = urlString.range(of: "vimeo.com/") {
            let afterHost = String(urlString[range.upperBound...])
            let components = afterHost.components(separatedBy: "/")
            if let firstComponent = components.first, 
               firstComponent.allSatisfy({ $0.isNumber }) {
                return firstComponent
            }
        }
        
        // Handle player.vimeo.com URLs
        if let range = urlString.range(of: "player.vimeo.com/video/") {
            let afterPath = String(urlString[range.upperBound...])
            let components = afterPath.components(separatedBy: "?")
            if let videoID = components.first,
               videoID.allSatisfy({ $0.isNumber }) {
                return videoID
            }
        }
        
        return ""
    }
    
    private func validateDirectVideoURL(_ url: URL) async throws -> URL {
        PTLogger.general.debug("Validating direct video URL")
        
        // Create a HEAD request to check if the URL exists and is accessible
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 30.0
        
        do {
            let (_, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw VideoError.networkError("Invalid response from server")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw VideoError.networkError("Video not accessible (HTTP \(httpResponse.statusCode))")
            }
            
            // Check content type
            if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
               !contentType.hasPrefix("video/") {
                PTLogger.general.warning("URL may not be a video file (Content-Type: \(contentType))")
            }
            
            return url
            
        } catch {
            if error is VideoError {
                throw error
            }
            throw VideoError.networkError("Unable to validate video URL: \(error.localizedDescription)")
        }
    }
    
    private func validateStreamingURL(_ url: URL) async throws -> URL {
        PTLogger.general.debug("Validating streaming URL")
        
        // For HLS streams, we can validate the playlist
        if url.pathExtension.lowercased() == "m3u8" || url.absoluteString.contains("playlist.m3u8") {
            return try await validateHLSStream(url)
        }
        
        return url
    }
    
    private func validateHLSStream(_ url: URL) async throws -> URL {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30.0
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw VideoError.networkError("Invalid response from server")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw VideoError.networkError("HLS stream not accessible (HTTP \(httpResponse.statusCode))")
            }
            
            // Basic validation of HLS playlist content
            if let playlistContent = String(data: data, encoding: .utf8) {
                if !playlistContent.contains("#EXTM3U") {
                    throw VideoError.unsupportedFormat("Invalid HLS playlist format")
                }
            }
            
            return url
            
        } catch {
            if error is VideoError {
                throw error
            }
            throw VideoError.networkError("Unable to validate HLS stream: \(error.localizedDescription)")
        }
    }
    
    private func validateGenericVideoURL(_ url: URL) async throws -> URL {
        PTLogger.general.debug("Validating generic video URL")
        
        // For now, return the URL directly without validation
        // This could be enhanced to perform actual validation
        return url
    }
    

}

// MARK: - Supporting Types

struct VideoURLMetadata {
    let url: URL
    let title: String?
    let duration: TimeInterval?
    let isLive: Bool
}

// MARK: - Extensions

private extension String {
    func isNumeric() -> Bool {
        return !isEmpty && allSatisfy { $0.isNumber }
    }
}