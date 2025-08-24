# PT Resources iOS App

A comprehensive SwiftUI iOS app for the Proclamation Trust that provides access to talks (sermons/lectures) with offline playback, server-side transcription, variable-speed playback, and Bible passage integration.

## Features

- **Talks Library**: Browse, search, and filter talks from the Proclamation Trust API
- **Offline Playback**: Download talks for offline listening with automatic resume
- **Variable Speed Playback**: 0.5x to 3.0x speed with pitch correction
- **Transcription**: Server-side Whisper transcription with timestamp sync
- **Bible Integration**: ESV Bible passages displayed alongside talks
- **Background Playback**: Lock screen controls and background audio
- **Search & Filters**: Full-text search with speaker, series, and date filters
- **Storage Management**: Monitor and manage downloaded content
- **Future-ready**: Stubs for podcast RSS, blog integration, and push notifications

## Project Structure

```
PT Resources/
├── PT Resources/
│   ├── PT_ResourcesApp.swift           # App entry point
│   ├── Config.swift                    # Configuration and API keys
│   ├── ContentView.swift               # Main tab view
│   ├── Models/                         # Data models
│   │   ├── Talk.swift                  # Talk, Speaker, Series models
│   │   ├── Transcription.swift         # Transcription models
│   │   └── ESVPassage.swift           # Bible passage models
│   ├── Services/                       # Business logic services
│   │   ├── TalksAPIService.swift       # API communication
│   │   ├── PlayerService.swift         # Audio playback
│   │   ├── DownloadService.swift       # File downloads
│   │   ├── TranscriptionService.swift  # Whisper transcription
│   │   ├── ESVService.swift            # Bible passages
│   │   └── StubServices.swift          # Future features
│   ├── ViewModels/                     # MVVM view models
│   │   └── TalksViewModel.swift        # Talks list logic
│   ├── Views/                          # SwiftUI views
│   │   ├── TalksListView.swift         # Main talks list
│   │   ├── TalkRowView.swift           # Individual talk row
│   │   ├── MiniPlayerView.swift        # Bottom mini player
│   │   └── FilterSortViews.swift       # Filter/sort sheets
│   ├── Persistence/                    # Core Data stack
│   │   ├── PersistenceController.swift # Core Data controller
│   │   └── PTResources.xcdatamodeld/   # Data model
│   └── Resources/                      # Localization
│       └── Localizable.strings         # String resources
├── PT ResourcesTests/                  # Unit tests
├── PT ResourcesUITests/                # UI tests
└── README.md                          # This file
```

## Setup Instructions

### 1. Prerequisites

- Xcode 15.0 or later
- iOS 17.0+ deployment target
- Active Apple Developer account (for device testing)

### 2. API Keys Configuration

The app uses several external APIs. To configure them:

1. **Create a `Secrets.xcconfig` file** in the project root:

```bash
touch Secrets.xcconfig
```

2. **Add your API keys** to `Secrets.xcconfig`:

```
// Proclamation Trust API
PROCLAMATION_API_BASE_URL = https://www.proctrust.org.uk/api/resources

// ESV Bible API (get from https://api.esv.org/)
ESV_API_KEY = your_esv_api_key_here

// Transcription service (replace with your Whisper service)
TRANSCRIPTION_API_URL = https://transcription.yourservice.com/v1
TRANSCRIPTION_API_KEY = your_transcription_api_key_here

// Podcast and blog feeds (replace with actual URLs)
PODCAST_FEED_URL = https://feeds.proctrust.org.uk/podcast.xml
BLOG_FEED_URL = https://proctrust.org.uk/blog/feed.xml

// Push notification server (replace with your endpoint)
PUSH_SERVER_ENDPOINT = https://api.proctrust.org.uk/v1/push
```

3. **Update `Config.swift`** to use the environment variables:

```swift
// In Config.swift, replace placeholder values:
static let esvAPIKey = ProcessInfo.processInfo.environment["ESV_API_KEY"] ?? "YOUR_ESV_API_KEY_HERE"
// ... repeat for other keys
```

4. **Add to `.gitignore`**:

```
Secrets.xcconfig
*.xcconfig
```

### 3. Xcode Project Configuration

1. **Configure the xcconfig file**:
   - In Xcode, select the project root
   - Go to Build Settings
   - Under "Based on Configuration File", set Debug and Release to use `Secrets.xcconfig`

2. **Add Core Data model to project**:
   - The `PTResources.xcdatamodeld` file should be added to the Xcode project
   - Ensure it's included in the app target

3. **Configure capabilities**:
   - Background Modes: Enable "Audio, AirPlay, and Picture in Picture"
   - Push Notifications: Enable for future push notification support

### 4. Running the App

#### In iOS Simulator (Mock Mode)

The app includes comprehensive mock data and services, so it runs fully in the simulator without real API keys:

```bash
# Build and run in simulator
xcodebuild -project "PT Resources/PT Resources.xcodeproj" -scheme "PT Resources" -destination 'platform=iOS Simulator,name=iPhone 15' build

# Or run tests
xcodebuild test -project "PT Resources/PT Resources.xcodeproj" -scheme "PT Resources" -destination 'platform=iOS Simulator,name=iPhone 15'
```

#### On Physical Device (Production Mode)

For device testing with real APIs:

1. Add valid API keys to `Secrets.xcconfig`
2. Build and run on device
3. The app will automatically detect real vs mock API keys

## API Integration Guide

### Talks API Contract

The app integrates with the actual Proclamation Trust API:

**Base URL:** `https://www.proctrust.org.uk/api/resources`

**Available Endpoints:**
```
GET /resources?q=query&speaker=speaker&series=series&page=1
- Main resources listing with search and filters

GET /resources/{id}  
- Individual resource/talk details

GET /resources/blog-post
- Blog posts from the Proclamation Trust

GET /resources/filters
- Available filter options (speakers, series, etc.)

GET /resources/latest
- Latest resources/talks

GET /resources/stats
- API statistics and metadata
```

**Expected Response Structure:**
The app handles various response formats and will need to be tested with the actual API responses to ensure proper data mapping.

### ESV API Integration

Uses the ESV REST API v3:

```
GET https://api.esv.org/v3/passage/text/?q={reference}
Headers: Authorization: {ESV_API_KEY}
```

### Transcription Service

Expected server-side Whisper integration:

```
POST /transcriptions
Body: {
  "audio_url": "https://...",
  "talk_id": "123",
  "language": "en",
  "priority": "normal"
}
Response: {
  "job_id": "job-456",
  "status": "pending",
  "estimated_completion_time": "2023-12-31T23:59:59Z"
}

GET /transcriptions/{job_id}
Response: {
  "job_id": "job-456",
  "status": "completed",
  "progress": 1.0,
  "result": Transcript,
  "error": null
}
```

## Development

### Mock Data

The app includes comprehensive mock data that allows development without real API keys:

- `Talk.mockTalks` - Sample talks data
- `ESVPassage.mockPassages` - Sample Bible passages
- `Transcript.mockTranscript` - Sample transcription
- Mock services for all API integrations

### Testing

Run tests with:

```bash
# Unit tests
xcodebuild test -project "PT Resources/PT Resources.xcodeproj" -scheme "PT Resources" -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:PT_ResourcesTests

# UI tests
xcodebuild test -project "PT Resources/PT Resources.xcodeproj" -scheme "PT Resources" -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:PT_ResourcesUITests
```

### Debugging Features

For development, the app includes:

- Network request logging
- Core Data debugging
- Mock service toggles
- Download progress monitoring

## Production Deployment

### 1. TestFlight

1. **Archive build**:
   ```bash
   xcodebuild archive -project "PT Resources/PT Resources.xcodeproj" -scheme "PT Resources" -archivePath "PT Resources.xcarchive"
   ```

2. **Upload to App Store Connect**:
   ```bash
   xcodebuild -exportArchive -archivePath "PT Resources.xcarchive" -exportOptionsPlist ExportOptions.plist -exportPath .
   ```

### 2. Production Configuration

For production release:

1. **Update API endpoints** in `Config.swift` to production URLs
2. **Configure APNs** for push notifications
3. **Set up analytics** service integration
4. **Configure crash reporting**
5. **Add privacy policy** and terms of service links

### 3. Required Permissions

The app requires these iOS permissions:

- **Media Library**: For audio playbook
- **Background App Refresh**: For download completion
- **Notifications**: For transcription and download alerts (optional)

## Future Enhancements

The codebase includes stubs for:

1. **Podcast Integration**: RSS feed parsing (`PodcastService`)
2. **Blog Integration**: Blog RSS feed (`BlogService`) 
3. **Push Notifications**: APNs registration (`NotificationsService`)
4. **Analytics**: Privacy-first analytics (`AnalyticsService`)
5. **CloudKit Sync**: Cross-device synchronization
6. **CarPlay**: In-car playback interface

## Architecture Notes

- **MVVM Pattern**: ViewModels manage business logic
- **Dependency Injection**: Services are mockable for testing
- **Core Data**: Local persistence with background contexts
- **Combine**: Reactive programming for data flow
- **Swift Concurrency**: Modern async/await patterns
- **Background URLSession**: Reliable downloads
- **AVAudioEngine**: Pitch-corrected speed control

## Support

For development issues:

1. Check the mock services are working in simulator
2. Verify API key configuration in `Secrets.xcconfig`
3. Review Core Data model consistency
4. Test with network debugging enabled

## License

Copyright © 2024 Proclamation Trust. All rights reserved.

---

## TODO for Production

- [ ] Replace mock API endpoints with production URLs
- [ ] Add real ESV API key
- [ ] Implement server-side transcription service
- [ ] Configure APNs for push notifications
- [ ] Add analytics service integration
- [ ] Implement deep linking for universal links
- [ ] Add comprehensive error handling
- [ ] Performance optimization for large talk libraries
- [ ] Accessibility improvements
- [ ] Internationalization (i18n)