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
        VStack(spacing: PTSpacing.lg) {
            // Error icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.ptSecondary)
                .symbolEffect(.pulse, isActive: true)

            // Error message
            VStack(spacing: PTSpacing.sm) {
                Text("Something went wrong")
                    .font(PTFont.ptSectionTitle)
                    .foregroundColor(.ptPrimary)

                Text(error.localizedDescription)
                    .font(PTFont.ptBodyText)
                    .foregroundColor(.ptDarkGray)
                    .multilineTextAlignment(.center)
                    .lineLimit(isExpanded ? nil : 3)
                    .onTapGesture {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    }
            }
            .padding(.horizontal, PTSpacing.lg)

            // Action buttons
            HStack(spacing: PTSpacing.md) {
                if let dismissAction = dismissAction {
                    Button(action: dismissAction) {
                        Text("Dismiss")
                            .ptSecondaryButton()
                    }
                }

                if let retryAction = retryAction {
                    Button(action: retryAction) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Try Again")
                        }
                        .ptPrimaryButton()
                    }
                }
            }
        }
        .padding(PTSpacing.xl)
        .background(Color.ptSurface)
        .cornerRadius(PTCornerRadius.large)
        .ptCardStyle()
        .padding(PTSpacing.lg)
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

