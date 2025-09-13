//
//  PrivacySettingsView.swift
//  PT Resources
//
//  Privacy and data management settings
//

import SwiftUI

struct PrivacySettingsView: View {
    @ObservedObject private var playerService = PlayerService.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: PTDesignTokens.Spacing.lg) {
                    PTLogo(size: 64, showText: false)
                    
                    Text("Privacy Settings")
                        .font(PTFont.ptSectionTitle)
                        .foregroundColor(PTDesignTokens.Colors.ink)
                    
                    Text("Privacy settings and data management features are coming soon.")
                        .font(PTFont.ptBodyText)
                        .foregroundColor(PTDesignTokens.Colors.medium)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, PTDesignTokens.Spacing.lg)
                    
                    Spacer()
                }
                .padding(PTDesignTokens.Spacing.xl)
                
                // Mini Player
                if playerService.currentTalk != nil {
                    VStack {
                        Spacer()
                        MiniPlayerView(playerService: playerService)
                            .transition(.move(edge: .bottom))
                            .background(PTDesignTokens.Colors.surface)
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: -4)
                    }
                }
            }
            .navigationTitle("Privacy & Data")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct PrivacySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        PrivacySettingsView()
    }
}