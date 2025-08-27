# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PT Resources is a comprehensive SwiftUI iOS app for the Proclamation Trust that provides access to talks (sermons/lectures) with offline playback, server-side transcription, variable-speed playback, and Bible passage integration.

## Build and Development Commands

Since this is an iOS Xcode project, development is primarily done through Xcode or xcodebuild:

- **Build the project**: `xcodebuild build -project "PT Resources/PT Resources.xcodeproj" -scheme "PT Resources" -destination 'platform=iOS Simulator,name=iPhone 15' -configuration Debug`
- **Run unit tests**: `xcodebuild test -project "PT Resources/PT Resources.xcodeproj" -scheme "PT Resources" -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:PT_ResourcesTests`
- **Run UI tests**: `xcodebuild test -project "PT Resources/PT Resources.xcodeproj" -scheme "PT Resources" -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:PT_ResourcesUITests`

## Architecture

### Core Structure
- **App Entry Point**: `PT_ResourcesApp.swift` - Main app with Core Data integration
- **Main UI**: `ContentView.swift` - TabView with Talks, Downloads, Settings tabs
- **Core Data Stack**: `PersistenceController.swift` + `PTResources.xcdatamodeld` + `CoreDataEntities.swift`

### Key Components
- **Models**: API models (`Talk.swift`, `Transcription.swift`, `ESVPassage.swift`)
- **Services**: API integration (`TalksAPIService.swift`), audio playback (`PlayerService.swift`), downloads (`DownloadService.swift`), transcription (`TranscriptionService.swift`)
- **ViewModels**: MVVM pattern (`TalksViewModel.swift`)
- **Views**: SwiftUI views (`TalksListView.swift`, `TalkRowView.swift`, etc.)

### API Integration
- **Base URL**: `https://www.proctrust.org.uk/api/resources`
- **Mock Services**: Comprehensive mock data for development without API keys
- **Real API**: Configured to work with actual Proclamation Trust API

## Key Technologies

- SwiftUI + Combine + Swift Concurrency (async/await)
- Core Data for local persistence
- AVPlayer + AVAudioEngine for audio playback with variable speed
- URLSession background downloads
- Swift Testing + XCTest
- iOS 17.0+ deployment target

## Development Notes

### Core Data
- Entities are defined in `PTResources.xcdatamodeld`
- NSManagedObject subclasses in `CoreDataEntities.swift`  
- Background contexts for imports/exports

### Mock vs Production  
- App now uses real Proclamation Trust APIs by default
- Mock services only used when explicitly requested with `--use-mock-services` launch argument
- All download functionality works with real API endpoints

### Common Build Issues
- If Core Data entities not found: Ensure `CoreDataEntities.swift` is in target  
- If API requests fail: App now uses real APIs; check network connectivity and API availability

### Download System
- Downloads now use direct `audioUrl` and `videoUrl` from talk detail API responses
- Audio files saved to `Documents/audio/{talkID}.mp3`  
- Video files saved to `Documents/video/{talkID}.mp4`
- Download validation includes file size verification and integrity checks
- Supports both audio-only and video-only talks (Vimeo URLs noted but not yet implemented)