//
//  ModelTests.swift
//  PT ResourcesTests
//
//  Unit tests for data models
//

import XCTest
@testable import PT_Resources

final class ModelTests: XCTestCase {

    // MARK: - Talk Model Tests

    func testTalkModelCreation() {
        let talk = Talk(
            id: "test-id",
            title: "Test Talk",
            description: "This is a test talk description",
            speaker: "Test Speaker",
            series: "Test Series",
            biblePassage: "John 1:1-5",
            dateRecorded: Date(),
            duration: 1800,
            audioURL: "https://example.com/audio.mp3",
            imageURL: "https://example.com/image.jpg",
            fileSize: 45_000_000
        )

        XCTAssertEqual(talk.id, "test-id")
        XCTAssertEqual(talk.title, "Test Talk")
        XCTAssertEqual(talk.speaker, "Test Speaker")
        XCTAssertEqual(talk.duration, 1800)
        XCTAssertEqual(talk.biblePassage, "John 1:1-5")
    }

    func testTalkFormattedDuration() {
        // Test various duration formats
        let talk1 = Talk.mockTalks[0] // Should have duration
        let formatted = talk1.formattedDuration

        // Duration should be in mm:ss or hh:mm:ss format
        XCTAssertFalse(formatted.isEmpty)

        if talk1.duration < 3600 {
            // Should be mm:ss format
            let components = formatted.split(separator: ":")
            XCTAssertEqual(components.count, 2, "Short duration should be mm:ss format")
        }
    }

    func testTalkFormattedDate() {
        let talk = Talk.mockTalks[0]
        let formatted = talk.formattedDate

        // Should be a non-empty date string
        XCTAssertFalse(formatted.isEmpty)
        // Should contain year or be a relative date
        XCTAssertTrue(formatted.contains("202") || formatted.contains("ago") || formatted.contains("Today"))
    }

    func testTalkMockData() {
        let mockTalks = Talk.mockTalks

        XCTAssertGreaterThan(mockTalks.count, 0, "Should have mock talks")

        for talk in mockTalks {
            XCTAssertFalse(talk.id.isEmpty, "Talk ID should not be empty")
            XCTAssertFalse(talk.title.isEmpty, "Talk title should not be empty")
            XCTAssertFalse(talk.speaker.isEmpty, "Talk speaker should not be empty")
            XCTAssertGreaterThan(talk.duration, 0, "Talk duration should be positive")
            XCTAssertFalse(talk.audioURL.isEmpty, "Talk audio URL should not be empty")
        }
    }

    // MARK: - Codable Tests

    func testTalkCodable() {
        let talk = Talk(
            id: "test-id",
            title: "Test Talk",
            description: "Test description",
            speaker: "Test Speaker",
            series: "Test Series",
            biblePassage: "John 1:1",
            dateRecorded: Date(),
            duration: 1800,
            audioURL: "https://example.com/audio.mp3",
            imageURL: "https://example.com/image.jpg",
            fileSize: 1024
        )

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(talk)

            let decoder = JSONDecoder()
            let decodedTalk = try decoder.decode(Talk.self, from: data)

            XCTAssertEqual(decodedTalk.id, talk.id)
            XCTAssertEqual(decodedTalk.title, talk.title)
            XCTAssertEqual(decodedTalk.speaker, talk.speaker)
            XCTAssertEqual(decodedTalk.duration, talk.duration)

        } catch {
            XCTFail("Talk should be codable: \(error)")
        }
    }

    func testTalkWithOptionalValuesCodable() {
        let talk = Talk(
            id: "test-id",
            title: "Test Talk",
            description: nil,
            speaker: "Test Speaker",
            series: nil,
            biblePassage: nil,
            dateRecorded: nil,
            duration: 1800,
            audioURL: "https://example.com/audio.mp3",
            imageURL: nil,
            fileSize: nil
        )

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(talk)

            let decoder = JSONDecoder()
            let decodedTalk = try decoder.decode(Talk.self, from: data)

            XCTAssertEqual(decodedTalk.id, talk.id)
            XCTAssertEqual(decodedTalk.title, talk.title)
            XCTAssertNil(decodedTalk.description)
            XCTAssertNil(decodedTalk.series)
            XCTAssertNil(decodedTalk.biblePassage)

        } catch {
            XCTFail("Talk with optional values should be codable: \(error)")
        }
    }

    // MARK: - ESVPassage Tests

    func testESVPassageMockData() {
        let mockPassages = ESVPassage.mockPassages

        XCTAssertGreaterThan(mockPassages.count, 0, "Should have mock ESV passages")

        for passage in mockPassages {
            XCTAssertFalse(passage.reference.isEmpty, "Passage reference should not be empty")
            XCTAssertFalse(passage.text.isEmpty, "Passage text should not be empty")
        }
    }

    func testESVPassageCodable() {
        let passage = ESVPassage.mockPassages[0]

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(passage)

            let decoder = JSONDecoder()
            let decodedPassage = try decoder.decode(ESVPassage.self, from: data)

            XCTAssertEqual(decodedPassage.reference, passage.reference)
            XCTAssertEqual(decodedPassage.text, passage.text)

        } catch {
            XCTFail("ESVPassage should be codable: \(error)")
        }
    }

    // MARK: - Transcription Tests

    func testTranscriptionMockData() {
        let mockTranscription = Transcription.mockTranscript

        XCTAssertFalse(mockTranscription.id.isEmpty, "Transcription ID should not be empty")
        XCTAssertFalse(mockTranscription.text.isEmpty, "Transcription text should not be empty")
        XCTAssertGreaterThan(mockTranscription.segments.count, 0, "Should have segments")
    }

    func testTranscriptionCodable() {
        let transcription = Transcription.mockTranscript

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(transcription)

            let decoder = JSONDecoder()
            let decodedTranscription = try decoder.decode(Transcription.self, from: data)

            XCTAssertEqual(decodedTranscription.id, transcription.id)
            XCTAssertEqual(decodedTranscription.text, transcription.text)
            XCTAssertEqual(decodedTranscription.segments.count, transcription.segments.count)

        } catch {
            XCTFail("Transcription should be codable: \(error)")
        }
    }

    // MARK: - Chapter Tests

    func testChapterMockData() {
        let mockChapters = Talk.mockChapters

        XCTAssertGreaterThan(mockChapters.count, 0, "Should have mock chapters")

        for chapter in mockChapters {
            XCTAssertFalse(chapter.id.isEmpty, "Chapter ID should not be empty")
            XCTAssertFalse(chapter.title.isEmpty, "Chapter title should not be empty")
            XCTAssertGreaterThanOrEqual(chapter.startTime, 0, "Start time should be non-negative")
            XCTAssertGreaterThan(chapter.endTime, chapter.startTime, "End time should be after start time")
        }
    }

    func testChapterCodable() {
        let chapter = Talk.mockChapters[0]

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(chapter)

            let decoder = JSONDecoder()
            let decodedChapter = try decoder.decode(Chapter.self, from: data)

            XCTAssertEqual(decodedChapter.id, chapter.id)
            XCTAssertEqual(decodedChapter.title, chapter.title)
            XCTAssertEqual(decodedChapter.startTime, chapter.startTime, accuracy: 0.001)

        } catch {
            XCTFail("Chapter should be codable: \(error)")
        }
    }

    // MARK: - LatestContent Tests

    func testLatestContentCodable() {
        let latestContent = LatestContent(
            blogPost: LatestBlogPost(
                id: "blog-1",
                title: "Test Blog Post",
                excerpt: "This is a test blog post",
                author: "Test Author",
                date: "2024-01-15",
                imageURL: "https://example.com/blog-image.jpg",
                category: "Theology"
            ),
            latestConference: ConferenceMedia(
                conferenceId: "conf-1",
                title: "Test Conference",
                excerpt: "This is a test conference",
                imageURL: "https://example.com/conference-image.jpg",
                category: "Conference"
            ),
            archiveMedia: ConferenceMedia(
                conferenceId: "conf-2",
                title: "Archive Conference",
                excerpt: "This is an archive conference",
                imageURL: "https://example.com/archive-image.jpg",
                category: "Archive"
            )
        )

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(latestContent)

            let decoder = JSONDecoder()
            let decodedContent = try decoder.decode(LatestContent.self, from: data)

            XCTAssertEqual(decodedContent.blogPost?.id, latestContent.blogPost?.id)
            XCTAssertEqual(decodedContent.latestConference?.conferenceId, latestContent.latestConference?.conferenceId)

        } catch {
            XCTFail("LatestContent should be codable: \(error)")
        }
    }

    // MARK: - ResourceDetail Tests

    func testResourceDetailCodable() {
        let resourceDetail = ResourceDetail(
            id: "resource-1",
            title: "Test Resource",
            description: "This is a test resource",
            speaker: "Test Speaker",
            series: "Test Series",
            biblePassage: "John 1:1",
            dateRecorded: Date(),
            duration: 1800,
            audioURL: "https://example.com/audio.mp3",
            videoURL: "https://example.com/video.mp4",
            imageURL: "https://example.com/image.jpg",
            fileSize: 1024,
            downloadURL: "https://example.com/download.mp3",
            transcriptionURL: "https://example.com/transcription.json",
            chapters: Talk.mockChapters,
            relatedResources: []
        )

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(resourceDetail)

            let decoder = JSONDecoder()
            let decodedDetail = try decoder.decode(ResourceDetail.self, from: data)

            XCTAssertEqual(decodedDetail.id, resourceDetail.id)
            XCTAssertEqual(decodedDetail.title, resourceDetail.title)
            XCTAssertEqual(decodedDetail.chapters.count, resourceDetail.chapters.count)

        } catch {
            XCTFail("ResourceDetail should be codable: \(error)")
        }
    }

    // MARK: - Performance Tests

    func testModelCreationPerformance() {
        measure {
            for i in 0..<1000 {
                let _ = Talk(
                    id: "perf-test-\(i)",
                    title: "Performance Test Talk \(i)",
                    description: "This is a performance test talk",
                    speaker: "Performance Speaker",
                    series: "Performance Series",
                    biblePassage: "John \(i):1",
                    dateRecorded: Date(),
                    duration: 1800,
                    audioURL: "https://example.com/audio\(i).mp3",
                    imageURL: "https://example.com/image\(i).jpg",
                    fileSize: 1024 * 1024
                )
            }
        }
    }

    func testModelEncodingPerformance() {
        let talks = (0..<100).map { i in
            Talk(
                id: "encode-test-\(i)",
                title: "Encode Test Talk \(i)",
                description: "This is an encoding test talk",
                speaker: "Encode Speaker",
                series: "Encode Series",
                biblePassage: "John \(i):1",
                dateRecorded: Date(),
                duration: 1800,
                audioURL: "https://example.com/audio\(i).mp3",
                imageURL: "https://example.com/image\(i).jpg",
                fileSize: 1024 * 1024
            )
        }

        measure {
            let encoder = JSONEncoder()
            for talk in talks {
                let _ = try? encoder.encode(talk)
            }
        }
    }

    func testModelDecodingPerformance() {
        let talk = Talk.mockTalks[0]

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(talk)

            measure {
                let decoder = JSONDecoder()
                for _ in 0..<100 {
                    let _ = try? decoder.decode(Talk.self, from: data)
                }
            }
        } catch {
            XCTFail("Failed to set up decoding performance test: \(error)")
        }
    }

    // MARK: - Edge Case Tests

    func testTalkWithMinimalData() {
        let minimalTalk = Talk(
            id: "minimal",
            title: "Minimal Talk",
            description: nil,
            speaker: "Speaker",
            series: nil,
            biblePassage: nil,
            dateRecorded: nil,
            duration: 0,
            audioURL: "https://example.com/audio.mp3",
            imageURL: nil,
            fileSize: nil
        )

        XCTAssertEqual(minimalTalk.id, "minimal")
        XCTAssertEqual(minimalTalk.title, "Minimal Talk")
        XCTAssertEqual(minimalTalk.speaker, "Speaker")
        XCTAssertEqual(minimalTalk.duration, 0)
    }

    func testTalkWithExtremeValues() {
        let extremeTalk = Talk(
            id: String(repeating: "a", count: 1000),
            title: String(repeating: "Title ", count: 100),
            description: String(repeating: "Description ", count: 500),
            speaker: String(repeating: "Speaker ", count: 50),
            series: String(repeating: "Series ", count: 50),
            biblePassage: String(repeating: "John 1:1 ", count: 20),
            dateRecorded: Date.distantFuture,
            duration: Int.max,
            audioURL: "https://example.com/" + String(repeating: "a", count: 1000) + ".mp3",
            imageURL: "https://example.com/" + String(repeating: "b", count: 1000) + ".jpg",
            fileSize: Int64.max
        )

        // Test that the model can handle extreme values
        XCTAssertTrue(extremeTalk.id.count > 100)
        XCTAssertTrue(extremeTalk.title.count > 500)
        XCTAssertEqual(extremeTalk.duration, Int.max)
    }
}

