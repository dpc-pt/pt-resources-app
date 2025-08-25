//
//  TalkDetailView.swift
//  PT Resources
//
//  Comprehensive talk details view with offline playback support
//

import SwiftUI

struct TalkDetailView: View {
    
    // MARK: - Properties
    
    let talk: Talk
    @ObservedObject var playerService: PlayerService
    @ObservedObject var downloadService: DownloadService
    
    @StateObject private var transcriptionService = TranscriptionService()
    @StateObject private var esvService = ESVService()
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: TalkDetailTab = .overview
    @State private var showingTranscription = false
    @State private var showingBiblePassage = false
    @State private var isDownloaded = false
    @State private var transcript: Transcript?
    @State private var biblePassage: ESVPassage?
    @State private var isLoadingTranscript = false
    @State private var isLoadingPassage = false
    @State private var showingSpeedMenu = false
    @State private var dragOffset: CGFloat = 0
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                backgroundView
                
                VStack(spacing: 0) {
                    // Header with artwork and basic info
                    headerSection
                    
                    // Tab selector
                    tabSelector
                    
                    // Content area
                    ScrollView {
                        VStack(spacing: PTSpacing.lg) {
                            switch selectedTab {
                            case .overview:
                                overviewContent
                            case .player:
                                playerContent
                            case .transcript:
                                transcriptContent  
                            case .passage:
                                passageContent
                            }
                        }
                        .padding(.horizontal, PTSpacing.screenPadding)
                        .padding(.bottom, 100) // Space for player controls
                    }
                    
                    Spacer()
                    
                    // Bottom player controls
                    bottomPlayerControls
                }
            }
        }
        .navigationBarHidden(true)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if dragOffset > 150 {
                        dismiss()
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .offset(y: dragOffset)
        .task {
            await loadTalkData()
        }
        .sheet(isPresented: $showingTranscription) {
            TranscriptionSheet(transcript: transcript, isLoading: isLoadingTranscript)
        }
        .sheet(isPresented: $showingBiblePassage) {
            BiblePassageSheet(passage: biblePassage, reference: talk.biblePassage, isLoading: isLoadingPassage)
        }
    }
    
    // MARK: - Background View
    
    private var backgroundView: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.ptNavy,
                        Color.ptRoyalBlue.opacity(0.8),
                        Color.ptBackground
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .ignoresSafeArea()
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: PTSpacing.md) {
            // Close and action buttons
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.down")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                }
                
                Spacer()
                
                Button(action: { 
                    // Share functionality
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                }
            }
            
            // Artwork
            AsyncImage(url: URL(string: talk.imageURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.ptCoral.opacity(0.3), Color.ptTurquoise.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Image(systemName: "waveform")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.7))
                    )
            }
            .frame(width: 200, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: PTSpacing.md))
            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
            
            // Talk info
            VStack(spacing: PTSpacing.xs) {
                Text(talk.title)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                
                Text(talk.speaker)
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
                
                if let series = talk.series {
                    Text(series)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, PTSpacing.sm)
                        .padding(.vertical, PTSpacing.xs)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                        )
                }
                
                HStack(spacing: PTSpacing.sm) {
                    Text(talk.formattedDate)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    if talk.duration > 0 {
                        Text("•")
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text(talk.formattedDuration)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
        }
        .padding(.horizontal, PTSpacing.screenPadding)
        .padding(.top, PTSpacing.md)
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(TalkDetailTab.allCases, id: \.self) { tab in
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: PTSpacing.xs) {
                        Text(tab.title)
                            .font(.subheadline.weight(selectedTab == tab ? .semibold : .medium))
                            .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.6))
                        
                        Rectangle()
                            .fill(selectedTab == tab ? Color.ptCoral : Color.clear)
                            .frame(height: 2)
                    }
                    .padding(.horizontal, PTSpacing.sm)
                }
            }
        }
        .padding(.horizontal, PTSpacing.screenPadding)
        .padding(.top, PTSpacing.md)
    }
    
    // MARK: - Overview Content
    
    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: PTSpacing.md) {
            if let description = talk.description, !description.isEmpty {
                VStack(alignment: .leading, spacing: PTSpacing.sm) {
                    Text("Description")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .lineSpacing(4)
                }
            }
            
            // Bible passage preview
            if let passage = talk.biblePassage {
                VStack(alignment: .leading, spacing: PTSpacing.sm) {
                    Text("Bible Passage")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Button(action: { 
                        selectedTab = .passage 
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(passage)
                                    .font(.title3.weight(.medium))
                                    .foregroundColor(.ptCoral)
                                
                                Text("Tap to read full passage")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: PTSpacing.sm)
                                .fill(Color.white.opacity(0.1))
                        )
                    }
                }
            }
            
            // Download section
            downloadSection
            
            // Transcription preview
            transcriptionPreviewSection
        }
    }
    
    // MARK: - Player Content
    
    private var playerContent: some View {
        VStack(spacing: PTSpacing.xl) {
            // Current playback info
            if playerService.currentTalk?.id == talk.id {
                VStack(spacing: PTSpacing.sm) {
                    Text("Now Playing")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    // Progress display
                    VStack(spacing: PTSpacing.sm) {
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 6)
                                
                                Rectangle()
                                    .fill(Color.ptCoral)
                                    .frame(
                                        width: geometry.size.width * CGFloat(playerService.duration > 0 ? playerService.currentTime / playerService.duration : 0),
                                        height: 6
                                    )
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                        .frame(height: 6)
                        
                        // Time labels
                        HStack {
                            Text(timeString(from: playerService.currentTime))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            
                            Spacer()
                            
                            Text(timeString(from: playerService.duration))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
            }
            
            // Playback speed control
            playbackSpeedSection
            
            // Chapter navigation (if available)
            if !playerService.chapters.isEmpty {
                chapterNavigationSection
            }
        }
    }
    
    // MARK: - Transcript Content
    
    private var transcriptContent: some View {
        VStack(alignment: .leading, spacing: PTSpacing.md) {
            HStack {
                Text("Transcription")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                if transcript == nil && !isLoadingTranscript {
                    Button("Generate") {
                        requestTranscription()
                    }
                    .foregroundColor(.ptCoral)
                }
            }
            
            if isLoadingTranscript {
                VStack(spacing: PTSpacing.sm) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.white)
                    
                    Text("Generating transcription...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, PTSpacing.xl)
            } else if let transcript = transcript {
                ScrollView {
                    VStack(alignment: .leading, spacing: PTSpacing.md) {
                        Text("Transcript")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text(transcript.text)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.9))
                            .lineSpacing(6)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: PTSpacing.sm)
                            .fill(Color.white.opacity(0.1))
                    )
                }
            } else {
                VStack(spacing: PTSpacing.sm) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("No transcription available")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("Tap 'Generate' to create a transcription using AI")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, PTSpacing.xl)
            }
        }
    }
    
    // MARK: - Bible Passage Content
    
    private var passageContent: some View {
        VStack(alignment: .leading, spacing: PTSpacing.md) {
            if let reference = talk.biblePassage {
                HStack {
                    Text("Bible Passage")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(reference)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.ptCoral)
                }
                
                if isLoadingPassage {
                    VStack(spacing: PTSpacing.sm) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.white)
                        
                        Text("Loading passage...")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, PTSpacing.xl)
                } else if let passage = biblePassage {
                    ScrollView {
                        VStack(alignment: .leading, spacing: PTSpacing.md) {
                            Text(passage.text)
                                .font(.body)
                                .foregroundColor(.white.opacity(0.9))
                                .lineSpacing(8)
                            
                            if let copyright = passage.copyright {
                                HStack {
                                    Spacer()
                                    Text(copyright)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: PTSpacing.sm)
                                .fill(Color.white.opacity(0.1))
                        )
                    }
                } else {
                    VStack(spacing: PTSpacing.sm) {
                        Image(systemName: "book")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text("Unable to load passage")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Button("Try Again") {
                            Task {
                                await loadBiblePassage()
                            }
                        }
                        .foregroundColor(.ptCoral)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, PTSpacing.xl)
                }
            } else {
                VStack(spacing: PTSpacing.sm) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("No Bible passage specified")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, PTSpacing.xl)
            }
        }
    }
    
    // MARK: - Download Section
    
    private var downloadSection: some View {
        VStack(alignment: .leading, spacing: PTSpacing.sm) {
            Text("Offline Download")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if isDownloaded {
                        Text("Downloaded")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.ptGreen)
                        Text("Available for offline playback")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    } else if let progress = downloadService.downloadProgress[talk.id] {
                        Text("Downloading...")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.ptCoral)
                        ProgressView(value: progress, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(width: 120)
                    } else {
                        Text("Download for offline listening")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        if let fileSize = talk.fileSize {
                            Text(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                
                Spacer()
                
                Button(action: {
                    if isDownloaded {
                        deleteDownload()
                    } else {
                        downloadTalk()
                    }
                }) {
                    Image(systemName: isDownloaded ? "trash" : "arrow.down.circle")
                        .font(.title2)
                        .foregroundColor(isDownloaded ? .red : .ptCoral)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: PTSpacing.sm)
                    .fill(Color.white.opacity(0.1))
            )
        }
    }
    
    // MARK: - Transcription Preview Section
    
    private var transcriptionPreviewSection: some View {
        VStack(alignment: .leading, spacing: PTSpacing.sm) {
            Text("Transcription")
                .font(.headline)
                .foregroundColor(.white)
            
            Button(action: { 
                selectedTab = .transcript 
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        if transcript != nil {
                            Text("Transcription available")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.ptGreen)
                            Text("Tap to read full transcript")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        } else {
                            Text("Generate AI transcription")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                            Text("Powered by Whisper AI")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: transcript != nil ? "doc.text.fill" : "doc.text")
                        .font(.title2)
                        .foregroundColor(transcript != nil ? .ptGreen : .white.opacity(0.5))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: PTSpacing.sm)
                        .fill(Color.white.opacity(0.1))
                )
            }
        }
    }
    
    // MARK: - Playback Speed Section
    
    private var playbackSpeedSection: some View {
        VStack(alignment: .leading, spacing: PTSpacing.sm) {
            Text("Playback Speed")
                .font(.headline)
                .foregroundColor(.white)
            
            let speeds: [Float] = [1.0, 1.25, 1.5, 2.0, 2.5, 3.0]
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: PTSpacing.sm) {
                ForEach(speeds, id: \.self) { speed in
                    Button(action: {
                        playerService.setPlaybackSpeed(speed)
                    }) {
                        Text("\(speed, specifier: "%.2g")x")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(playerService.playbackSpeed == speed ? .ptNavy : .white)
                            .frame(height: 40)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: PTSpacing.xs)
                                    .fill(playerService.playbackSpeed == speed ? Color.ptCoral : Color.white.opacity(0.1))
                            )
                    }
                }
            }
        }
    }
    
    // MARK: - Chapter Navigation Section
    
    private var chapterNavigationSection: some View {
        VStack(alignment: .leading, spacing: PTSpacing.sm) {
            Text("Chapters")
                .font(.headline)
                .foregroundColor(.white)
            
            LazyVStack(spacing: PTSpacing.xs) {
                ForEach(Array(playerService.chapters.enumerated()), id: \.element.id) { index, chapter in
                    Button(action: {
                        playerService.jumpToChapter(chapter)
                    }) {
                        HStack {
                            Text(chapter.title)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                            
                            Spacer()
                            
                            Text(chapter.formattedStartTime)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.vertical, PTSpacing.xs)
                        .padding(.horizontal, PTSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: PTSpacing.xs)
                                .fill(playerService.currentChapterIndex == index ? Color.white.opacity(0.2) : Color.clear)
                        )
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: PTSpacing.sm)
                    .fill(Color.white.opacity(0.1))
            )
        }
    }
    
    // MARK: - Bottom Player Controls
    
    private var bottomPlayerControls: some View {
        VStack(spacing: 0) {
            // Progress bar
            if playerService.currentTalk?.id == talk.id {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 2)
                        .overlay(
                            HStack {
                                Rectangle()
                                    .fill(Color.ptCoral)
                                    .frame(width: geometry.size.width * CGFloat(playerService.duration > 0 ? playerService.currentTime / playerService.duration : 0))
                                Spacer(minLength: 0)
                            }
                        )
                }
                .frame(height: 2)
            }
            
            // Control buttons
            HStack(spacing: PTSpacing.xl) {
                // Skip backward
                Button(action: { 
                    if playerService.currentTalk?.id != talk.id {
                        playerService.loadTalk(talk)
                    }
                    playerService.skipBackward() 
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "gobackward.10")
                            .font(.title2)
                            .foregroundColor(.white)
                        Text("10s")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                // Play/Pause
                Button(action: {
                    if playerService.currentTalk?.id == talk.id {
                        if playerService.playbackState.isPlaying {
                            playerService.pause()
                        } else {
                            playerService.play()
                        }
                    } else {
                        playerService.loadTalk(talk)
                        playerService.play()
                    }
                }) {
                    Image(systemName: (playerService.currentTalk?.id == talk.id && playerService.playbackState.isPlaying) ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                }
                
                // Skip forward
                Button(action: { 
                    if playerService.currentTalk?.id != talk.id {
                        playerService.loadTalk(talk)
                    }
                    playerService.skipForward() 
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "goforward.30")
                            .font(.title2)
                            .foregroundColor(.white)
                        Text("30s")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .padding(.vertical, PTSpacing.lg)
            .background(Color.black.opacity(0.3))
        }
    }
    
    // MARK: - Helper Methods
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func loadTalkData() async {
        await checkDownloadStatus()
        await loadTranscript()
        await loadBiblePassage()
    }
    
    private func checkDownloadStatus() async {
        isDownloaded = await downloadService.isDownloaded(talk.id)
    }
    
    private func loadTranscript() async {
        do {
            transcript = try await transcriptionService.getTranscript(for: talk.id)
        } catch {
            print("Failed to load transcript: \(error)")
        }
    }
    
    private func loadBiblePassage() async {
        guard let reference = talk.biblePassage, !reference.isEmpty else { return }
        
        isLoadingPassage = true
        do {
            biblePassage = try await esvService.fetchPassage(reference: reference)
        } catch {
            print("Failed to load Bible passage: \(error)")
        }
        isLoadingPassage = false
    }
    
    private func requestTranscription() {
        isLoadingTranscript = true
        Task {
            do {
                try await transcriptionService.requestTranscription(for: talk)
                // Poll for completion
                while transcript == nil && isLoadingTranscript {
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    transcript = try await transcriptionService.getTranscript(for: talk.id)
                    
                    if transcript != nil {
                        isLoadingTranscript = false
                        break
                    }
                }
            } catch {
                print("Failed to request transcription: \(error)")
                isLoadingTranscript = false
            }
        }
    }
    
    private func downloadTalk() {
        Task {
            do {
                try await downloadService.downloadTalk(talk)
                await checkDownloadStatus()
            } catch {
                print("Failed to download talk: \(error)")
            }
        }
    }
    
    private func deleteDownload() {
        Task {
            do {
                try await downloadService.deleteDownload(for: talk.id)
                await checkDownloadStatus()
            } catch {
                print("Failed to delete download: \(error)")
            }
        }
    }
}

// MARK: - Supporting Types

enum TalkDetailTab: CaseIterable {
    case overview
    case player
    case transcript
    case passage
    
    var title: String {
        switch self {
        case .overview: return "Overview"
        case .player: return "Player" 
        case .transcript: return "Transcript"
        case .passage: return "Passage"
        }
    }
}

// MARK: - Sheet Views

struct TranscriptionSheet: View {
    let transcript: Transcript?
    let isLoading: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            contentView
                .navigationTitle("Transcription")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PTSpacing.md) {
                if isLoading {
                    loadingView
                } else if let transcript = transcript {
                    transcriptView(transcript)
                } else {
                    emptyView
                }
            }
            .padding()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: PTSpacing.md) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Generating transcription...")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        Text("No transcription available")
            .font(.headline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func transcriptView(_ transcript: Transcript) -> some View {
        VStack(alignment: .leading, spacing: PTSpacing.lg) {
            ForEach(transcript.segments, id: \.id) { segment in
                segmentView(segment)
            }
        }
    }
    
    private func segmentView(_ segment: TranscriptSegment) -> some View {
        VStack(alignment: .leading, spacing: PTSpacing.xs) {
            HStack {
                Text(timeString(from: segment.startTime))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let confidence = segment.confidence, confidence > 0 {
                    Text("Confidence: \(Int(confidence * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(segment.text)
                .font(.body)
                .lineSpacing(4)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct BiblePassageSheet: View {
    let passage: ESVPassage?
    let reference: String?
    let isLoading: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: PTSpacing.md) {
                    if isLoading {
                        VStack(spacing: PTSpacing.md) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Loading passage...")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let passage = passage {
                        VStack(alignment: .leading, spacing: PTSpacing.lg) {
                            Text(passage.text)
                                .font(.body)
                                .lineSpacing(8)
                            
                            if let copyright = passage.copyright {
                                HStack {
                                    Spacer()
                                    Text(copyright)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } else {
                        VStack(spacing: PTSpacing.md) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            
                            Text("Unable to load passage")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding()
            }
            .navigationTitle(reference ?? "Bible Passage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

struct TalkDetailView_Previews: PreviewProvider {
    static var previews: some View {
        TalkDetailView(
            talk: Talk.mockTalks[0],
            playerService: PlayerService(),
            downloadService: DownloadService(apiService: MockTalksAPIService())
        )
    }
}