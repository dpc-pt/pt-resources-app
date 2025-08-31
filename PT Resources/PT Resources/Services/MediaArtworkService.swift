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
        
        // If no remote image or loading failed, generate custom artwork
        if artwork == nil {
            artwork = await generateCustomArtwork(
                title: talk.title,
                speaker: talk.speaker,
                series: talk.series,
                hasVideo: talk.hasVideo
            )
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
            artwork = await generateCustomArtwork(
                title: resource.title,
                speaker: resource.speaker,
                series: resource.conference,
                hasVideo: resource.videoURL != nil
            )
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
    
    private func generateCustomArtwork(
        title: String,
        speaker: String,
        series: String?,
        hasVideo: Bool
    ) async -> UIImage? {
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let renderer = UIGraphicsImageRenderer(size: self.artworkSize)
                
                let image = renderer.image { context in
                    let rect = CGRect(origin: .zero, size: self.artworkSize)
                    
                    // Create solid background
                    self.drawSolidBackground(in: rect, context: context.cgContext, hasVideo: hasVideo)
                    
                    // Determine if we'll have a PT logo
                    let willHaveLogo = self.brandingService.hasLogo()
                    
                    // Add strategic PT branding pattern based on logo presence
                    self.drawBrandPattern(in: rect, context: context.cgContext, hasLogo: willHaveLogo)
                    
                    // Add content overlay
                    self.drawContentOverlay(
                        in: rect,
                        context: context.cgContext,
                        title: title,
                        speaker: speaker,
                        series: series,
                        hasVideo: hasVideo
                    )
                    
                    // Add PT logo if available
                    self.drawPTLogo(in: rect, context: context.cgContext)
                }
                
                Task { @MainActor in
                    continuation.resume(returning: image)
                }
            }
        }
    }
    
    private func drawSolidBackground(in rect: CGRect, context: CGContext, hasVideo: Bool) {
        // Use solid PT brand colors based on content type
        let backgroundColor: UIColor
        
        if hasVideo {
            // Video content - PT Blue
            backgroundColor = brandingService.ptBlue
        } else {
            // Audio content - PT Orange  
            backgroundColor = brandingService.ptOrange
        }
        
        context.setFillColor(backgroundColor.cgColor)
        context.fill(rect)
        
        // Add subtle texture using PT brand patterns
        drawBrandPattern(in: rect, context: context, hasLogo: false) // No logo in background pattern
    }
    
    private func drawBrandPattern(in rect: CGRect, context: CGContext, hasLogo: Bool) {
        // Strategic pattern usage based on PT branding guidelines:
        // - Use pt-icon-pattern when NO PT logo is present (as primary branding)
        // - Use color-dots when PT logo IS present (as subtle texture)
        
        let patternName = hasLogo ? "color-dots" : "pt-icon-pattern"
        let opacity: CGFloat = hasLogo ? 0.08 : 0.12 // Slightly more prominent when no logo
        
        if let patternImage = brandingService.getStrategicPattern(hasLogo: hasLogo) {
            context.saveGState()
            context.setAlpha(opacity)
            
            // Calculate proper pattern size maintaining SVG aspect ratio
            let patternSize = calculatePatternSize(for: patternImage, in: rect)
            let tilesX = Int(ceil(rect.width / patternSize.width))
            let tilesY = Int(ceil(rect.height / patternSize.height))
            
            // Tile pattern with proper scaling
            for x in 0..<tilesX {
                for y in 0..<tilesY {
                    let patternRect = CGRect(
                        x: CGFloat(x) * patternSize.width,
                        y: CGFloat(y) * patternSize.height,
                        width: patternSize.width,
                        height: patternSize.height
                    )
                    // Use aspect fit to prevent stretching
                    drawImageMaintainingAspectRatio(patternImage, in: patternRect, context: context)
                }
            }
            
            context.restoreGState()
        }
    }
    
    
    private func calculatePatternSize(for image: UIImage, in rect: CGRect) -> CGSize {
        let imageSize = image.size
        let maxPatternSize: CGFloat = 120 // Maximum pattern tile size
        
        // Calculate scale to fit within max size while maintaining aspect ratio
        let scale = min(maxPatternSize / imageSize.width, maxPatternSize / imageSize.height, 1.0)
        
        return CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
    }
    
    private func drawImageMaintainingAspectRatio(_ image: UIImage, in rect: CGRect, context: CGContext) {
        let imageSize = image.size
        let aspectRatio = imageSize.width / imageSize.height
        
        var drawRect: CGRect
        
        if aspectRatio > (rect.width / rect.height) {
            // Image is wider - fit to width
            let height = rect.width / aspectRatio
            drawRect = CGRect(
                x: rect.minX,
                y: rect.minY + (rect.height - height) / 2,
                width: rect.width,
                height: height
            )
        } else {
            // Image is taller - fit to height
            let width = rect.height * aspectRatio
            drawRect = CGRect(
                x: rect.minX + (rect.width - width) / 2,
                y: rect.minY,
                width: width,
                height: rect.height
            )
        }
        
        image.draw(in: drawRect)
    }
    
    private func drawBrandingPattern(in rect: CGRect, context: CGContext) {
        // Add subtle geometric pattern
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.1).cgColor)
        context.setLineWidth(1.0)
        
        let spacing: CGFloat = 40
        
        // Draw diagonal lines
        for i in stride(from: -rect.height, through: rect.width + rect.height, by: spacing) {
            context.move(to: CGPoint(x: i, y: 0))
            context.addLine(to: CGPoint(x: i + rect.height, y: rect.height))
        }
        
        context.strokePath()
        
        // Add circles for decoration
        context.setFillColor(UIColor.white.withAlphaComponent(0.05).cgColor)
        
        let circlePositions = [
            CGPoint(x: rect.width * 0.8, y: rect.height * 0.2),
            CGPoint(x: rect.width * 0.2, y: rect.height * 0.8),
            CGPoint(x: rect.width * 0.9, y: rect.height * 0.7)
        ]
        
        for position in circlePositions {
            let circleRect = CGRect(
                x: position.x - 30,
                y: position.y - 30,
                width: 60,
                height: 60
            )
            context.fillEllipse(in: circleRect)
        }
    }
    
    private func drawContentOverlay(
        in rect: CGRect,
        context: CGContext,
        title: String,
        speaker: String,
        series: String?,
        hasVideo: Bool
    ) {
        // Create semi-transparent overlay for text readability
        let overlayRect = CGRect(
            x: 0,
            y: rect.height * 0.4,
            width: rect.width,
            height: rect.height * 0.6
        )
        
        context.setFillColor(UIColor.black.withAlphaComponent(0.4).cgColor)
        context.fill(overlayRect)
        
        // Draw text content
        let titleFont = UIFont.systemFont(ofSize: 32, weight: .bold)
        let speakerFont = UIFont.systemFont(ofSize: 24, weight: .medium)
        let seriesFont = UIFont.systemFont(ofSize: 18, weight: .regular)
        
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.white,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                style.lineBreakMode = .byTruncatingTail
                return style
            }()
        ]
        
        let speakerAttributes: [NSAttributedString.Key: Any] = [
            .font: speakerFont,
            .foregroundColor: UIColor.white.withAlphaComponent(0.9),
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                return style
            }()
        ]
        
        let seriesAttributes: [NSAttributedString.Key: Any] = [
            .font: seriesFont,
            .foregroundColor: UIColor.white.withAlphaComponent(0.7),
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                return style
            }()
        ]
        
        // Calculate text positions
        let contentArea = CGRect(
            x: 20,
            y: rect.height * 0.45,
            width: rect.width - 40,
            height: rect.height * 0.5
        )
        
        var currentY = contentArea.minY
        
        // Draw series if available
        if let series = series, !series.isEmpty {
            let seriesRect = CGRect(
                x: contentArea.minX,
                y: currentY,
                width: contentArea.width,
                height: 25
            )
            series.draw(in: seriesRect, withAttributes: seriesAttributes)
            currentY += 30
        }
        
        // Draw title (with word wrapping)
        let titleSize = title.boundingRect(
            with: CGSize(width: contentArea.width, height: 100),
            options: [.usesLineFragmentOrigin],
            attributes: titleAttributes,
            context: nil
        ).size
        
        let titleRect = CGRect(
            x: contentArea.minX,
            y: currentY,
            width: contentArea.width,
            height: min(titleSize.height, 80)
        )
        title.draw(in: titleRect, withAttributes: titleAttributes)
        currentY += titleRect.height + 15
        
        // Draw speaker
        let speakerRect = CGRect(
            x: contentArea.minX,
            y: currentY,
            width: contentArea.width,
            height: 30
        )
        speaker.draw(in: speakerRect, withAttributes: speakerAttributes)
        
        // Add media type indicator
        let mediaIcon = hasVideo ? "📹" : "🎧"
        let iconAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24),
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                return style
            }()
        ]
        
        let iconRect = CGRect(
            x: contentArea.maxX - 40,
            y: contentArea.minY + 10,
            width: 30,
            height: 30
        )
        mediaIcon.draw(in: iconRect, withAttributes: iconAttributes)
    }
    
    private func drawPTLogo(in rect: CGRect, context: CGContext) {
        // Draw PT logo in bottom right using actual asset
        let logoSize: CGFloat = 80
        let logoRect = CGRect(
            x: rect.width - logoSize - 20,
            y: rect.height - logoSize - 20,
            width: logoSize,
            height: logoSize
        )
        
        // Try to load the PT logo icon from assets
        if let ptLogo = brandingService.loadPTLogo() {
            // Draw the actual PT logo maintaining aspect ratio
            context.saveGState()
            context.setAlpha(0.9) // Slightly transparent for overlay effect
            drawImageMaintainingAspectRatio(ptLogo, in: logoRect, context: context)
            context.restoreGState()
        } else {
            // Fallback to text-based logo if asset not found
            drawFallbackPTLogo(in: logoRect, context: context)
        }
    }
    
    
    private func drawFallbackPTLogo(in rect: CGRect, context: CGContext) {
        // Fallback PT logo using solid colors
        let circleRect = rect.insetBy(dx: 8, dy: 8)
        
        // Draw solid background circle
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: circleRect)
        
        // Draw PT text in brand color
        let logoFont = UIFont.systemFont(ofSize: 28, weight: .black)
        let logoAttributes: [NSAttributedString.Key: Any] = [
            .font: logoFont,
            .foregroundColor: brandingService.ptBlue,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                return style
            }()
        ]
        
        let textRect = CGRect(
            x: circleRect.minX,
            y: circleRect.minY + (circleRect.height - 32) / 2,
            width: circleRect.width,
            height: 32
        )
        "PT".draw(in: textRect, withAttributes: logoAttributes)
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
        let renderer = UIGraphicsImageRenderer(size: artworkSize)
        
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: artworkSize)
            
            // Use solid PT brand color background
            context.cgContext.setFillColor(brandingService.ptBlue.cgColor)
            context.cgContext.fill(rect)
            
            // Determine if we'll have a PT logo
            let willHaveLogo = brandingService.hasLogo()
            
            // Add strategic brand pattern
            drawBrandPattern(in: rect, context: context.cgContext, hasLogo: willHaveLogo)
            
            // Add PT logo
            drawPTLogo(in: rect, context: context.cgContext)
            
            // Add "PT Resources" text
            let titleFont = UIFont.systemFont(ofSize: 36, weight: .bold)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.white,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .center
                    return style
                }()
            ]
            
            let titleRect = CGRect(
                x: 40,
                y: rect.height/2 - 20,
                width: rect.width - 80,
                height: 40
            )
            "PT Resources".draw(in: titleRect, withAttributes: titleAttributes)
        }
    }
}