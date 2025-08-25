//
//  TalkDetailView.swift
//  PT Resources
//
//  Comprehensive talk details view with offline playback support
//

import SwiftUI

struct TalkDetailView: View {
    let talk: Talk
    @ObservedObject var playerService: PlayerService
    @ObservedObject var downloadService: DownloadService
    @StateObject private var transcriptionService = TranscriptionService()
    @StateObject private var esvService = ESVService()
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: TalkDetailTab = .overview
    @State private var showingTranscript = false
    @State private var showingBiblePassage = false
    @State private var biblePassage: ESVPassage?
    @State private var isLoadingBiblePassage = false
    @State private var biblePassageError: String?
    @State private var isDownloading = false
    @State private var downloadProgress: Float = 0.0
    @State private var isPressed = false
    @State private var isTalkDownloaded = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Tab selector
                tabSelector
                
                // Content based on selected tab
                TabView(selection: $selectedTab) {
                    overviewTab
                        .tag(TalkDetailTab.overview)
                    
                    transcriptTab
                        .tag(TalkDetailTab.transcript)
                    
                    biblePassageTab
                        .tag(TalkDetailTab.biblePassage)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadBiblePassage()
            checkDownloadStatus()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: PTDesignTokens.Spacing.lg) {
            // Navigation bar
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(PTDesignTokens.Colors.ink)
                }
                
                Spacer()
                
                // Download button
                downloadButton
                
                // Share button
                Button(action: shareTalk) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
                        .foregroundColor(PTDesignTokens.Colors.ink)
                }
            }
            .padding(.horizontal, PTDesignTokens.Spacing.md)
            
            // Talk artwork and basic info
            VStack(spacing: PTDesignTokens.Spacing.md) {
                // Artwork
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [PTDesignTokens.Colors.tang.opacity(0.1), PTDesignTokens.Colors.kleinBlue.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        PTLogo(size: 40, showText: false)
                    )
                    .frame(width: 200, height: 200)
                    .cornerRadius(PTDesignTokens.BorderRadius.lg)
                
                // Talk info
                VStack(spacing: PTDesignTokens.Spacing.sm) {
                    Text(talk.title)
                        .font(PTFont.ptSectionTitle)
                        .foregroundColor(PTDesignTokens.Colors.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                    
                    Text(talk.speaker)
                        .font(PTFont.ptCardTitle)
                        .foregroundColor(PTDesignTokens.Colors.tang)
                    
                    if let series = talk.series {
                        Text(series)
                            .font(PTFont.ptCardSubtitle)
                            .foregroundColor(PTDesignTokens.Colors.medium)
                    }
                    
                    HStack(spacing: PTDesignTokens.Spacing.md) {
                        if let biblePassage = talk.biblePassage {
                            Text(biblePassage)
                                .font(PTFont.ptCaptionText)
                                .foregroundColor(PTDesignTokens.Colors.kleinBlue)
                                .padding(.horizontal, PTDesignTokens.Spacing.sm)
                                .padding(.vertical, PTDesignTokens.Spacing.xs)
                                .background(
                                    Capsule()
                                        .fill(PTDesignTokens.Colors.kleinBlue.opacity(0.1))
                                )
                        }
                        
                        Text(talk.formattedDate)
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(PTDesignTokens.Colors.medium)
                        
                        Text(talk.formattedDuration)
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(PTDesignTokens.Colors.medium)
                    }
                }
            }
            .padding(.horizontal, PTDesignTokens.Spacing.lg)
        }
        .padding(.top, PTDesignTokens.Spacing.md)
    }
    
    // MARK: - Download Button
    
    private var downloadButton: some View {
        Group {
            if isDownloading {
                // Download progress
                VStack(spacing: 2) {
                    ProgressView(value: downloadProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: PTDesignTokens.Colors.tang))
                        .frame(width: 60, height: 4)
                    
                    Text("\(Int(downloadProgress * 100))%")
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                }
            } else {
                // Download/Delete button
                Button(action: toggleDownload) {
                    if isTalkDownloaded {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(PTDesignTokens.Colors.success)
                    } else {
                        Image(systemName: "arrow.down.circle")
                            .font(.title2)
                            .foregroundColor(PTDesignTokens.Colors.ink)
                    }
                }
            }
        }
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(TalkDetailTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: PTDesignTokens.Spacing.xs) {
                        Text(tab.displayName)
                            .font(PTFont.ptCardSubtitle)
                            .foregroundColor(selectedTab == tab ? PTDesignTokens.Colors.ink : PTDesignTokens.Colors.medium)
                        
                        Rectangle()
                            .fill(selectedTab == tab ? PTDesignTokens.Colors.tang : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, PTDesignTokens.Spacing.lg)
        .padding(.top, PTDesignTokens.Spacing.lg)
    }
    
    // MARK: - Overview Tab
    
    private var overviewTab: some View {
        ScrollView {
            VStack(spacing: PTDesignTokens.Spacing.lg) {
                // Media Player
                mediaPlayerSection
                
                // Description
                if let description = talk.description {
                    descriptionSection(description)
                }
                
                // Action buttons
                actionButtonsSection
            }
            .padding(PTDesignTokens.Spacing.lg)
        }
    }
    
    // MARK: - Media Player Section
    
    private var mediaPlayerSection: some View {
        VStack(spacing: PTDesignTokens.Spacing.md) {
            // Progress bar
            VStack(spacing: PTDesignTokens.Spacing.sm) {
                ProgressView(value: playerService.currentTime, total: playerService.duration)
                    .progressViewStyle(PTMediaProgressStyle())
                    .frame(height: 4)
                
                HStack {
                    Text(timeString(from: playerService.currentTime))
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                    
                    Spacer()
                    
                    Text(timeString(from: playerService.duration))
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                }
            }
            
            // Playback controls
            HStack(spacing: PTDesignTokens.Spacing.xl) {
                // Skip backward (10s)
                Button(action: { playerService.skipBackward() }) {
                    Image(systemName: "gobackward.10")
                        .font(.title2)
                        .foregroundColor(PTDesignTokens.Colors.ink)
                }
                
                // Play/Pause
                Button(action: togglePlayback) {
                    Image(systemName: playerService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(PTDesignTokens.Colors.tang)
                }
                
                // Skip forward (30s)
                Button(action: { playerService.skipForward() }) {
                    Image(systemName: "goforward.30")
                        .font(.title2)
                        .foregroundColor(PTDesignTokens.Colors.ink)
                }
            }
            
            // Speed control
            HStack {
                Text("Speed:")
                    .font(PTFont.ptCaptionText)
                    .foregroundColor(PTDesignTokens.Colors.medium)
                
                Spacer()
                
                Button(action: { playerService.adjustPlaybackSpeed() }) {
                    Text("\(playerService.playbackSpeed, specifier: "%.1f")x")
                        .font(PTFont.ptCaptionText)
                        .foregroundColor(PTDesignTokens.Colors.kleinBlue)
                        .padding(.horizontal, PTDesignTokens.Spacing.sm)
                        .padding(.vertical, PTDesignTokens.Spacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.sm)
                                .fill(PTDesignTokens.Colors.kleinBlue.opacity(0.1))
                        )
                }
            }
        }
        .padding(PTDesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.card)
                .fill(PTDesignTokens.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.card)
                        .stroke(PTDesignTokens.Colors.light.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
    
    // MARK: - Description Section
    
    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.sm) {
            Text("Description")
                .font(PTFont.ptCardTitle)
                .foregroundColor(PTDesignTokens.Colors.ink)
            
            Text(description)
                .font(PTFont.ptBodyText)
                .foregroundColor(PTDesignTokens.Colors.ink)
                .lineLimit(nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PTDesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.card)
                .fill(PTDesignTokens.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.card)
                        .stroke(PTDesignTokens.Colors.light.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: PTDesignTokens.Spacing.md) {
            // Transcription button
            Button(action: requestTranscription) {
                HStack {
                    Image(systemName: "text.bubble")
                        .font(.title3)
                    
                    Text("Get Transcript")
                        .font(PTFont.ptButtonText)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, PTDesignTokens.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                        .fill(PTDesignTokens.Colors.kleinBlue)
                )
            }
            
            // Bible passage button
            if let biblePassage = talk.biblePassage {
                Button(action: { showingBiblePassage = true }) {
                    HStack {
                        Image(systemName: "book")
                            .font(.title3)
                        
                        Text("View \(biblePassage)")
                            .font(PTFont.ptButtonText)
                    }
                    .foregroundColor(PTDesignTokens.Colors.kleinBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, PTDesignTokens.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                            .stroke(PTDesignTokens.Colors.kleinBlue, lineWidth: 1)
                    )
                }
            }
        }
    }
    
    // MARK: - Transcript Tab
    
    private var transcriptTab: some View {
        ScrollView {
            VStack(spacing: PTDesignTokens.Spacing.lg) {
                if transcriptionService.transcriptionQueue.contains(where: { $0.talkID == talk.id }) {
                    // Transcription in progress
                    VStack(spacing: PTDesignTokens.Spacing.md) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text("Generating transcript...")
                            .font(PTFont.ptCardTitle)
                            .foregroundColor(PTDesignTokens.Colors.ink)
                        
                        Text("This may take a few minutes")
                            .font(PTFont.ptCaptionText)
                            .foregroundColor(PTDesignTokens.Colors.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(PTDesignTokens.Spacing.xl)
                } else {
                    // Request transcription or show existing
                    VStack(spacing: PTDesignTokens.Spacing.md) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 48))
                            .foregroundColor(PTDesignTokens.Colors.medium)
                        
                        Text("No transcript available")
                            .font(PTFont.ptCardTitle)
                            .foregroundColor(PTDesignTokens.Colors.ink)
                        
                        Text("Request a transcript to see the full text of this talk")
                            .font(PTFont.ptBodyText)
                            .foregroundColor(PTDesignTokens.Colors.medium)
                            .multilineTextAlignment(.center)
                        
                        Button(action: requestTranscription) {
                            Text("Request Transcript")
                                .font(PTFont.ptButtonText)
                                .foregroundColor(.white)
                                .padding(.horizontal, PTDesignTokens.Spacing.lg)
                                .padding(.vertical, PTDesignTokens.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                                        .fill(PTDesignTokens.Colors.tang)
                                )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(PTDesignTokens.Spacing.xl)
                }
            }
            .padding(PTDesignTokens.Spacing.lg)
        }
    }
    
    // MARK: - Bible Passage Tab
    
    private var biblePassageTab: some View {
        ScrollView {
            VStack(spacing: PTDesignTokens.Spacing.lg) {
                if isLoadingBiblePassage {
                    // Loading state
                    VStack(spacing: PTDesignTokens.Spacing.md) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text("Loading Bible passage...")
                            .font(PTFont.ptCardTitle)
                            .foregroundColor(PTDesignTokens.Colors.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(PTDesignTokens.Spacing.xl)
                } else if let error = biblePassageError {
                    // Error state
                    VStack(spacing: PTDesignTokens.Spacing.md) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(PTDesignTokens.Colors.turmeric)
                        
                        Text("Unable to load passage")
                            .font(PTFont.ptCardTitle)
                            .foregroundColor(PTDesignTokens.Colors.ink)
                        
                        Text(error)
                            .font(PTFont.ptBodyText)
                            .foregroundColor(PTDesignTokens.Colors.medium)
                            .multilineTextAlignment(.center)
                        
                        Button(action: loadBiblePassage) {
                            Text("Try Again")
                                .font(PTFont.ptButtonText)
                                .foregroundColor(.white)
                                .padding(.horizontal, PTDesignTokens.Spacing.lg)
                                .padding(.vertical, PTDesignTokens.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                                        .fill(PTDesignTokens.Colors.tang)
                                )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(PTDesignTokens.Spacing.xl)
                } else if let passage = biblePassage {
                    // Bible passage content
                    VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.md) {
                        Text(passage.reference)
                            .font(PTFont.ptSectionTitle)
                            .foregroundColor(PTDesignTokens.Colors.ink)
                        
                        ForEach(passage.passages, id: \.self) { text in
                            Text(text)
                                .font(PTFont.ptBodyText)
                                .foregroundColor(PTDesignTokens.Colors.ink)
                                .lineSpacing(PTDesignTokens.Typography.lineHeightRelaxed)
                        }
                        
                        if let copyright = passage.copyright {
                            Text(copyright)
                                .font(PTFont.ptCaptionText)
                                .foregroundColor(PTDesignTokens.Colors.medium)
                                .padding(.top, PTDesignTokens.Spacing.md)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(PTDesignTokens.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.card)
                            .fill(PTDesignTokens.Colors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.card)
                                    .stroke(PTDesignTokens.Colors.light.opacity(0.2), lineWidth: 0.5)
                            )
                    )
                } else {
                    // No passage available
                    VStack(spacing: PTDesignTokens.Spacing.md) {
                        Image(systemName: "book")
                            .font(.system(size: 48))
                            .foregroundColor(PTDesignTokens.Colors.medium)
                        
                        Text("No Bible passage available")
                            .font(PTFont.ptCardTitle)
                            .foregroundColor(PTDesignTokens.Colors.ink)
                        
                        Text("This talk doesn't reference a specific Bible passage")
                            .font(PTFont.ptBodyText)
                            .foregroundColor(PTDesignTokens.Colors.medium)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(PTDesignTokens.Spacing.xl)
                }
            }
            .padding(PTDesignTokens.Spacing.lg)
        }
    }
    
    // MARK: - Helper Methods
    
    private func togglePlayback() {
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
                try await transcriptionService.requestTranscription(for: talk)
            } catch {
                print("Transcription request failed: \(error)")
            }
        }
    }
    
    private func loadBiblePassage() {
        guard let biblePassage = talk.biblePassage else { return }
        
        isLoadingBiblePassage = true
        biblePassageError = nil
        
        Task {
            do {
                let passage = try await esvService.fetchPassage(reference: biblePassage)
                await MainActor.run {
                    self.biblePassage = passage
                    self.isLoadingBiblePassage = false
                }
            } catch {
                await MainActor.run {
                    self.biblePassageError = error.localizedDescription
                    self.isLoadingBiblePassage = false
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
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Supporting Types

enum TalkDetailTab: CaseIterable {
    case overview
    case transcript
    case biblePassage
    
    var displayName: String {
        switch self {
        case .overview: return "Overview"
        case .transcript: return "Transcript"
        case .biblePassage: return "Bible Passage"
        }
    }
}

// MARK: - Progress View Style

struct PTMediaProgressStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        ZStack(alignment: .leading) {
            // Background
            RoundedRectangle(cornerRadius: 2)
                .fill(PTDesignTokens.Colors.light.opacity(0.3))
                .frame(height: 4)
            
            // Progress
            RoundedRectangle(cornerRadius: 2)
                .fill(PTDesignTokens.Colors.tang)
                .frame(
                    width: CGFloat(configuration.fractionCompleted ?? 0) * UIScreen.main.bounds.width * 0.8,
                    height: 4
                )
        }
    }
}

// MARK: - Preview

struct TalkDetailView_Previews: PreviewProvider {
    static var previews: some View {
        TalkDetailView(
            talk: Talk.mockTalks[0],
            playerService: PlayerService(),
            downloadService: DownloadService(apiService: TalksAPIService())
        )
    }
}