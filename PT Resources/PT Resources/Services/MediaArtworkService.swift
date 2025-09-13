//
//  MediaArtworkService.swift
//  PT Resources
//
//  Service for generating and managing media artwork for Now Playing, lock screen, and Control Center
//

import Foundation
import UIKit
import MediaPlayer
import SwiftUI
import Combine

@MainActor
final class MediaArtworkService: ObservableObject {
    
    // MARK: - Singleton Instance
    
    static let shared = MediaArtworkService()
    
    // MARK: - Published Properties
    
    @Published var currentArtwork: UIImage?
    @Published var isGeneratingArtwork = false
    
    // MARK: - Private Properties
    
    private let artworkCache = NSCache<NSString, UIImage>()
    private let artworkSize = CGSize(width: 512, height: 512) // High-res for all iOS displays
    private var cancellables = Set<AnyCancellable>()
    
    // PT Branding Service
    private let brandingService = PTBrandingService.shared
    
    // MARK: - Initialization
    
    private init() {
        setupCache()
    }
    
    // MARK: - Public Methods
    
    /// Generate artwork for a talk/resource with speaker, title, and PT branding
    func generateArtwork(for talk: Talk) async -> UIImage? {
        let cacheKey = "talk_\(talk.id)" as NSString
        
        // Check cache first
        if let cachedImage = artworkCache.object(forKey: cacheKey) {
            await MainActor.run {
                currentArtwork = cachedImage
            }
            return cachedImage
        }
        
        await MainActor.run {
            isGeneratingArtwork = true
        }
        
        // Try to load image from URL using priority order
        var artwork: UIImage?
        
        if let artworkURL = talk.artworkURL, let url = URL(string: artworkURL) {
            artwork = await loadRemoteImage(from: url)
        }
        
        // If no remote image or loading failed, use simple PT Resources logo
        if artwork == nil {
            artwork = generateSimplePTArtwork()
        }
        
        // Cache the result
        if let finalArtwork = artwork {
            artworkCache.setObject(finalArtwork, forKey: cacheKey)
        }
        
        await MainActor.run {
            currentArtwork = artwork
            isGeneratingArtwork = false
        }
        
        return artwork
    }
    
    /// Generate artwork for a resource detail
    func generateArtwork(for resource: ResourceDetail) async -> UIImage? {
        let cacheKey = "resource_\(resource.id)" as NSString
        
        if let cachedImage = artworkCache.object(forKey: cacheKey) {
            await MainActor.run {
                currentArtwork = cachedImage
            }
            return cachedImage
        }
        
        await MainActor.run {
            isGeneratingArtwork = true
        }
        
        var artwork: UIImage?
        
        if let imageURL = resource.resourceImageURL {
            artwork = await loadRemoteImage(from: imageURL)
        }
        
        if artwork == nil {
            artwork = generateSimplePTArtwork()
        }
        
        if let finalArtwork = artwork {
            artworkCache.setObject(finalArtwork, forKey: cacheKey)
        }
        
        await MainActor.run {
            currentArtwork = artwork
            isGeneratingArtwork = false
        }
        
        return artwork
    }
    
    /// Create MPMediaItemArtwork for Now Playing integration
    func createMPMediaItemArtwork(from image: UIImage) -> MPMediaItemArtwork {
        return MPMediaItemArtwork(boundsSize: artworkSize) { _ in
            return image
        }
    }
    
    // MARK: - Private Methods
    
    private func setupCache() {
        artworkCache.countLimit = 100
        artworkCache.totalCostLimit = 1024 * 1024 * 50 // 50MB
    }
    
    private func loadRemoteImage(from url: URL) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // Check if this is an SVG file by looking at the URL or content
            let isSVG = url.pathExtension.lowercased() == "svg" || 
                       String(data: data.prefix(100), encoding: .utf8)?.contains("<svg") == true
            
            if isSVG {
                PTLogger.general.info("Detected SVG file, falling back to local PT Resources logo: \(url)")
                // For SVG files, fall back to the local PT Resources logo
                return generateSimplePTArtwork()
            }
            
            guard let image = UIImage(data: data) else {
                PTLogger.general.warning("Failed to create image from remote data: \(url)")
                return nil
            }
            
            // Resize to standard artwork size
            let resizedImage = await resizeImage(image, to: artworkSize)
            PTLogger.general.info("Successfully loaded and resized remote artwork")
            return resizedImage
            
        } catch {
            PTLogger.general.error("Failed to load remote artwork: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Generate simple artwork with just PT Resources logo
    private func generateSimplePTArtwork() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: artworkSize)
        
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: artworkSize)
            
            // Solid background using PT Klein Blue
            context.cgContext.setFillColor(PTDesignTokens.Colors.kleinBlue.cgColor!)
            context.cgContext.fill(rect)
            
            // Add PT Resources logo in the center
            if let ptLogo = UIImage(named: "pt-resources") {
                let logoSize: CGFloat = min(rect.width, rect.height) * 0.6
                let logoRect = CGRect(
                    x: (rect.width - logoSize) / 2,
                    y: (rect.height - logoSize) / 2,
                    width: logoSize,
                    height: logoSize
                )
                ptLogo.draw(in: logoRect)
            }
        }
    }
    
    
    private func resizeImage(_ image: UIImage, to size: CGSize) async -> UIImage {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let renderer = UIGraphicsImageRenderer(size: size)
                let resizedImage = renderer.image { _ in
                    image.draw(in: CGRect(origin: .zero, size: size))
                }
                continuation.resume(returning: resizedImage)
            }
        }
    }
}

// MARK: - Now Playing Integration

extension MediaArtworkService {
    
    /// Update Now Playing info with rich metadata and artwork
    func updateNowPlayingInfo(
        title: String,
        artist: String,
        album: String?,
        artwork: UIImage?,
        duration: TimeInterval,
        currentTime: TimeInterval,
        playbackRate: Float
    ) {
        
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: playbackRate,
            MPMediaItemPropertyMediaType: MPMediaType.podcast.rawValue
        ]
        
        // Add album/series info if available
        if let album = album {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = album
        }
        
        // Add high-quality artwork
        if let artwork = artwork {
            let mpArtwork = createMPMediaItemArtwork(from: artwork)
            nowPlayingInfo[MPMediaItemPropertyArtwork] = mpArtwork
        }
        
        // Add additional metadata for rich experience
        nowPlayingInfo[MPMediaItemPropertyGenre] = "Sermon"
        nowPlayingInfo[MPMediaItemPropertyComments] = "Proclamation Trust Resources"
        
        // Set the Now Playing info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
        PTLogger.general.info("Updated Now Playing info with rich metadata and artwork")
    }
}

// MARK: - Artwork Templates

extension MediaArtworkService {
    
    /// Generate a placeholder artwork when no specific content is available
    func generatePlaceholderArtwork() -> UIImage {
        return generateSimplePTArtwork() ?? UIImage()
    }
}
