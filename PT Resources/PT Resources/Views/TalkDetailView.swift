//
//  TalkDetailView.swift
//  PT Resources
//
//  Beautiful talk details view with PT design system
//

import SwiftUI
import WebKit

struct TalkDetailView: View {
    let talk: Talk
    @ObservedObject var playerService = PlayerService.shared
    @ObservedObject var downloadService: DownloadService
    @StateObject private var transcriptionService = TranscriptionService()
    @StateObject private var esvService = ESVService()
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingTranscript = false
    @State private var showingBiblePassage = false
    @StateObject private var biblePassageState = BiblePassageState()
    @State private var isDownloading = false
    @State private var downloadProgress: Float = 0.0
    @State private var isTalkDownloaded = false
    @State private var selectedMediaType: MediaType = .audio
    @State private var videoError: String?
    @State private var showingVideoError = false
    @State private var currentTranscript: Transcript?
    @State private var streamingTranscript: StreamingTranscript?
    @State private var showingTranscriptSearch = false
    @State private var transcriptSearchText = ""
    @State private var searchResults: [TranscriptSegment] = []
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero Section with Talk Art & Info
                    heroSection
                    
                    // Media Type Toggle (if multiple types available)
                    if talk.hasMultipleMediaTypes {
                        mediaTypeToggleSection
                            .padding(.horizontal, PTDesignTokens.Spacing.md)
                            .padding(.bottom, PTDesignTokens.Spacing.md)
                    }
                    
                    // Media Player Controls
                    mediaPlayerSection
                        .padding(.horizontal, PTDesignTokens.Spacing.md)
                        .padding(.bottom, PTDesignTokens.Spacing.lg)
                    
                    // Talk Information Card
                    talkInfoSection
                        .padding(.horizontal, PTDesignTokens.Spacing.md)
                        .padding(.bottom, PTDesignTokens.Spacing.lg)
                    
                    // Action Buttons
                    actionButtonsSection
                        .padding(.horizontal, PTDesignTokens.Spacing.md)
                        .padding(.bottom, PTDesignTokens.Spacing.xl)
                }
            }
            .background(PTDesignTokens.Colors.background)
            .navigationBarHidden(true)
        }
        .onAppear {
            loadBiblePassage()
            checkDownloadStatus()
            setInitialMediaType()
            loadTranscript()
        }
        .onReceive(NotificationCenter.default.publisher(for: .transcriptionCompleted)) { notification in
            if let talkID = notification.userInfo?["talkID"] as? String,
               talkID == talk.id {
                loadTranscript()
                streamingTranscript = nil // Clear streaming state
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .transcriptionProgress)) { notification in
            if let talkID = notification.userInfo?["talkID"] as? String,
               let progress = notification.userInfo?["progress"] as? Float,
               talkID == talk.id {
                if streamingTranscript == nil {
                    streamingTranscript = StreamingTranscript(talkID: talkID)
                }
                streamingTranscript?.updateProgress(progress)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .transcriptionSegmentAdded)) { notification in
            if let talkID = notification.userInfo?["talkID"] as? String,
               let segment = notification.userInfo?["segment"] as? TranscriptSegment,
               talkID == talk.id {
                if streamingTranscript == nil {
                    streamingTranscript = StreamingTranscript(talkID: talkID)
                }
                streamingTranscript?.addSegment(segment)
            }
        }
        .sheet(isPresented: $showingTranscript) {
            transcriptSheet
        }
        .sheet(isPresented: $showingBiblePassage) {
            biblePassageSheet
        }
        .alert("Video Error", isPresented: $showingVideoError) {
            Button("OK") {
                videoError = nil
                showingVideoError = false
            }
        } message: {
            Text(videoError ?? "An unknown error occurred")
        }
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        GeometryReader { geometry in
            ZStack {
                // Background image or default
                PTAsyncImage(url: talk.artworkURL.flatMap(URL.init)) {
                    defaultArtworkView
                }
                .aspectRatio(contentMode: .fill)
                .clipped()
                
                // Dark overlay for text readability
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                VStack(spacing: 0) {
                    // Navigation overlay
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(PTFont.ptCardTitle)
                                .foregroundColor(.white)
                                .padding(PTDesignTokens.Spacing.sm)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.4))
                                )
                        }
                        
                        Spacer()
                        
                        HStack(spacing: PTDesignTokens.Spacing.sm) {
                            // Download button
                            Button(action: toggleDownload) {
                                Group {
                                    if isDownloading {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .tint(.white)
                                    } else {
                                        Image(systemName: isTalkDownloaded ? "checkmark.circle.fill" : "arrow.down.circle")
                                            .font(PTFont.ptCardTitle)
                                    }
                                }
                                .foregroundColor(.white)
                                .padding(PTDesignTokens.Spacing.sm)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.4))
                                )
                            }
                            
                            // Share button
                            Button(action: shareTalk) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(PTFont.ptCardTitle)
                                    .foregroundColor(.white)
                                    .padding(PTDesignTokens.Spacing.sm)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.4))
                                    )
                            }
                        }
                    }
                    .padding(PTDesignTokens.Spacing.md)
                    .zIndex(1)
                    
                    Spacer()
                    
                    // Talk info overlay
                    VStack(spacing: PTDesignTokens.Spacing.md) {
                        Text(talk.title)
                            .font(PTFont.ptDisplayMedium)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        
                        Text(talk.speaker)
                            .font(PTFont.ptSectionTitle)
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        
                        HStack(spacing: PTDesignTokens.Spacing.md) {
                            if let biblePassage = talk.biblePassage {
                                Text(biblePassage)
                                    .font(PTFont.ptCaptionText)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, PTDesignTokens.Spacing.sm)
                                    .padding(.vertical, PTDesignTokens.Spacing.xs)
                                    .background(
                                        Capsule()
                                            .fill(Color.white.opacity(0.2))
                                    )
                            }
                            
                            Text(talk.formattedYear)
                                .font(PTFont.ptCaptionText)
                                .foregroundColor(.white.opacity(0.8))
                            
                            if talk.duration > 0 {
                                Text("•")
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Text(talk.formattedDuration)
                                    .font(PTFont.ptCaptionText)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                    .padding(PTDesignTokens.Spacing.lg)
                    .zIndex(1)
                }
            }
        }
        .frame(height: 320)
        .cornerRadius(PTDesignTokens.BorderRadius.xl, corners: [.bottomLeft, .bottomRight])
    }
    
    private var defaultArtworkView: some View {
        Rectangle()
            .fill(PTDesignTokens.Colors.veryLight)
            .overlay(
                PTLogo(size: 60, showText: false)
                    .opacity(0.3)
            )
    }
    
    
    
    
    // MARK: - Media Type Toggle Section
    
    private var mediaTypeToggleSection: some View {
        VStack(spacing: PTDesignTokens.Spacing.sm) {
            Text("Media Type")
                .font(PTFont.ptCardSubtitle)
                .foregroundColor(PTDesignTokens.Colors.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: PTDesignTokens.Spacing.sm) {
                ForEach(talk.availableMediaTypes, id: \.self) { mediaType in
                    Button(action: {
                        selectedMediaType = mediaType
                    }) {
                        HStack(spacing: PTDesignTokens.Spacing.sm) {
                            Image(systemName: mediaType.icon)
                                .font(.system(size: 16))
                            
                            Text(mediaType.displayName)
                                .font(PTFont.ptButtonText)
                        }
                        .foregroundColor(selectedMediaType == mediaType ? .white : PTDesignTokens.Colors.ink)
                        .padding(.horizontal, PTDesignTokens.Spacing.md)
                        .padding(.vertical, PTDesignTokens.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                                .fill(selectedMediaType == mediaType ? PTDesignTokens.Colors.tang : PTDesignTokens.Colors.veryLight)
                                .overlay(
                                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                                        .stroke(selectedMediaType == mediaType ? PTDesignTokens.Colors.tang : PTDesignTokens.Colors.light, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(PTDesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.lg)
                .fill(PTDesignTokens.Colors.surface)
                .shadow(color: PTDesignTokens.Colors.ink.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Media Player Section
    
    private var mediaPlayerSection: some View {
        VStack(spacing: PTDesignTokens.Spacing.lg) {
            // Media type indicator
            HStack {
                Image(systemName: selectedMediaType.icon)
                    .font(.system(size: 16))
                    .foregroundColor(PTDesignTokens.Colors.kleinBlue)
                
                Text("\(selectedMediaType.displayName) Player")
                    .font(PTFont.ptCardSubtitle)
                    .foregroundColor(PTDesignTokens.Colors.ink)
                
                Spacer()
            }
            
            // Progress bar (only for audio)
            if selectedMediaType == .audio {
                VStack(spacing: PTDesignTokens.Spacing.sm) {
                    ProgressView(value: playerService.currentTime, total: playerService.duration)
                        .progressViewStyle(PTMediaProgressStyle())
                        .frame(height: 6)
                    
                    HStack {
                        Text(timeString(from: playerService.currentTime))
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(PTDesignTokens.Colors.medium)
                            .monospacedDigit()
                        
                        Spacer()
                        
                        Text(timeString(from: playerService.duration))
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(PTDesignTokens.Colors.medium)
                            .monospacedDigit()
                    }
                }
            }
            
            // Playback controls
            HStack(spacing: PTDesignTokens.Spacing.xxl) {
                // Skip backward (10s) - only for audio
                if selectedMediaType == .audio {
                    Button(action: { playerService.skipBackward() }) {
                        Image(systemName: "gobackward.10")
                            .font(.system(size: 24))
                            .foregroundColor(PTDesignTokens.Colors.ink)
                            .padding(PTDesignTokens.Spacing.sm)
                            .background(
                                Circle()
                                    .fill(PTDesignTokens.Colors.veryLight)
                            )
                    }
                }
                
                // Play/Pause
                Button(action: togglePlayback) {
                    Group {
                        if selectedMediaType == .audio {
                            Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                        } else {
                            Image(systemName: "play.fill")
                        }
                    }
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .padding(PTDesignTokens.Spacing.lg)
                    .background(
                        Circle()
                            .fill(PTDesignTokens.Colors.tang)
                            .shadow(color: PTDesignTokens.Colors.tang.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                }
                .scaleEffect(selectedMediaType == .audio && playerService.isPlaying ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: selectedMediaType == .audio ? playerService.isPlaying : false)
                
                // Skip forward (30s) - only for audio
                if selectedMediaType == .audio {
                    Button(action: { playerService.skipForward() }) {
                        Image(systemName: "goforward.30")
                            .font(.system(size: 24))
                            .foregroundColor(PTDesignTokens.Colors.ink)
                            .padding(PTDesignTokens.Spacing.sm)
                            .background(
                                Circle()
                                    .fill(PTDesignTokens.Colors.veryLight)
                            )
                    }
                }
            }
            
            // Speed control (only for audio)
            if selectedMediaType == .audio {
                HStack {
                    Text("Playback Speed")
                        .font(PTFont.ptCardSubtitle)
                        .foregroundColor(PTDesignTokens.Colors.ink)
                    
                    Spacer()
                    
                    Button(action: { playerService.adjustPlaybackSpeed() }) {
                        Text("\(playerService.playbackSpeed, specifier: "%.1f")×")
                            .font(PTFont.ptButtonText)
                            .foregroundColor(PTDesignTokens.Colors.kleinBlue)
                            .padding(.horizontal, PTDesignTokens.Spacing.md)
                            .padding(.vertical, PTDesignTokens.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                                    .fill(PTDesignTokens.Colors.kleinBlue.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                                            .stroke(PTDesignTokens.Colors.kleinBlue, lineWidth: 1)
                                    )
                            )
                    }
                }
            }
        }
        .padding(PTDesignTokens.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.xl)
                .fill(PTDesignTokens.Colors.surface)
                .shadow(color: PTDesignTokens.Colors.ink.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Talk Info Section
    
    private var talkInfoSection: some View {
        VStack(spacing: PTDesignTokens.Spacing.lg) {
            // Series info (if available)
            if let series = talk.series {
                HStack {
                    VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.xs) {
                        Text("Series")
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(PTDesignTokens.Colors.medium)
                            .textCase(.uppercase)
                            .tracking(0.5)
                        
                        Text(series)
                            .font(PTFont.ptCardTitle)
                            .foregroundColor(PTDesignTokens.Colors.ink)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 24))
                        .foregroundColor(PTDesignTokens.Colors.kleinBlue)
                }
                .padding(PTDesignTokens.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.lg)
                        .fill(PTDesignTokens.Colors.kleinBlue.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.lg)
                                .stroke(PTDesignTokens.Colors.kleinBlue.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            
            // Description (if available)
            if let description = talk.description, !description.isEmpty {
                VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.sm) {
                    Text("About This Talk")
                        .font(PTFont.ptSectionTitle)
                        .foregroundColor(PTDesignTokens.Colors.ink)
                    
                    Text(description)
                        .font(PTFont.ptBodyText)
                        .foregroundColor(PTDesignTokens.Colors.ink)
                        .lineSpacing(PTDesignTokens.Typography.lineHeightRelaxed)
                        .lineLimit(nil)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(PTDesignTokens.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.xl)
                        .fill(PTDesignTokens.Colors.surface)
                        .shadow(color: PTDesignTokens.Colors.ink.opacity(0.1), radius: 8, x: 0, y: 4)
                )
            }
        }
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: PTDesignTokens.Spacing.md) {
            // Primary action - Transcript
            Button(action: { showingTranscript = true }) {
                HStack(spacing: PTDesignTokens.Spacing.md) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Transcript")
                            .font(PTFont.ptButtonText)
                            .foregroundColor(.white)
                        Text("Read the full text of this talk")
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(PTDesignTokens.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.xl)
                        .fill(PTDesignTokens.Colors.kleinBlue)
                        .shadow(color: PTDesignTokens.Colors.kleinBlue.opacity(0.3), radius: 8, x: 0, y: 4)
                )
            }
            
            // Secondary action - Bible Passage
            if let biblePassage = talk.biblePassage {
                Button(action: { showingBiblePassage = true }) {
                    HStack(spacing: PTDesignTokens.Spacing.md) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 20))
                            .foregroundColor(PTDesignTokens.Colors.ink)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bible Passage")
                                .font(PTFont.ptButtonText)
                                .foregroundColor(PTDesignTokens.Colors.ink)
                            Text(biblePassage)
                                .font(PTFont.ptCaptionText)
                                .foregroundColor(PTDesignTokens.Colors.kleinBlue)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(PTDesignTokens.Colors.medium)
                    }
                    .padding(PTDesignTokens.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.xl)
                            .fill(PTDesignTokens.Colors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.xl)
                                    .stroke(PTDesignTokens.Colors.light.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: PTDesignTokens.Colors.ink.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                }
            }
        }
    }
    
    // MARK: - Transcript Sheet
    
    private var transcriptSheet: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: PTDesignTokens.Spacing.lg) {
                    if let transcript = currentTranscript {
                        // Show completed transcript with segments
                        transcriptDisplayView(segments: transcript.segments, isCompleted: true)
                    } else if let streaming = streamingTranscript {
                        // Show streaming transcript with real-time updates
                        VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.md) {
                            // Progress indicator
                            HStack {
                                Text("Transcribing...")
                                    .font(PTFont.ptCaptionText)
                                    .foregroundColor(PTDesignTokens.Colors.medium)
                                
                                Spacer()
                                
                                Text("\(Int(streaming.progress * 100))%")
                                    .font(PTFont.ptCaptionText)
                                    .foregroundColor(PTDesignTokens.Colors.medium)
                            }
                            
                            ProgressView(value: streaming.progress)
                                .progressViewStyle(LinearProgressViewStyle(tint: PTDesignTokens.Colors.tang))
                            
                            // Live transcript content
                            transcriptDisplayView(segments: streaming.segments, isCompleted: false)
                        }
                        .padding(.horizontal, PTDesignTokens.Spacing.lg)
                    } else if transcriptionService.transcriptionQueue.contains(where: { $0.talkID == talk.id }) {
                        // Transcription in progress
                        VStack(spacing: PTDesignTokens.Spacing.lg) {
                            PTLogo(size: 64, showText: false)
                                .opacity(0.6)
                            
                            VStack(spacing: PTDesignTokens.Spacing.sm) {
                                Text("Generating Transcript")
                                    .font(PTFont.ptSectionTitle)
                                    .foregroundColor(PTDesignTokens.Colors.ink)
                                
                                Text("This may take a few minutes")
                                    .font(PTFont.ptBodyText)
                                    .foregroundColor(PTDesignTokens.Colors.medium)
                            }
                            
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(PTDesignTokens.Colors.tang)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(PTDesignTokens.Spacing.xl)
                    } else {
                        // Request transcription or show existing
                        VStack(spacing: PTDesignTokens.Spacing.lg) {
                            Image(systemName: "text.bubble")
                                .font(.system(size: 64))
                                .foregroundColor(PTDesignTokens.Colors.kleinBlue.opacity(0.6))
                            
                            VStack(spacing: PTDesignTokens.Spacing.sm) {
                                Text("No Transcript Available")
                                    .font(PTFont.ptSectionTitle)
                                    .foregroundColor(PTDesignTokens.Colors.ink)
                                
                                if isTalkDownloaded {
                                    Text("Generate a transcript from the downloaded audio file using secure on-device processing. Your audio never leaves your device.")
                                        .font(PTFont.ptBodyText)
                                        .foregroundColor(PTDesignTokens.Colors.medium)
                                        .multilineTextAlignment(.center)
                                        .lineSpacing(PTDesignTokens.Typography.lineHeightRelaxed)
                                } else {
                                    Text("Download this talk first to generate a transcript using secure on-device processing.")
                                        .font(PTFont.ptBodyText)
                                        .foregroundColor(PTDesignTokens.Colors.medium)
                                        .multilineTextAlignment(.center)
                                        .lineSpacing(PTDesignTokens.Typography.lineHeightRelaxed)
                                }
                            }
                            
                            Button(action: {
                                requestTranscription()
                                showingTranscript = false
                            }) {
                                HStack {
                                    Image(systemName: isTalkDownloaded ? "waveform.badge.checkmark" : "arrow.down.circle")
                                    Text(isTalkDownloaded ? "Generate Transcript" : "Download Talk First")
                                }
                                .font(PTFont.ptButtonText)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, PTDesignTokens.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                                        .fill(isTalkDownloaded ? PTDesignTokens.Colors.tang : PTDesignTokens.Colors.medium)
                                        .shadow(color: (isTalkDownloaded ? PTDesignTokens.Colors.tang : PTDesignTokens.Colors.medium).opacity(0.3), radius: 8, x: 0, y: 4)
                                )
                            }
                            .disabled(!isTalkDownloaded)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(PTDesignTokens.Spacing.xl)
                    }
                    
                    // Search Drawer
                    if showingTranscriptSearch {
                        transcriptSearchDrawer
                    }
                }
                .navigationTitle("Transcript")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            showingTranscriptSearch.toggle()
                        }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 18))
                                .foregroundColor(PTDesignTokens.Colors.kleinBlue)
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingTranscript = false
                            showingTranscriptSearch = false
                            transcriptSearchText = ""
                            searchResults = []
                        }
                        .font(PTFont.ptButtonText)
                        .foregroundColor(PTDesignTokens.Colors.tang)
                    }
                }
            }
        }
    }
    
    // MARK: - Transcript Search Drawer
    
    @ViewBuilder
    private var transcriptSearchDrawer: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: PTDesignTokens.Spacing.md) {
                // Search Header
                HStack {
                    Text("Search Transcript")
                        .font(PTFont.ptSectionTitle)
                        .foregroundColor(PTDesignTokens.Colors.ink)
                    
                    Spacer()
                    
                    Button(action: {
                        showingTranscriptSearch = false
                        transcriptSearchText = ""
                        searchResults = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(PTDesignTokens.Colors.medium)
                    }
                }
                
                // Search Field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(PTDesignTokens.Colors.medium)
                    
                    TextField("Search in transcript...", text: $transcriptSearchText)
                        .font(PTFont.ptBodyText)
                        .foregroundColor(PTDesignTokens.Colors.ink)
                        .onChange(of: transcriptSearchText) { newValue in
                            performSearch(query: newValue)
                        }
                    
                    if !transcriptSearchText.isEmpty {
                        Button(action: {
                            transcriptSearchText = ""
                            searchResults = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(PTDesignTokens.Colors.medium)
                        }
                    }
                }
                .padding(PTDesignTokens.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.lg)
                        .fill(PTDesignTokens.Colors.veryLight)
                )
                
                // Search Results
                if !searchResults.isEmpty {
                    VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.xs) {
                        Text("\(searchResults.count) result\(searchResults.count == 1 ? "" : "s")")
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(PTDesignTokens.Colors.medium)
                        
                        ScrollView {
                            LazyVStack(spacing: PTDesignTokens.Spacing.xs) {
                                ForEach(Array(searchResults.enumerated()), id: \.offset) { index, segment in
                                    searchResultRow(segment: segment, index: index)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                } else if !transcriptSearchText.isEmpty {
                    Text("No results found")
                        .font(PTFont.ptBodyText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                        .padding(.vertical, PTDesignTokens.Spacing.md)
                }
            }
            .padding(PTDesignTokens.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.xl)
                    .fill(PTDesignTokens.Colors.surface)
                    .shadow(color: PTDesignTokens.Colors.ink.opacity(0.15), radius: 20, x: 0, y: -5)
            )
            .padding(.horizontal, PTDesignTokens.Spacing.md)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .background(
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    showingTranscriptSearch = false
                }
        )
    }
    
    @ViewBuilder
    private func searchResultRow(segment: TranscriptSegment, index: Int) -> some View {
        Button(action: {
            showingTranscriptSearch = false
            
            // Start playback at this segment if not already playing
            if selectedMediaType == .audio {
                if playerService.currentTalk?.id != talk.id {
                    playerService.loadTalk(talk)
                }
                if !playerService.isPlaying {
                    playerService.play()
                }
                playerService.seek(to: segment.startTime)
            }
        }) {
            VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.xs) {
                HStack {
                    Text(timeString(from: segment.startTime))
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(PTDesignTokens.Colors.kleinBlue)
                        .monospacedDigit()
                    
                    Spacer()
                }
                
                Text(cleanTranscriptText(segment.text))
                    .font(PTFont.ptBodyText)
                    .foregroundColor(PTDesignTokens.Colors.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(PTDesignTokens.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.lg)
                    .fill(PTDesignTokens.Colors.kleinBlue.opacity(0.05))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Bible Passage Sheet
    
    private var biblePassageSheet: some View {
        NavigationStack {
            Group {
                if biblePassageState.isLoading {
                        // Loading state
                        VStack(spacing: PTDesignTokens.Spacing.lg) {
                            PTLogo(size: 64, showText: false)
                                .opacity(0.6)
                            
                            VStack(spacing: PTDesignTokens.Spacing.sm) {
                                Text("Loading Bible Passage")
                                    .font(PTFont.ptSectionTitle)
                                    .foregroundColor(PTDesignTokens.Colors.ink)
                                
                                Text("Fetching the text from ESV API")
                                    .font(PTFont.ptBodyText)
                                    .foregroundColor(PTDesignTokens.Colors.medium)
                            }
                            
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(PTDesignTokens.Colors.kleinBlue)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(PTDesignTokens.Colors.background)
                        
                    } else if let error = biblePassageState.error {
                        // Error state
                        VStack(spacing: PTDesignTokens.Spacing.lg) {
                            Image(systemName: "wifi.exclamationmark")
                                .font(.system(size: 64))
                                .foregroundColor(PTDesignTokens.Colors.turmeric)
                            
                            VStack(spacing: PTDesignTokens.Spacing.sm) {
                                Text("Unable to Load Passage")
                                    .font(PTFont.ptSectionTitle)
                                    .foregroundColor(PTDesignTokens.Colors.ink)
                                
                                Text(error)
                                    .font(PTFont.ptBodyText)
                                    .foregroundColor(PTDesignTokens.Colors.medium)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(PTDesignTokens.Typography.lineHeightRelaxed)
                            }
                            
                            Button(action: loadBiblePassage) {
                                Text("Try Again")
                                    .font(PTFont.ptButtonText)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, PTDesignTokens.Spacing.md)
                                    .background(
                                        RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                                            .fill(PTDesignTokens.Colors.tang)
                                            .shadow(color: PTDesignTokens.Colors.tang.opacity(0.3), radius: 8, x: 0, y: 4)
                                    )
                            }
                            .padding(.horizontal, PTDesignTokens.Spacing.xl)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(PTDesignTokens.Colors.background)
                        
                    } else if let passage = biblePassageState.biblePassage {
                        // Bible passage content - full screen
                        VStack(spacing: 0) {
                            // Header with passage reference
                            VStack(spacing: PTDesignTokens.Spacing.sm) {
                                Text(passage.reference)
                                    .font(PTFont.ptDisplayMedium)
                                    .foregroundColor(PTDesignTokens.Colors.ink)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                            }
                            .padding(.horizontal, PTDesignTokens.Spacing.lg)
                            .padding(.vertical, PTDesignTokens.Spacing.md)
                            .background(PTDesignTokens.Colors.surface)
                            
                            // Bible passage content - takes remaining space
                            ForEach(passage.passages, id: \.self) { htmlContent in
                                ESVHTMLView(htmlContent: htmlContent)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            
                            // Footer with copyright
                            if let copyright = passage.copyright {
                                VStack {
                                    Divider()
                                    Text(copyright)
                                        .font(PTFont.ptCaptionText)
                                        .foregroundColor(PTDesignTokens.Colors.medium)
                                        .multilineTextAlignment(.center)
                                        .padding(.vertical, PTDesignTokens.Spacing.sm)
                                }
                                .background(PTDesignTokens.Colors.surface)
                                .padding(.horizontal, PTDesignTokens.Spacing.lg)
                            }
                        }
                        
                    } else {
                        // No passage available
                        VStack(spacing: PTDesignTokens.Spacing.lg) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 64))
                                .foregroundColor(PTDesignTokens.Colors.medium)
                            
                            VStack(spacing: PTDesignTokens.Spacing.sm) {
                                Text("No Bible Passage")
                                    .font(PTFont.ptSectionTitle)
                                    .foregroundColor(PTDesignTokens.Colors.ink)
                                
                                Text("This talk doesn't reference a specific Bible passage")
                                    .font(PTFont.ptBodyText)
                                    .foregroundColor(PTDesignTokens.Colors.medium)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(PTDesignTokens.Typography.lineHeightRelaxed)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(PTDesignTokens.Colors.background)
                    }
                }
                .navigationTitle("Bible Passage")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingBiblePassage = false
                        }
                        .font(PTFont.ptButtonText)
                        .foregroundColor(PTDesignTokens.Colors.tang)
                    }
                }
            }
        }
        
        // MARK: - Helper Methods
        
        private func togglePlayback() {
            switch selectedMediaType {
            case .audio:
                // Handle audio playback
                if playerService.currentTalk?.id == talk.id {
                    if playerService.isPlaying {
                        playerService.pause()
                    } else {
                        playerService.play()
                    }
                } else {
                    playerService.loadTalk(talk)
                    playerService.play()
                }
                
            case .video:
                // Handle video playback
                guard let url = talk.processedVideoURL else {
                    // Show error or fallback to audio
                    print("Video URL not available")
                    return
                }
                
                // For Vimeo videos, always try WebView first to avoid domain restriction issues
                if let videoID = talk.videoURL, videoID.allSatisfy({ $0.isNumber }) {
                    // Use WebView directly for Vimeo videos to avoid domain restriction issues
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first,
                       let rootViewController = window.rootViewController {
                        VideoPlayerManager.shared.presentVideoWithWebViewFallback(for: videoID, title: talk.title, from: rootViewController)
                    }
                } else {
                    // For non-Vimeo videos, try AVPlayer first
                    Task {
                        let isAccessible = await VideoPlayerManager.shared.isVideoAccessible(url)
                        
                        await MainActor.run {
                            if isAccessible {
                                // Present video player with AVPlayer
                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let window = windowScene.windows.first,
                                   let rootViewController = window.rootViewController {
                                    VideoPlayerManager.shared.presentVideoPlayer(for: url, title: talk.title, from: rootViewController)
                                }
                            } else {
                                // Show error message and fallback to audio
                                videoError = "This video is not publicly accessible. Switching to audio mode."
                                showingVideoError = true
                                selectedMediaType = .audio
                            }
                        }
                    }
                }
            }
        }
        
        private func toggleDownload() {
            Task {
                if isTalkDownloaded {
                    // Delete downloaded talk
                    do {
                        try await downloadService.deleteDownload(for: talk.id)
                        await MainActor.run {
                            isTalkDownloaded = false
                        }
                    } catch {
                        print("Failed to delete download: \(error)")
                    }
                } else if downloadService.activeDownloads.contains(where: { $0.talkID == talk.id }) {
                    // Cancel download
                    await downloadService.cancelDownload(for: talk.id)
                } else {
                    // Start download
                    isDownloading = true
                    do {
                        try await downloadService.downloadTalk(talk)
                        await MainActor.run {
                            isTalkDownloaded = true
                        }
                    } catch {
                        print("Download failed: \(error)")
                    }
                    isDownloading = false
                }
            }
        }
        
        private func checkDownloadStatus() {
            Task {
                let downloaded = await downloadService.isDownloaded(talk.id)
                await MainActor.run {
                    isTalkDownloaded = downloaded
                }
            }
        }
        
        private func requestTranscription() {
            Task {
                do {
                    // Check if talk is downloaded first
                    guard isTalkDownloaded else {
                        print("Cannot transcribe: talk not downloaded")
                        return
                    }
                    
                    print("Starting local transcription using on-device processing...")
                    try await transcriptionService.requestTranscription(for: talk)
                    
                    // The UI will automatically refresh via the notification listener
                } catch TranscriptionError.audioFileNotFound {
                    print("Audio file not found - transcript requires downloaded audio")
                } catch {
                    print("Local transcription failed: \(error)")
                }
            }
        }
        
        private func loadTranscript() {
            Task {
                do {
                    currentTranscript = try await transcriptionService.getTranscript(for: talk.id)
                } catch {
                    print("Failed to load transcript: \(error)")
                    currentTranscript = nil
                }
            }
        }
        
        private func loadBiblePassage() {
            guard let biblePassageRef = talk.biblePassage else {
                return
            }
            
            biblePassageState.isLoading = true
            biblePassageState.error = nil
            biblePassageState.biblePassage = nil
            
            Task {
                do {
                    let passage = try await esvService.fetchPassage(reference: biblePassageRef)
                    DispatchQueue.main.async {
                        self.biblePassageState.biblePassage = passage
                        self.biblePassageState.isLoading = false
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.biblePassageState.error = error.localizedDescription
                        self.biblePassageState.isLoading = false
                    }
                }
            }
        }
        
        private func shareTalk() {
            let shareText = "Check out this talk: \(talk.title) by \(talk.speaker)"
            let activityVC = UIActivityViewController(activityItems: [shareText, talk.shareURL], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(activityVC, animated: true)
            }
        }
        
        private func setInitialMediaType() {
            // Set initial media type based on availability, preferring audio
            if talk.hasAudio {
                selectedMediaType = .audio
            } else if talk.hasVideo {
                selectedMediaType = .video
            }
        }
        
        private func timeString(from timeInterval: TimeInterval) -> String {
            let minutes = Int(timeInterval) / 60
            let seconds = Int(timeInterval) % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
        
        
        private func cleanTranscriptText(_ text: String) -> String {
            var cleanedText = text
            
            // Remove WhisperKit time tags and control markers
            cleanedText = cleanedText.replacingOccurrences(of: #"<\|[^|]*\|>"#, with: "", options: .regularExpression)
            
            // Remove any remaining angle bracket tags
            cleanedText = cleanedText.replacingOccurrences(of: #"<[^>]*>"#, with: "", options: .regularExpression)
            
            // Clean up multiple spaces and trim
            cleanedText = cleanedText.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            return cleanedText
        }
        
        private func performSearch(query: String) {
            guard !query.isEmpty else {
                searchResults = []
                return
            }
            
            let segments = currentTranscript?.segments ?? streamingTranscript?.segments ?? []
            
            searchResults = segments.filter { segment in
                let cleanedText = cleanTranscriptText(segment.text)
                return cleanedText.localizedCaseInsensitiveContains(query)
            }
        }
        
        @ViewBuilder
        private func transcriptDisplayView(segments: [TranscriptSegment], isCompleted: Bool) -> some View {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: PTDesignTokens.Spacing.md) {
                        ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                            transcriptSegmentView(segment: segment, index: index)
                        }
                        
                        // Show "Transcribing..." indicator for streaming transcripts
                        if !isCompleted {
                            transcriptProgressView
                        }
                    }
                    .padding(PTDesignTokens.Spacing.lg)
                }
                .onChange(of: playerService.currentTime) { newTime in
                    if selectedMediaType == .audio && playerService.isPlaying {
                        if let activeSegmentIndex = segments.firstIndex(where: {
                            newTime >= $0.startTime && newTime <= $0.endTime
                        }) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo("segment-\(activeSegmentIndex)", anchor: .center)
                            }
                        }
                    }
                }
                .onChange(of: segments.count) { _ in
                    // Auto-scroll to bottom for new segments in streaming mode
                    if !isCompleted && !segments.isEmpty {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("segment-\(segments.count - 1)", anchor: .bottom)
                        }
                    }
                }
            }
        }
        
        @ViewBuilder
        private func transcriptSegmentView(segment: TranscriptSegment, index: Int) -> some View {
            let isActive = selectedMediaType == .audio &&
            playerService.currentTime >= segment.startTime &&
            playerService.currentTime <= segment.endTime
            
            Button(action: {
                if selectedMediaType == .audio {
                    // Load talk if not already loaded
                    if playerService.currentTalk?.id != talk.id {
                        playerService.loadTalk(talk)
                    }
                    
                    // Start playing if not already playing
                    if !playerService.isPlaying {
                        playerService.play()
                    }
                    
                    // Seek to the segment's timestamp
                    playerService.seek(to: segment.startTime)
                }
            }) {
                transcriptSegmentContent(segment: segment, isActive: isActive)
            }
            .buttonStyle(PlainButtonStyle())
            .id("segment-\(index)")
        }
        
        @ViewBuilder
        private func transcriptSegmentContent(segment: TranscriptSegment, isActive: Bool) -> some View {
            HStack(alignment: .top, spacing: PTDesignTokens.Spacing.md) {
                // Timestamp
                Text(timeString(from: segment.startTime))
                    .font(PTFont.ptCaptionText)
                    .foregroundColor(isActive ? PTDesignTokens.Colors.tang : PTDesignTokens.Colors.medium)
                    .monospacedDigit()
                    .frame(width: 60, alignment: .leading)
                
                // Text content
                Text(cleanTranscriptText(segment.text))
                    .font(PTFont.ptBodyText)
                    .foregroundColor(isActive ? PTDesignTokens.Colors.ink : PTDesignTokens.Colors.dark)
                    .lineSpacing(PTDesignTokens.Typography.lineHeightRelaxed)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, PTDesignTokens.Spacing.sm)
            .padding(.horizontal, PTDesignTokens.Spacing.md)
            .background(transcriptSegmentBackground(isActive: isActive))
            .overlay(transcriptSegmentOverlay(isActive: isActive))
        }
        
        @ViewBuilder
        private func transcriptSegmentBackground(isActive: Bool) -> some View {
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.sm)
                .fill(isActive ? PTDesignTokens.Colors.tang.opacity(0.1) : Color.clear)
        }
        
        @ViewBuilder
        private func transcriptSegmentOverlay(isActive: Bool) -> some View {
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.sm)
                .stroke(isActive ? PTDesignTokens.Colors.tang : Color.clear, lineWidth: 1)
        }
        
        @ViewBuilder
        private var transcriptProgressView: some View {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Transcribing more...")
                    .font(PTFont.ptCaptionText)
                    .foregroundColor(PTDesignTokens.Colors.medium)
            }
            .padding(.vertical, PTDesignTokens.Spacing.md)
        }
        
    }
    
    
    // MARK: - Progress View Style
    
    // MARK: - Extensions
    
    extension View {
        func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
            clipShape(RoundedCorner(radius: radius, corners: corners))
        }
    }
    
    struct RoundedCorner: Shape {
        var radius: CGFloat = .infinity
        var corners: UIRectCorner = .allCorners
        
        func path(in rect: CGRect) -> Path {
            let path = UIBezierPath(
                roundedRect: rect,
                byRoundingCorners: corners,
                cornerRadii: CGSize(width: radius, height: radius)
            )
            return Path(path.cgPath)
        }
    }
    
    
    // MARK: - Progress View Style
    
    struct PTMediaProgressStyle: ProgressViewStyle {
        func makeBody(configuration: Configuration) -> some View {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(PTDesignTokens.Colors.light.opacity(0.3))
                        .frame(height: 6)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [PTDesignTokens.Colors.tang, PTDesignTokens.Colors.tang.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: max(0, min(geometry.size.width * CGFloat(configuration.fractionCompleted ?? 0), geometry.size.width)),
                            height: 6
                        )
                        .animation(.easeInOut(duration: 0.2), value: configuration.fractionCompleted)
                }
            }
            .frame(height: 6)
        }
    }
    
    // MARK: - Bible Passage State
    
    class BiblePassageState: ObservableObject {
        @Published var biblePassage: ESVPassage?
        @Published var isLoading = false
        @Published var error: String?
        
        func reset() {
            biblePassage = nil
            isLoading = false
            error = nil
        }
    }
    
    // MARK: - ESV HTML View
    
    struct ESVHTMLView: UIViewRepresentable {
        let htmlContent: String
        
        func makeUIView(context: Context) -> WKWebView {
            let configuration = WKWebViewConfiguration()
            let webView = WKWebView(frame: .zero, configuration: configuration)
            webView.navigationDelegate = context.coordinator
            webView.isOpaque = false
            webView.backgroundColor = UIColor.clear
            webView.scrollView.backgroundColor = UIColor.clear
            return webView
        }
        
        func updateUIView(_ webView: WKWebView, context: Context) {
            let styledHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <link rel="stylesheet" href="https://use.typekit.net/jdz3hnc.css">
            <style>
                body {
                    font-family: 'optima', 'Optima', -apple-system, BlinkMacSystemFont, system-ui;
                    font-size: 18px;
                    line-height: 1.7;
                    color: #07324c;
                    margin: 0;
                    padding: 20px;
                    background-color: transparent;
                    font-weight: 400;
                }
                
                /* Verse numbers */
                .verse-num, sup {
                    font-family: 'optima', 'Optima', system-ui;
                    color: #4060ab;
                    font-size: 14px;
                    font-weight: 500;
                    margin-right: 4px;
                    vertical-align: super;
                    line-height: 1;
                }
                
                /* Paragraphs */
                p {
                    margin: 0 0 16px 0;
                    text-align: left;
                    font-family: 'optima', 'Optima', system-ui;
                    color: #07324c;
                }
                
                /* Headings */
                h1, h2, h3, h4, h5, h6 {
                    font-family: 'optima', 'Optima', system-ui;
                    font-weight: 500;
                    color: #07324c;
                    margin: 24px 0 16px 0;
                }
                
                h2 {
                    font-size: 20px;
                    font-weight: 500;
                    color: #4060ab;
                    text-align: center;
                    margin: 0 0 20px 0;
                }
                
                /* Links */
                a {
                    color: #4060ab;
                    text-decoration: none;
                }
                
                a:hover {
                    color: #ff4c23;
                }
                
                /* ESV specific classes - hide audio links and extra content */
                .extra_text {
                    display: none;
                }
                
                .audio {
                    display: none;
                }
                
                .mp3link {
                    display: none;
                }
                
                small {
                    display: none;
                }
                
                /* Copyright */
                .copyright {
                    font-family: 'optima', 'Optima', system-ui;
                    font-size: 12px;
                    color: #717580;
                    margin-top: 24px;
                    font-style: italic;
                    text-align: center;
                }
                
                /* Improve readability */
                strong, b {
                    font-weight: 600;
                    color: #07324c;
                }
                
                em, i {
                    font-style: italic;
                    color: #717580;
                }
                
                /* Chapter and section headings */
                .chapter-heading {
                    color: #ff4c23;
                    font-weight: 600;
                    text-align: center;
                    margin: 20px 0;
                }
            </style>
        </head>
        <body>
            \(htmlContent)
        </body>
        </html>
        """
            
            webView.loadHTMLString(styledHTML, baseURL: nil)
        }
        
        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }
        
        class Coordinator: NSObject, WKNavigationDelegate {
            var parent: ESVHTMLView
            
            init(_ parent: ESVHTMLView) {
                self.parent = parent
            }
            
            func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
                // Prevent navigation - we only want to display content
                if navigationAction.navigationType == .linkActivated {
                    decisionHandler(.cancel)
                } else {
                    decisionHandler(.allow)
                }
            }
        }
    }
    
    // MARK: - Preview
    
    struct TalkDetailView_Previews: PreviewProvider {
        static var previews: some View {
            TalkDetailView(
                talk: Talk.mockTalks[0],
                downloadService: DownloadService(apiService: TalksAPIService())
            )
        }
    }
    
    // MARK: - String Extension for Search
    
    extension String {
        func ranges(of string: String, options: String.CompareOptions = []) -> [Range<String.Index>] {
            var ranges: [Range<String.Index>] = []
            var searchRange = self.startIndex..<self.endIndex
            
            while let foundRange = self.range(of: string, options: options, range: searchRange) {
                ranges.append(foundRange)
                searchRange = foundRange.upperBound..<self.endIndex
            }
            
            return ranges
    }
}
