//
//  ImageCacheService.swift
//  PT Resources
//
//  Comprehensive image caching and loading service
//

import SwiftUI
import UIKit
import Combine
import CommonCrypto

/// Comprehensive image caching service with memory and disk caching
final class ImageCacheService {
    static let shared = ImageCacheService()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    // Configuration
    private let maxMemoryCost = 50 * 1024 * 1024 // 50MB
    private let maxDiskCacheSize = 100 * 1024 * 1024 // 100MB
    private let imageProcessingQueue = DispatchQueue(label: "com.ptresources.imageProcessing", qos: .userInitiated)
    private let cacheQueue = DispatchQueue(label: "com.ptresources.imageCache", qos: .background)

    private init() {
        // Set up memory cache
        memoryCache.totalCostLimit = maxMemoryCost

        // Set up disk cache directory
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDirectory.appendingPathComponent("ImageCache")

        do {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        } catch {
            PTLogger.general.error("Failed to create image cache directory: \(error)")
        }

        // Set up cache eviction
        setupCacheEviction()
    }

    // MARK: - Public API

    /// Load image from cache or download from URL
    func loadImage(from url: URL, targetSize: CGSize? = nil) async throws -> UIImage {
        let cacheKey = cacheKeyForURL(url)

        // Check memory cache first
        if let cachedImage = memoryCache.object(forKey: cacheKey as NSString) {
            PTLogger.general.info("Image loaded from memory cache: \(url.absoluteString)")
            return processImageForSize(cachedImage, targetSize: targetSize)
        }

        // Check disk cache
        if let diskImage = loadFromDiskCache(cacheKey: cacheKey) {
            PTLogger.general.info("Image loaded from disk cache: \(url.absoluteString)")
            // Store in memory cache for faster future access
            storeInMemoryCache(diskImage, key: cacheKey)
            return processImageForSize(diskImage, targetSize: targetSize)
        }

        // Download from network
        PTLogger.general.info("Downloading image from network: \(url.absoluteString)")
        let image = try await downloadImage(from: url)

        // Process image if needed
        let processedImage = processImageForSize(image, targetSize: targetSize)

        // Cache the original image
        cacheImage(image, for: cacheKey)

        return processedImage
    }

    /// Prefetch images for better performance
    func prefetchImages(urls: [URL]) {
        Task {
            for url in urls {
                do {
                    _ = try await loadImage(from: url)
                } catch {
                    PTLogger.general.error("Failed to prefetch image \(url.absoluteString): \(error.localizedDescription)")
                }
            }
        }
    }

    /// Clear all caches
    func clearCache() async {
        // Clear memory cache
        memoryCache.removeAllObjects()

        // Clear disk cache
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in contents {
                try fileManager.removeItem(at: file)
            }
            PTLogger.general.info("Image cache cleared")
        } catch {
            PTLogger.general.error("Failed to clear disk cache: \(error.localizedDescription)")
        }
    }

    /// Get cache size information
    func getCacheSize() -> (memorySize: Int, diskSize: Int) {
        let memorySize = memoryCache.totalCostLimit

        var diskSize = 0
        if let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for file in contents {
                if let attributes = try? fileManager.attributesOfItem(atPath: file.path),
                   let size = attributes[.size] as? Int {
                    diskSize += size
                }
            }
        }

        return (memorySize, diskSize)
    }

    // MARK: - Private Methods

    private func cacheKeyForURL(_ url: URL) -> String {
        return url.absoluteString.md5()
    }

    private func downloadImage(from url: URL) async throws -> UIImage {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ImageCacheError.invalidResponse
        }

        guard let image = UIImage(data: data) else {
            throw ImageCacheError.invalidImageData
        }

        return image
    }

    private func processImageForSize(_ image: UIImage, targetSize: CGSize?) -> UIImage {
        guard let targetSize = targetSize else { return image }

        let size = image.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let scaleFactor = min(widthRatio, heightRatio)

        let scaledSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)

        return image.resized(to: scaledSize)
    }

    private func cacheImage(_ image: UIImage, for cacheKey: String) {
        // Store in memory cache
        storeInMemoryCache(image, key: cacheKey)

        // Store in disk cache
        storeInDiskCache(image, cacheKey: cacheKey)
    }

    private func storeInMemoryCache(_ image: UIImage, key: String) {
        let cost = Int(image.size.width * image.size.height * 4) // Rough estimate of memory usage
        memoryCache.setObject(image, forKey: key as NSString, cost: cost)
    }

    private func storeInDiskCache(_ image: UIImage, cacheKey: String) {
        cacheQueue.async {
            guard let data = image.jpegData(compressionQuality: 0.8) else { return }
            let fileURL = self.cacheDirectory.appendingPathComponent(cacheKey)

            do {
                try data.write(to: fileURL)
            } catch {
                PTLogger.general.error("Failed to store image in disk cache: \(error.localizedDescription)")
            }
        }
    }

    private func loadFromDiskCache(cacheKey: String) -> UIImage? {
        let fileURL = cacheDirectory.appendingPathComponent(cacheKey)

        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }

        return image
    }

    private func setupCacheEviction() {
        // Evict disk cache when it gets too large
        cacheQueue.async { [weak self] in
            guard let self = self else { return }

            do {
                let contents = try self.fileManager.contentsOfDirectory(at: self.cacheDirectory,
                                                                       includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])

                let (_, diskSize) = self.getCacheSize()

                if diskSize > self.maxDiskCacheSize {
                    // Sort by creation date (oldest first) and remove oldest files
                    let sortedContents = contents.sorted { (url1, url2) -> Bool in
                        let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                        let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                        return date1 < date2
                    }

                    var removedSize = 0
                    for file in sortedContents {
                        if let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                            removedSize += size
                            try? self.fileManager.removeItem(at: file)

                            if diskSize - removedSize < self.maxDiskCacheSize / 2 {
                                break
                            }
                        }
                    }

                    PTLogger.general.info("Evicted \(removedSize) bytes from disk cache")
                }
            } catch {
                PTLogger.general.error("Failed to evict disk cache: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Image Processing Extensions

extension UIImage {
    func resized(to targetSize: CGSize) -> UIImage {
        let size = self.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let scaleFactor = min(widthRatio, heightRatio)

        let scaledSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)

        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        return renderer.image { context in
            draw(in: CGRect(origin: .zero, size: scaledSize))
        }
    }

    func withRoundedCorners(radius: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)

            path.addClip()
            draw(in: rect)
        }
    }
}

// MARK: - String MD5 Extension

extension String {
    func md5() -> String {
        let data = Data(utf8)
        let hash = data.withUnsafeBytes { bytes -> [UInt8] in
            var hash = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            CC_MD5(bytes.baseAddress, CC_LONG(data.count), &hash)
            return hash
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Errors

enum ImageCacheError: LocalizedError {
    case invalidResponse
    case invalidImageData
    case networkError(Error)
    case cacheError

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .invalidImageData:
            return "Invalid image data"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .cacheError:
            return "Cache operation failed"
        }
    }
}

// MARK: - SwiftUI Integration

struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    let targetSize: CGSize?
    let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase = .empty

    init(url: URL?, targetSize: CGSize? = nil, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.targetSize = targetSize
        self.content = content
    }

    var body: some View {
        content(phase)
            .task {
                await loadImage()
            }
    }

    private func loadImage() async {
        guard let url = url else {
            phase = .empty
            return
        }

        do {
            let image = try await ImageCacheService.shared.loadImage(from: url, targetSize: targetSize)
            let swiftUIImage = Image(uiImage: image)
            phase = .success(swiftUIImage)
        } catch {
            phase = .failure(error)
        }
    }
}

// MARK: - Convenience View

struct PTAsyncImage: View {
    let url: URL?
    let targetSize: CGSize?
    let placeholder: AnyView

    init(url: URL?, targetSize: CGSize? = nil, @ViewBuilder placeholder: () -> some View) {
        self.url = url
        self.targetSize = targetSize
        self.placeholder = AnyView(placeholder())
    }

    var body: some View {
        CachedAsyncImage(url: url, targetSize: targetSize) { phase in
            switch phase {
            case .empty:
                placeholder
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                placeholder
            @unknown default:
                placeholder
            }
        }
    }
}

// Import CommonCrypto for MD5 is handled at the top of the file
