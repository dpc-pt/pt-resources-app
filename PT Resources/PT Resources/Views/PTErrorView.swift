//
//  PTErrorView.swift
//  PT Resources
//
//  Reusable error view with retry functionality
//

import SwiftUI

struct PTErrorView: View {
    let error: Error
    let retryAction: (() -> Void)?
    let dismissAction: (() -> Void)?

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: PTDesignTokens.Spacing.lg) {
            // Error icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(PTDesignTokens.Colors.tang)
                .symbolEffect(.pulse, isActive: true)

            // Error message
            VStack(spacing: PTDesignTokens.Spacing.sm) {
                Text("Something went wrong")
                    .font(PTFont.ptSectionTitle)
                    .foregroundColor(PTDesignTokens.Colors.ink)

                Text(error.localizedDescription)
                    .font(PTFont.ptBodyText)
                    .foregroundColor(PTDesignTokens.Colors.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(isExpanded ? nil : 3)
                    .onTapGesture {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    }
            }
            .padding(.horizontal, PTDesignTokens.Spacing.lg)

            // Action buttons
            HStack(spacing: PTDesignTokens.Spacing.md) {
                if let dismissAction = dismissAction {
                    Button("Dismiss", action: dismissAction)
                        .foregroundColor(PTDesignTokens.Colors.kleinBlue)
                        .padding()
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button)
                                .stroke(PTDesignTokens.Colors.kleinBlue, lineWidth: 1)
                        )
                }

                if let retryAction = retryAction {
                    Button(action: retryAction) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Try Again")
                        }
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(PTDesignTokens.Colors.tang)
                    .clipShape(RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.button))
                }
            }
        }
        .padding(PTDesignTokens.Spacing.xl)
        .background(PTDesignTokens.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.lg))
        // Card styling
        .padding(PTDesignTokens.Spacing.lg)
    }
}

// MARK: - Error Boundary View

struct PTErrorBoundary<Content: View>: View {
    let content: Content
    let fallback: (Error) -> AnyView

    @State private var currentError: Error?

    init(@ViewBuilder content: () -> Content, @ViewBuilder fallback: @escaping (Error) -> some View) {
        self.content = content()
        self.fallback = { AnyView(fallback($0)) }
    }

    var body: some View {
        Group {
            if let error = currentError {
                fallback(error)
            } else {
                content
                    .environment(\.errorHandler, ErrorHandler { error in
                        currentError = error
                    })
            }
        }
    }
}

// MARK: - Error Handler Environment

struct ErrorHandler {
    let handle: (Error) -> Void

    func callAsFunction(_ error: Error) {
        handle(error)
    }
}

private struct ErrorHandlerKey: EnvironmentKey {
    static let defaultValue = ErrorHandler { _ in }
}

extension EnvironmentValues {
    var errorHandler: ErrorHandler {
        get { self[ErrorHandlerKey.self] }
        set { self[ErrorHandlerKey.self] = newValue }
    }
}

// MARK: - Preview

struct PTErrorView_Previews: PreviewProvider {
    static var previews: some View {
        PTErrorView(
            error: APIError.networkError(NSError(domain: "Test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network connection failed"])),
            retryAction: { print("Retry tapped") },
            dismissAction: { print("Dismiss tapped") }
        )
        .preferredColorScheme(.light)
    }
}

