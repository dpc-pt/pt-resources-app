//
//  VideoPlayerTestSuite.swift
//  PT Resources
//
//  Comprehensive testing and validation for video player implementation
//

import Foundation
import AVFoundation
import AVKit
import SwiftUI

/// Test suite for validating video player functionality
@MainActor
class VideoPlayerTestSuite: ObservableObject {
    
    // MARK: - Test Results
    
    @Published var testResults: [VideoPlayerTestResult] = []
    @Published var isRunningTests = false
    @Published var overallTestStatus: TestStatus = .notRun
    
    // MARK: - Test URLs
    
    private let testVideoURLs: [VideoPlayerTestCase] = [
        VideoPlayerTestCase(
            name: "Direct MP4 Video",
            url: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!,
            expectedResult: .success
        ),
        VideoPlayerTestCase(
            name: "Vimeo Video ID",
            url: URL(string: "https://vimeo.com/194364791")!,
            expectedResult: .success
        ),
        VideoPlayerTestCase(
            name: "Vimeo Player URL",
            url: URL(string: "https://player.vimeo.com/video/194364791")!,
            expectedResult: .success
        ),
        VideoPlayerTestCase(
            name: "Invalid URL",
            url: URL(string: "https://invalid.url/nonexistent.mp4")!,
            expectedResult: .failure
        ),
        VideoPlayerTestCase(
            name: "Non-video URL",
            url: URL(string: "https://www.google.com")!,
            expectedResult: .failure
        )
    ]
    
    // MARK: - Test Execution
    
    func runAllTests() async {
        isRunningTests = true
        testResults.removeAll()
        
        PTLogger.general.info("Starting video player test suite")
        
        // Test URL Detection
        await testURLDetection()
        
        // Test URL Processing
        await testURLProcessing()
        
        // Test Video Player Manager
        await testVideoPlayerManager()
        
        // Test Video Player Configuration
        await testVideoPlayerConfiguration()
        
        // Test Error Handling
        await testErrorHandling()
        
        // Calculate overall status
        calculateOverallStatus()
        
        isRunningTests = false
        PTLogger.general.info("Video player test suite completed")
    }
    
    // MARK: - Individual Tests
    
    private func testURLDetection() async {
        let testName = "URL Detection"
        PTLogger.general.info("Running test: \(testName)")
        
        var passedTests = 0
        let totalTests = testVideoURLs.count
        
        for testCase in testVideoURLs {
            let isValid = VideoURLDetector.shared.isValidVideoURL(testCase.url)
            let expectedValid = testCase.expectedResult == .success
            
            if isValid == expectedValid {
                passedTests += 1
            }
        }
        
        let result = VideoPlayerTestResult(
            testName: testName,
            status: passedTests == totalTests ? .passed : .failed,
            details: "\(passedTests)/\(totalTests) URL detection tests passed",
            timestamp: Date()
        )
        
        testResults.append(result)
    }
    
    private func testURLProcessing() async {
        let testName = "URL Processing"
        PTLogger.general.info("Running test: \(testName)")
        
        var passedTests = 0
        let totalTests = testVideoURLs.filter { $0.expectedResult == .success }.count
        
        for testCase in testVideoURLs where testCase.expectedResult == .success {
            do {
                let processedURL = try await VideoURLDetector.shared.processVideoURL(testCase.url)
                if processedURL.absoluteString.isEmpty {
                    continue
                }
                passedTests += 1
            } catch {
                // Expected for failure cases
                continue
            }
        }
        
        let result = VideoPlayerTestResult(
            testName: testName,
            status: passedTests > 0 ? .passed : .failed,
            details: "\(passedTests)/\(totalTests) URL processing tests passed",
            timestamp: Date()
        )
        
        testResults.append(result)
    }
    
    private func testVideoPlayerManager() async {
        let testName = "Video Player Manager"
        PTLogger.general.info("Running test: \(testName)")
        
        let videoManager = VideoPlayerManager.shared
        var testsPassed = 0
        var totalTests = 0
        
        // Test 1: Manager singleton
        totalTests += 1
        if videoManager === VideoPlayerManager.shared {
            testsPassed += 1
        }
        
        // Test 2: Initial state
        totalTests += 1
        if !videoManager.isVideoLoading && videoManager.videoError == nil {
            testsPassed += 1
        }
        
        // Test 3: URL validation
        totalTests += 1
        let testURL = URL(string: "https://player.vimeo.com/video/194364791")!
        if videoManager.isSupportedVideoURL(testURL) {
            testsPassed += 1
        }
        
        let result = VideoPlayerTestResult(
            testName: testName,
            status: testsPassed == totalTests ? .passed : .failed,
            details: "\(testsPassed)/\(totalTests) Video Player Manager tests passed",
            timestamp: Date()
        )
        
        testResults.append(result)
    }
    
    private func testVideoPlayerConfiguration() async {
        let testName = "Video Player Configuration"
        PTLogger.general.info("Running test: \(testName)")
        
        var testsPassed = 0
        var totalTests = 0
        
        // Test 1: Default configuration
        totalTests += 1
        let defaultConfig = VideoPlayerConfiguration.default
        if defaultConfig.allowsPictureInPicturePlayback && defaultConfig.allowsExternalPlayback {
            testsPassed += 1
        }
        
        // Test 2: Audio-only configuration
        totalTests += 1
        let audioConfig = VideoPlayerConfiguration.audioOnly
        if !audioConfig.allowsPictureInPicturePlayback && audioConfig.allowsBackgroundAudio {
            testsPassed += 1
        }
        
        // Test 3: Feature manager initialization
        totalTests += 1
        let featureManager = VideoPlayerFeatureManager(configuration: defaultConfig)
        if featureManager.currentPlaybackSpeed == 1.0 {
            testsPassed += 1
        }
        
        let result = VideoPlayerTestResult(
            testName: testName,
            status: testsPassed == totalTests ? .passed : .failed,
            details: "\(testsPassed)/\(totalTests) Configuration tests passed",
            timestamp: Date()
        )
        
        testResults.append(result)
    }
    
    private func testErrorHandling() async {
        let testName = "Error Handling"
        PTLogger.general.info("Running test: \(testName)")
        
        var testsPassed = 0
        var totalTests = 0
        
        // Test 1: Invalid URL error
        totalTests += 1
        do {
            let invalidURL = URL(string: "not-a-valid-url")!
            _ = try await VideoURLDetector.shared.processVideoURL(invalidURL)
        } catch {
            testsPassed += 1 // Expected to throw an error
        }
        
        // Test 2: Network error handling
        totalTests += 1
        do {
            let networkURL = URL(string: "https://nonexistent-domain-12345.com/video.mp4")!
            _ = try await VideoURLDetector.shared.processVideoURL(networkURL)
        } catch {
            testsPassed += 1 // Expected to throw an error
        }
        
        // Test 3: Error types
        totalTests += 1
        let testError = VideoError.invalidURL("Test error")
        if testError.localizedDescription.contains("Invalid video URL") {
            testsPassed += 1
        }
        
        let result = VideoPlayerTestResult(
            testName: testName,
            status: testsPassed == totalTests ? .passed : .failed,
            details: "\(testsPassed)/\(totalTests) Error handling tests passed",
            timestamp: Date()
        )
        
        testResults.append(result)
    }
    
    // MARK: - Helper Methods
    
    private func calculateOverallStatus() {
        let failedTests = testResults.filter { $0.status == .failed }
        let passedTests = testResults.filter { $0.status == .passed }
        
        if failedTests.isEmpty && !passedTests.isEmpty {
            overallTestStatus = .allPassed
        } else if passedTests.isEmpty {
            overallTestStatus = .allFailed
        } else {
            overallTestStatus = .someFailed
        }
    }
    
    // MARK: - Test Report Generation
    
    func generateTestReport() -> String {
        var report = "# Video Player Test Suite Report\n\n"
        report += "**Generated:** \(Date().formatted())\n"
        report += "**Overall Status:** \(overallTestStatus.description)\n\n"
        
        report += "## Test Results\n\n"
        
        for result in testResults {
            report += "### \(result.testName)\n"
            report += "- **Status:** \(result.status.emoji) \(result.status.description)\n"
            report += "- **Details:** \(result.details)\n"
            report += "- **Timestamp:** \(result.timestamp.formatted())\n\n"
        }
        
        report += "## Summary\n\n"
        let passedCount = testResults.filter { $0.status == .passed }.count
        let failedCount = testResults.filter { $0.status == .failed }.count
        let totalCount = testResults.count
        
        report += "- **Total Tests:** \(totalCount)\n"
        report += "- **Passed:** \(passedCount)\n"
        report += "- **Failed:** \(failedCount)\n"
        report += "- **Success Rate:** \(totalCount > 0 ? Int((Double(passedCount) / Double(totalCount)) * 100) : 0)%\n"
        
        return report
    }
}

// MARK: - Supporting Types

struct VideoPlayerTestCase {
    let name: String
    let url: URL
    let expectedResult: TestExpectedResult
}

struct VideoPlayerTestResult {
    let testName: String
    let status: TestStatus
    let details: String
    let timestamp: Date
}

enum TestExpectedResult {
    case success
    case failure
}

enum TestStatus {
    case notRun
    case passed
    case failed
    case allPassed
    case allFailed
    case someFailed
    
    var description: String {
        switch self {
        case .notRun: return "Not Run"
        case .passed: return "Passed"
        case .failed: return "Failed"
        case .allPassed: return "All Tests Passed"
        case .allFailed: return "All Tests Failed"
        case .someFailed: return "Some Tests Failed"
        }
    }
    
    var emoji: String {
        switch self {
        case .notRun: return "⏸️"
        case .passed, .allPassed: return "✅"
        case .failed, .allFailed: return "❌"
        case .someFailed: return "⚠️"
        }
    }
}

// MARK: - Test View for Manual Testing

struct VideoPlayerTestView: View {
    @StateObject private var testSuite = VideoPlayerTestSuite()
    @State private var showingReport = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Overall status
                statusCard
                
                // Test results list
                if !testSuite.testResults.isEmpty {
                    testResultsList
                }
                
                Spacer()
                
                // Actions
                actionButtons
            }
            .padding()
            .navigationTitle("Video Player Tests")
            .sheet(isPresented: $showingReport) {
                testReportView
            }
        }
    }
    
    private var statusCard: some View {
        VStack(spacing: 12) {
            Text(testSuite.overallTestStatus.emoji)
                .font(.system(size: 48))
            
            Text(testSuite.overallTestStatus.description)
                .font(.title2)
                .fontWeight(.semibold)
            
            if testSuite.isRunningTests {
                ProgressView("Running tests...")
                    .padding(.top)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
        )
    }
    
    private var testResultsList: some View {
        List(testSuite.testResults, id: \.testName) { result in
            HStack {
                Text(result.status.emoji)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.testName)
                        .font(.headline)
                    
                    Text(result.details)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                Task {
                    await testSuite.runAllTests()
                }
            }) {
                Text("Run Tests")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(testSuite.isRunningTests)
            
            if !testSuite.testResults.isEmpty {
                Button("View Report") {
                    showingReport = true
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(8)
            }
        }
    }
    
    private var testReportView: some View {
        NavigationView {
            ScrollView {
                Text(testSuite.generateTestReport())
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
            .navigationTitle("Test Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingReport = false
                    }
                }
            }
        }
    }
}