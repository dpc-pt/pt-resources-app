//
//  NowPlayingService.swift
//  PT Resources
//
//  Service for managing iOS Now Playing Info Center integration
//  Provides artwork and metadata to lock screen, control center, and CarPlay
//

import Foundation
import MediaPlayer
import UIKit
import SwiftUI

/// Service responsible for updating iOS Now Playing Info Center
/// This ensures consistent metadata and artwork across lock screen, control center, and CarPlay
@MainActor
final class NowPlayingService: ObservableObject {
    static let shared = NowPlayingService()
    
    private init() {
        setupRemoteCommandCenter()
    }
    
    // MARK: - Public API
    
    /// Updates Now Playing Info with resource details and artwork
    func updateNowPlayingInfo(
        for resource: ResourceDetail,
        artwork: UIImage? = nil,
        currentTime: TimeInterval = 0,
        duration: TimeInterval = 0,
        isPlaying: Bool = false,
        playbackRate: Float = 1.0
    ) {
        Task {
            await setNowPlayingInfo(
                title: resource.title,
                artist: resource.speaker,
                album: resource.conference,
                artwork: artwork,
                currentTime: currentTime,
                duration: duration,
                isPlaying: isPlaying,
                playbackRate: playbackRate,
                mediaType: resource.videoURL != nil ? .video : .audio,
                artworkURL: resource.resourceImageURL
            )
        }
    }
    
    /// Updates Now Playing Info with Talk details and artwork
    func updateNowPlayingInfo(
        for talk: Talk,
        artwork: UIImage? = nil,
        currentTime: TimeInterval = 0,
        duration: TimeInterval = 0,
        isPlaying: Bool = false,
        playbackRate: Float = 1.0
    ) {
        Task {
            await setNowPlayingInfo(
                title: talk.title,
                artist: talk.speaker,
                album: talk.series ?? "",
                artwork: artwork,
                currentTime: currentTime,
                duration: duration,
                isPlaying: isPlaying,
                playbackRate: playbackRate,
                mediaType: talk.videoURL != nil ? .video : .audio,
                artworkURL: (talk.imageURL != nil) ? URL(string: talk.imageURL!) : nil
            )
        }
    }
    
    /// Updates only playback state (more efficient for frequent updates)
    func updatePlaybackState(currentTime: TimeInterval, isPlaying: Bool, playbackRate: Float = 1.0) {
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackRate : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    /// Updates only artwork when it becomes available
    func updateArtwork(_ artwork: UIImage) {
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        let mediaArtwork = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
        nowPlayingInfo[MPMediaItemPropertyArtwork] = mediaArtwork
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    /// Clears Now Playing Info
    func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    // MARK: - Private Implementation
    
    private func setNowPlayingInfo(
        title: String,
        artist: String,
        album: String,
        artwork: UIImage?,
        currentTime: TimeInterval,
        duration: TimeInterval,
        isPlaying: Bool,
        playbackRate: Float,
        mediaType: MPNowPlayingInfoMediaType,
        artworkURL: URL?
    ) async {
        var nowPlayingInfo = [String: Any]()
        
        // Basic metadata
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = album
        
        // Playback information
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackRate : 0.0
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = mediaType.rawValue
        
        // Handle artwork with priority: provided artwork > download from URL > branded fallback
        if let providedArtwork = artwork {
            let mediaArtwork = MPMediaItemArtwork(boundsSize: providedArtwork.size) { _ in
                return providedArtwork
            }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = mediaArtwork
        } else if let artworkURL = artworkURL {
            do {
                let downloadedArtwork = try await loadArtworkForNowPlaying(from: artworkURL)
                let mediaArtwork = MPMediaItemArtwork(boundsSize: downloadedArtwork.size) { _ in
                    return downloadedArtwork
                }
                nowPlayingInfo[MPMediaItemPropertyArtwork] = mediaArtwork
            } catch {
                // Use branded fallback if download fails
                let brandedArtwork = await MainActor.run { createBrandedArtwork(title: title, album: album) }
                let mediaArtwork = MPMediaItemArtwork(boundsSize: brandedArtwork.size) { _ in
                    return brandedArtwork
                }
                nowPlayingInfo[MPMediaItemPropertyArtwork] = mediaArtwork
            }
        } else {
            // No artwork URL, use branded fallback
            let brandedArtwork = await MainActor.run { createBrandedArtwork(title: title, album: album) }
            let mediaArtwork = MPMediaItemArtwork(boundsSize: brandedArtwork.size) { _ in
                return brandedArtwork
            }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = mediaArtwork
        }
        
        // Update on main thread
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Enable play/pause commands
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        
        // Enable skip commands
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [30] // 30 seconds
        commandCenter.skipBackwardCommand.preferredIntervals = [15] // 15 seconds
        
        // Enable seek commands
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        
        // Add command handlers (these should be handled by PlayerService)
        commandCenter.playCommand.addTarget { _ in
            PlayerService.shared.play()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { _ in
            PlayerService.shared.pause()
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.addTarget { _ in
            if PlayerService.shared.isPlaying {
                PlayerService.shared.pause()
            } else {
                PlayerService.shared.play()
            }
            return .success
        }
        
        commandCenter.skipForwardCommand.addTarget { _ in
            PlayerService.shared.skipForward()
            return .success
        }
        
        commandCenter.skipBackwardCommand.addTarget { _ in
            PlayerService.shared.skipBackward()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                PlayerService.shared.seek(to: event.positionTime)
                return .success
            }
            return .commandFailed
        }
    }
    
    private func loadArtworkForNowPlaying(from url: URL) async throws -> UIImage {
        // Use cached version if available
        if let cachedImage = await ImageCacheService.shared.loadImage(from: url) {
            return cachedImage.resized(to: CGSize(width: 512, height: 512))
        }
        
        // Load from network
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: data) else {
            throw NowPlayingError.invalidImageData
        }
        
        return image.resized(to: CGSize(width: 512, height: 512))
    }
    
    private func createBrandedArtwork(title: String, album: String) -> UIImage {
        if !Thread.isMainThread {
            return DispatchQueue.main.sync {
                createBrandedArtwork(title: title, album: album)
            }
        }
        
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image: UIImage
        do {
            image = try renderer.image { context in
                let rect = CGRect(origin: .zero, size: size)
                
                // PT brand gradient background
                let colors = [
                    UIColor(PTDesignTokens.Colors.kleinBlue).cgColor,
                    UIColor(PTDesignTokens.Colors.tang).cgColor,
                    UIColor(PTDesignTokens.Colors.ink).cgColor
                ]
                
                if let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: colors as CFArray,
                    locations: [0.0, 0.5, 1.0]
                ) {
                    context.cgContext.drawLinearGradient(
                        gradient,
                        start: CGPoint(x: 0, y: 0),
                        end: CGPoint(x: size.width, y: size.height),
                        options: []
                    )
                }
                
                // Add PT logo
                let logoAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 72, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
                
                let logoText = "PT"
                let logoSize = logoText.size(withAttributes: logoAttributes)
                let logoRect = CGRect(
                    x: (size.width - logoSize.width) / 2,
                    y: (size.height - logoSize.height) / 2 - 30,
                    width: logoSize.width,
                    height: logoSize.height
                )
                
                logoText.draw(in: logoRect, withAttributes: logoAttributes)
                
                // Add album/series info if available
                if !album.isEmpty {
                    let albumAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                        .foregroundColor: UIColor.white.withAlphaComponent(0.8)
                    ]
                    
                    let albumSize = album.size(withAttributes: albumAttributes)
                    let albumRect = CGRect(
                        x: (size.width - albumSize.width) / 2,
                        y: logoRect.maxY + 15,
                        width: albumSize.width,
                        height: albumSize.height
                    )
                    
                    album.draw(in: albumRect, withAttributes: albumAttributes)
                }
            }
        } catch {
            print("Failed to draw branded artwork: \(error)")
            // Fallback to solid color image
            let fallbackRenderer = UIGraphicsImageRenderer(size: size)
            image = fallbackRenderer.image { ctx in
                UIColor.gray.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
            }
        }
        return image
    }
}

// MARK: - Supporting Types

enum NowPlayingError: Error {
    case invalidImageData
    case networkError
    case artworkGenerationFailed
}

