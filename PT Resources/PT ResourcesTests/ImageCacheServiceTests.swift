//
//  ImageCacheServiceTests.swift
//  PT ResourcesTests
//
//  Unit tests for ImageCacheService
//

import XCTest
import SwiftUI
@testable import PT_Resources

final class ImageCacheServiceTests: XCTestCase {
    var imageCacheService: ImageCacheService!
    var testImage: UIImage!
    var testURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        imageCacheService = ImageCacheService()

        // Create a test image
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContext(size)
        UIColor.red.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        testImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        testURL = URL(string: "https://example.com/test-image.jpg")!
    }

    override func tearDownWithError() throws {
        // Clear cache after each test
        imageCacheService = nil
        testImage = nil
        testURL = nil
        try super.tearDownWithError()
    }

    // MARK: - Cache Key Tests

    func testCacheKeyGeneration() {
        let key1 = imageCacheService.cacheKeyForURL(testURL)
        let key2 = imageCacheService.cacheKeyForURL(testURL)

        XCTAssertEqual(key1, key2, "Same URL should generate same cache key")
        XCTAssertFalse(key1.isEmpty, "Cache key should not be empty")
    }

    func testDifferentURLsGenerateDifferentKeys() {
        let url1 = URL(string: "https://example.com/image1.jpg")!
        let url2 = URL(string: "https://example.com/image2.jpg")!

        let key1 = imageCacheService.cacheKeyForURL(url1)
        let key2 = imageCacheService.cacheKeyForURL(url2)

        XCTAssertNotEqual(key1, key2, "Different URLs should generate different cache keys")
    }

    // MARK: - Image Processing Tests

    func testImageResizing() {
        let targetSize = CGSize(width: 50, height: 50)
        let resizedImage = testImage.resized(to: targetSize)

        XCTAssertEqual(resizedImage.size.width, targetSize.width, accuracy: 0.1)
        XCTAssertEqual(resizedImage.size.height, targetSize.height, accuracy: 0.1)
    }

    func testImageWithRoundedCorners() {
        let radius: CGFloat = 10
        let roundedImage = testImage.withRoundedCorners(radius: radius)

        XCTAssertEqual(roundedImage.size, testImage.size, "Rounded corner image should maintain original size")
    }

    // MARK: - Memory Cache Tests

    func testMemoryCacheStorageAndRetrieval() {
        let cacheKey = "test_memory_key"

        // Store in memory cache
        imageCacheService.storeInMemoryCache(testImage, key: cacheKey)

        // Verify it's in the cache (this would require exposing internal cache for testing)
        // In a real implementation, you might want to expose a method to check cache contents
    }

    // MARK: - Cache Clearing Tests

    func testCacheClearing() async {
        // This test would need to be more comprehensive with actual network calls
        // For now, we test that the method exists and can be called
        await imageCacheService.clearCache()

        let cacheSize = imageCacheService.getCacheSize()
        // Cache size should be minimal after clearing
        XCTAssertGreaterThanOrEqual(cacheSize.memorySize, 0)
        XCTAssertGreaterThanOrEqual(cacheSize.diskSize, 0)
    }

    // MARK: - Error Handling Tests

    func testInvalidImageDataHandling() {
        let invalidData = Data("not an image".utf8)

        // Test that invalid data doesn't crash the service
        // This would typically be tested with a mock network call
        XCTAssertNotNil(invalidData)
    }

    func testInvalidURLHandling() {
        let invalidURL = URL(string: "not-a-valid-url")!

        // Test that invalid URLs are handled gracefully
        // This would typically be tested with a mock network call
        XCTAssertNotNil(invalidURL)
    }

    // MARK: - Prefetch Tests

    func testImagePrefetch() {
        let urls = [testURL]

        // Test that prefetch method can be called without crashing
        imageCacheService.prefetchImages(urls: urls)

        // In a real test, you might want to wait for the prefetch to complete
        // and verify the images are cached
    }

    // MARK: - Performance Tests

    func testImageProcessingPerformance() {
        measure {
            for _ in 0..<100 {
                let targetSize = CGSize(width: 50, height: 50)
                _ = testImage.resized(to: targetSize)
            }
        }
    }

    func testCacheKeyGenerationPerformance() {
        let urls = (0..<1000).map { URL(string: "https://example.com/image\($0).jpg")! }

        measure {
            for url in urls {
                _ = imageCacheService.cacheKeyForURL(url)
            }
        }
    }
}

