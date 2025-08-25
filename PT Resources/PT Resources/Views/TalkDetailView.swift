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
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: PTDesignTokens.Spacing.lg) {
                // Header with back button
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(PTDesignTokens.Colors.ink)
                    }
                    Spacer()
                }
                .padding(.horizontal, PTDesignTokens.Spacing.md)
                
                // Talk info
                VStack(spacing: PTDesignTokens.Spacing.md) {
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
                    
                    Text(talk.title)
                        .font(PTFont.ptSectionTitle)
                        .foregroundColor(PTDesignTokens.Colors.ink)
                        .multilineTextAlignment(.center)
                    
                    Text(talk.speaker)
                        .font(PTFont.ptCardTitle)
                        .foregroundColor(PTDesignTokens.Colors.tang)
                    
                    Text("Detailed view coming soon...")
                        .font(PTFont.ptBodyText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .padding(PTDesignTokens.Spacing.lg)
        }
        .navigationBarHidden(true)
    }
}

enum TalkDetailTab: CaseIterable {
    case overview
    case transcript
    case notes
}

struct TalkDetailView_Previews: PreviewProvider {
    static var previews: some View {
        TalkDetailView(
            talk: Talk.mockTalks[0],
            playerService: PlayerService(),
            downloadService: DownloadService(apiService: TalksAPIService())
        )
    }
}