//
//  PTFontDebugger.swift
//  PT Resources
//
//  Utility for debugging font loading and registration
//

import SwiftUI
import UIKit

class PTFontDebugger {
    static let shared = PTFontDebugger()
    
    private init() {}
    
    /// Debug font availability and print detailed information
    func debugFonts() {
        print("\n🔍 PT Font Debug Report")
        print("========================")
        
        // Check all expected PT fonts
        let ptFonts = [
            ("Agenda-One-Bold", "Agenda One Bold"),
            ("Agenda-One-Medium", "Agenda One Medium"),
            ("Fields-Display-Black", "Fields Display Black"),
            ("fields-display-medium", "Fields Display Medium"),
            ("OptimaLTPro-BlackItalic", "Optima LT Pro Black Italic"),
            ("OptimaLTPro-Bold", "Optima LT Pro Bold"),
            ("OptimaLTPro-BoldItalic", "Optima LT Pro Bold Italic"),
            ("OptimaLTPro-Italic", "Optima LT Pro Italic"),
            ("OptimaLTPro-Medium", "Optima LT Pro Medium"),
            ("OptimaLTPro-MediumItalic", "Optima LT Pro Medium Italic"),
            ("OptimaLTPro-Roman", "Optima LT Pro Roman")
        ]
        
    }
    
    /// Test font rendering with sample text
    func testFontRendering() -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Font Rendering Test")
                .font(.title)
                .padding(.bottom)
            
            Group {
                Text("Agenda One Bold")
                    .font(.custom("Agenda-One-Bold", size: 24))
                    .foregroundColor(.primary)
                
                Text("Agenda One Medium")
                    .font(.custom("Agenda-One-Medium", size: 20))
                    .foregroundColor(.primary)
                
                Text("Fields Display Black")
                    .font(.custom("Fields-Display-Black", size: 22))
                    .foregroundColor(.primary)
                
                Text("Fields Display Medium")
                    .font(.custom("fields-display-medium", size: 18))
                    .foregroundColor(.primary)
                
                Text("Optima LT Pro Roman")
                    .font(.custom("OptimaLTPro-Roman", size: 16))
                    .foregroundColor(.primary)
                
                Text("Optima LT Pro Bold")
                    .font(.custom("OptimaLTPro-Bold", size: 16))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - SwiftUI View Extension

extension View {
    func debugFonts() -> some View {
        self.onAppear {
            PTFontDebugger.shared.debugFonts()
        }
    }
}


