//
//  PrivacySettingsView.swift
//  PT Resources
//
//  Privacy and data management settings
//

import SwiftUI

struct PrivacySettingsView: View {
    var body: some View {
        NavigationStack {
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