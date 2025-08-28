//
//  TalkDetailView.swift
//  PT Resources
//
//  Beautiful talk details view with PT design system
//

import SwiftUI

struct TalkDetailView: View {
    let talk: Talk
    @ObservedObject var playerService = PlayerService.shared
    @ObservedObject var downloadService: DownloadService
    @StateObject private var transcriptionService = TranscriptionService()
    @StateObject private var esvService = ESVService()
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingTranscript = false
    @State private var showingBiblePassage = false
    @State private var biblePassage: ESVPassage?
    @State private var isLoadingBiblePassage = false
    @State private var biblePassageError: String?
    @State private var isDownloading = false
    @State private var downloadProgress: Float = 0.0
    @State private var isTalkDownloaded = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero Section with Talk Art & Info
                    heroSection
                    
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
        }
        .sheet(isPresented: $showingTranscript) {
            transcriptSheet
        }
        .sheet(isPresented: $showingBiblePassage) {
            biblePassageSheet
        }
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        GeometryReader { geometry in
            ZStack {
                // Background image or default
                Group {
                    if let imageURL = talk.imageURL, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            defaultArtworkView
                        }
                    } else {
                        defaultArtworkView
                    }
                }
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
    
    
    
    
    // MARK: - Media Player Section
    
    private var mediaPlayerSection: some View {
        VStack(spacing: PTDesignTokens.Spacing.lg) {
            // Progress bar
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
            
            // Playback controls
            HStack(spacing: PTDesignTokens.Spacing.xxl) {
                // Skip backward (10s)
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
                
                // Play/Pause
                Button(action: togglePlayback) {
                    Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .padding(PTDesignTokens.Spacing.lg)
                        .background(
                            Circle()
                                .fill(PTDesignTokens.Colors.tang)
                                .shadow(color: PTDesignTokens.Colors.tang.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                }
                .scaleEffect(playerService.isPlaying ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: playerService.isPlaying)
                
                // Skip forward (30s)
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
            
            // Speed control
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
            VStack(spacing: PTDesignTokens.Spacing.lg) {
                if transcriptionService.transcriptionQueue.contains(where: { $0.talkID == talk.id }) {
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
                            
                            Text("Request a transcript to see the full text of this talk. This usually takes a few minutes to generate.")
                                .font(PTFont.ptBodyText)
                                .foregroundColor(PTDesignTokens.Colors.medium)
                                .multilineTextAlignment(.center)
                                .lineSpacing(PTDesignTokens.Typography.lineHeightRelaxed)
                        }
                        
                        Button(action: {
                            requestTranscription()
                            showingTranscript = false
                        }) {
                            Text("Request Transcript")
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
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(PTDesignTokens.Spacing.xl)
                }
            }
            .navigationTitle("Transcript")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingTranscript = false
                    }
                    .font(PTFont.ptButtonText)
                    .foregroundColor(PTDesignTokens.Colors.tang)
                }
            }
        }
    }
    
    // MARK: - Bible Passage Sheet
    
    private var biblePassageSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PTDesignTokens.Spacing.lg) {
                    if isLoadingBiblePassage {
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
                        .frame(maxWidth: .infinity)
                        .padding(PTDesignTokens.Spacing.xl)
                    } else if let error = biblePassageError {
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
                        }
                        .frame(maxWidth: .infinity)
                        .padding(PTDesignTokens.Spacing.xl)
                    } else if let passage = biblePassage {
                        // Bible passage content
                        VStack(alignment: .leading, spacing: PTDesignTokens.Spacing.lg) {
                            Text(passage.reference)
                                .font(PTFont.ptDisplayMedium)
                                .foregroundColor(PTDesignTokens.Colors.ink)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.bottom, PTDesignTokens.Spacing.md)
                            
                            ForEach(passage.passages, id: \.self) { text in
                                Text(text)
                                    .font(PTFont.ptBodyText)
                                    .foregroundColor(PTDesignTokens.Colors.ink)
                                    .lineSpacing(PTDesignTokens.Typography.lineHeightRelaxed)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, PTDesignTokens.Spacing.sm)
                            }
                            
                            if let copyright = passage.copyright {
                                Divider()
                                    .padding(.vertical, PTDesignTokens.Spacing.md)
                                
                                Text(copyright)
                                    .font(PTFont.ptCaptionText)
                                    .foregroundColor(PTDesignTokens.Colors.medium)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(PTDesignTokens.Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.xl)
                                .fill(PTDesignTokens.Colors.surface)
                                .shadow(color: PTDesignTokens.Colors.ink.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
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
                        .frame(maxWidth: .infinity)
                        .padding(PTDesignTokens.Spacing.xl)
                    }
                }
                .padding(PTDesignTokens.Spacing.md)
            }
            .navigationTitle("Bible Passage")
            .navigationBarTitleDisplayMode(.large)
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

// MARK: - Preview

struct TalkDetailView_Previews: PreviewProvider {
    static var previews: some View {
        TalkDetailView(
            talk: Talk.mockTalks[0],
            downloadService: DownloadService(apiService: TalksAPIService())
        )
    }
}