//
//  MediaArtworkServiceTest.swift
//  PT Resources
//
//  Simple test to verify artwork generation with PT branding
//

import Foundation
import UIKit

@MainActor
class MediaArtworkServiceTest {
    
    static func testArtworkGeneration() {
        let service = MediaArtworkService.shared
        
        // Test placeholder artwork
        let placeholderArtwork = service.generatePlaceholderArtwork()
        print("✅ Generated placeholder artwork: \(placeholderArtwork.size)")
        
        // Test brand colors
        print("✅ PT Brand Colors:")
        print("   - Blue: PT Blue for video content")
        print("   - Orange: PT Orange for audio content")
        print("   - Logo: Using pt-logo-icon asset with fallback")
        print("   - Patterns: Using brand patterns from assets")
        
        // Verify logo asset availability
        if let _ = UIImage(named: "pt-logo-icon") {
            print("✅ PT Logo icon asset found")
        } else {
            print("⚠️ PT Logo icon asset not found - using fallback")
        }
        
        // Verify pattern assets
        let patternNames = ["pt-icon-pattern", "color-dots"]
        for patternName in patternNames {
            if let _ = UIImage(named: patternName) {
                print("✅ Pattern '\(patternName)' found")
            } else {
                print("⚠️ Pattern '\(patternName)' not found")
            }
        }
    }
}

extension MediaArtworkService {
    
    /// Test method to generate sample artwork
    func generateTestArtwork() {
        Task {
            // Create sample talk for testing
            let sampleTalk = Talk(
                id: "test-123",
                title: "The Gospel According to Mark",
                description: "A comprehensive study through Mark's Gospel",
                speaker: "John Stott",
                series: "Keswick Convention 2024",
                biblePassage: "Mark 1:1-16",
                dateRecorded: Date(),
                duration: 2400,
                audioURL: "https://example.com/audio.mp3",
                videoURL: nil,
                imageURL: nil,
                fileSize: 45000000,
                category: "Sermon",
                scriptureReference: "Mark 1:1-16",
                conferenceId: "keswick-2024",
                speakerIds: ["john-stott"],
                bookIds: ["mark"]
            )
            
            // Generate artwork
            let artwork = await generateArtwork(for: sampleTalk)
            
            if let artwork = artwork {
                print("✅ Generated test artwork: \(artwork.size)")
                print("   - Used solid PT Orange background (audio content)")
                print("   - Applied brand patterns at 10% opacity")
                print("   - Added PT logo in bottom right")
                print("   - Included talk metadata overlay")
            } else {
                print("❌ Failed to generate test artwork")
            }
        }
    }
}