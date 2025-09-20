//
//  FilteringService.swift
//  PT Resources
//
//  Unified filtering service for consistent filtering across the app
//

import Foundation
import Combine

// MARK: - Filter Type

enum FilterType {
    case speaker
    case conference
    case conferenceType
    case bibleBook
    case year
    case collection
    case topic
    case series
}

// MARK: - Filter Option

struct LocalFilterOption: Identifiable, Hashable {
    let id = UUID()
    let type: FilterType
    let value: String
    let displayName: String
    let count: Int
    let icon: String
    let color: String
    
    init(type: FilterType, value: String, displayName: String, count: Int = 0, icon: String = "circle", color: String = "blue") {
        self.type = type
        self.value = value
        self.displayName = displayName
        self.count = count
        self.icon = icon
        self.color = color
    }
}

// MARK: - Sorting Options
// Note: TalkSortOption is defined in Talk.swift - we'll use that instead

// MARK: - Filtering Service Protocol

@MainActor
protocol FilteringServiceProtocol: ObservableObject {
    var isFiltering: Bool { get }
    var lastFilteredCount: (total: Int, filtered: Int)? { get }
    
    func filterTalks(_ talks: [Talk], with filters: TalkSearchFilters) -> [Talk]
    func filterConferences(_ conferences: [ConferenceInfo], with filters: ConferenceSearchFilters) -> [ConferenceInfo]
    func searchTalks(_ talks: [Talk], query: String) -> [Talk]
    func searchConferences(_ conferences: [ConferenceInfo], query: String) -> [ConferenceInfo]
    func generateFilterOptions(from talks: [Talk]) -> [LocalFilterOption]
    func sortTalks(_ talks: [Talk], by option: TalkSortOption) -> [Talk]
}

// MARK: - Filtering Service Implementation

@MainActor
final class FilteringService: ObservableObject, FilteringServiceProtocol {
    
    // MARK: - Published Properties
    
    @Published var isFiltering = false
    @Published var lastFilteredCount: (total: Int, filtered: Int)?
    
    // MARK: - Talk Filtering
    
    func filterTalks(_ talks: [Talk], with filters: TalkSearchFilters) -> [Talk] {
        isFiltering = true
        defer { isFiltering = false }
        
        var filteredTalks = talks
        
        // Apply search query filter
        if !filters.query.isEmpty {
            filteredTalks = searchTalks(filteredTalks, query: filters.query)
        }
        
        // Apply speaker filter
        if !filters.speakerIds.isEmpty {
            filteredTalks = filteredTalks.filter { talk in
                filters.speakerIds.contains { speakerId in
                    talk.speaker.lowercased().contains(speakerId.lowercased())
                }
            }
        }
        
        // Legacy speaker support
        if let speaker = filters.speaker, !speaker.isEmpty {
            filteredTalks = filteredTalks.filter { talk in
                talk.speaker.lowercased().contains(speaker.lowercased())
            }
        }
        
        // Apply conference filter
        if !filters.conferenceIds.isEmpty {
            filteredTalks = filteredTalks.filter { talk in
                guard let conferenceId = talk.conferenceId else { return false }
                return filters.conferenceIds.contains(conferenceId)
            }
        }
        
        // Apply conference type filter
        if !filters.conferenceTypes.isEmpty {
            filteredTalks = filteredTalks.filter { talk in
                guard let category = talk.category else { return false }
                return filters.conferenceTypes.contains(category)
            }
        }
        
        // Apply Bible book filter
        if !filters.bibleBookIds.isEmpty {
            filteredTalks = filteredTalks.filter { talk in
                guard let biblePassage = talk.biblePassage else { return false }
                return filters.bibleBookIds.contains { bookId in
                    biblePassage.lowercased().contains(bookId.lowercased())
                }
            }
        }
        
        // Apply year filter
        if !filters.years.isEmpty {
            filteredTalks = filteredTalks.filter { talk in
                let dateRecorded = talk.dateRecorded
                let year = Calendar.current.component(.year, from: dateRecorded)
                return filters.years.contains(String(year))
            }
        }
        
        // Apply collection filter
        if !filters.collections.isEmpty {
            filteredTalks = filteredTalks.filter { talk in
                // Collection filtering logic would go here
                // For now, return true to avoid filtering out talks
                true
            }
        }
        
        // Apply date range filter
        if let dateFrom = filters.dateFrom {
            filteredTalks = filteredTalks.filter { talk in
                let dateRecorded = talk.dateRecorded
                return dateRecorded >= dateFrom
            }
        }
        
        if let dateTo = filters.dateTo {
            filteredTalks = filteredTalks.filter { talk in
                let dateRecorded = talk.dateRecorded
                return dateRecorded <= dateTo
            }
        }
        
        // Apply transcript filter
        if let hasTranscript = filters.hasTranscript {
            filteredTalks = filteredTalks.filter { talk in
                // This would check if talk has transcript
                // For now, return true to avoid filtering
                true
            }
        }
        
        // Apply download filter
        if let isDownloaded = filters.isDownloaded {
            filteredTalks = filteredTalks.filter { talk in
                // This would check if talk is downloaded
                // For now, return true to avoid filtering
                true
            }
        }
        
        // Update filter statistics
        lastFilteredCount = (total: talks.count, filtered: filteredTalks.count)
        
        return filteredTalks
    }
    
    // MARK: - Conference Filtering
    
    func filterConferences(_ conferences: [ConferenceInfo], with filters: ConferenceSearchFilters) -> [ConferenceInfo] {
        isFiltering = true
        defer { isFiltering = false }
        
        var filteredConferences = conferences
        
        // Apply search query filter
        if !filters.query.isEmpty {
            filteredConferences = searchConferences(filteredConferences, query: filters.query)
        }
        
        // Update filter statistics
        lastFilteredCount = (total: conferences.count, filtered: filteredConferences.count)
        
        return filteredConferences
    }
    
    // MARK: - Search Functions
    
    func searchTalks(_ talks: [Talk], query: String) -> [Talk] {
        guard !query.isEmpty else { return talks }
        
        let lowercaseQuery = query.lowercased()
        let searchTerms = lowercaseQuery.components(separatedBy: " ").filter { !$0.isEmpty }
        
        return talks.filter { talk in
            let searchableText = [
                talk.title,
                talk.speaker,
                talk.biblePassage ?? "",
                talk.series ?? ""
            ].map { $0.lowercased() }.joined(separator: " ")
            
            return searchTerms.allSatisfy { term in
                searchableText.contains(term)
            }
        }
    }
    
    func searchConferences(_ conferences: [ConferenceInfo], query: String) -> [ConferenceInfo] {
        guard !query.isEmpty else { return conferences }
        
        let lowercaseQuery = query.lowercased()
        
        return conferences.filter { conference in
            let searchableText = [
                conference.title,
                conference.description ?? ""
            ].compactMap { $0?.lowercased() }.joined(separator: " ")
            
            return searchableText.contains(lowercaseQuery)
        }
    }
    
    // MARK: - Filter Options Generation
    
    func generateFilterOptions(from talks: [Talk]) -> [LocalFilterOption] {
        var options: [LocalFilterOption] = []
        
        // Generate speaker options
        let speakers = Set(talks.map { $0.speaker }).sorted()
        options.append(contentsOf: speakers.map { speaker in
            LocalFilterOption(type: .speaker, value: speaker, displayName: speaker, icon: "person", color: "blue")
        })
        
        // Generate year options
        let years = Set(talks.map { talk in
            String(Calendar.current.component(.year, from: talk.dateRecorded))
        }).sorted(by: >)
        
        options.append(contentsOf: years.map { year in
            LocalFilterOption(type: .year, value: year, displayName: year, icon: "calendar", color: "green")
        })
        
        return options
    }
    
    // MARK: - Sorting
    
    func sortTalks(_ talks: [Talk], by option: TalkSortOption) -> [Talk] {
        switch option {
        case .dateNewest:
            return talks.sorted { $0.dateRecorded > $1.dateRecorded }
        case .dateOldest:
            return talks.sorted { $0.dateRecorded < $1.dateRecorded }
        case .titleAZ:
            return talks.sorted { $0.title < $1.title }
        case .titleZA:
            return talks.sorted { $0.title > $1.title }
        }
    }
}