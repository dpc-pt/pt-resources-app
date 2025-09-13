//
//  ErrorCoordinator.swift
//  PT Resources
//
//  Centralized error handling coordinator for consistent error management across the app
//

import Foundation
import SwiftUI
import Combine

// MARK: - Error Severity

enum ErrorSeverity {
    case low        // Minor issues that don't prevent app usage
    case medium     // Issues that impact functionality but have workarounds
    case high       // Critical issues that prevent core functionality
    case critical   // App-breaking issues requiring immediate attention
}

// MARK: - Error Category

enum ErrorCategory {
    case network
    case api
    case storage
    case media
    case authentication
    case download
    case transcription
    case ui
    case system
}

// MARK: - Error Context

struct ErrorContext {
    let id = UUID()
    let timestamp = Date()
    let category: ErrorCategory
    let severity: ErrorSeverity
    let userMessage: String
    let technicalDetails: String?
    let suggestedAction: String?
    let retryHandler: (() -> Void)?
    let dismissHandler: (() -> Void)?
    
    init(
        category: ErrorCategory,
        severity: ErrorSeverity,
        userMessage: String,
        technicalDetails: String? = nil,
        suggestedAction: String? = nil,
        retryHandler: (() -> Void)? = nil,
        dismissHandler: (() -> Void)? = nil
    ) {
        self.category = category
        self.severity = severity
        self.userMessage = userMessage
        self.technicalDetails = technicalDetails
        self.suggestedAction = suggestedAction
        self.retryHandler = retryHandler
        self.dismissHandler = dismissHandler
    }
}

// MARK: - Error Coordinator Protocol

protocol ErrorCoordinatorProtocol: ObservableObject {
    var currentError: ErrorContext? { get }
    var errorHistory: [ErrorContext] { get }
    
    func handle(_ error: Error, category: ErrorCategory, retryHandler: (() -> Void)?)
    func handle(context: ErrorContext)
    func dismiss()
    func clearHistory()
}

// MARK: - Error Coordinator Implementation

@MainActor
final class ErrorCoordinator: ObservableObject, ErrorCoordinatorProtocol {
    
    // MARK: - Published Properties
    
    @Published var currentError: ErrorContext?
    @Published var errorHistory: [ErrorContext] = []
    
    // MARK: - Private Properties
    
    private let maxHistorySize = 50
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Public Methods
    
    func handle(_ error: Error, category: ErrorCategory, retryHandler: (() -> Void)? = nil) {
        let context = createErrorContext(from: error, category: category, retryHandler: retryHandler)
        handle(context: context)
    }
    
    func handle(context: ErrorContext) {
        // Add to history
        errorHistory.insert(context, at: 0)
        
        // Trim history if needed
        if errorHistory.count > maxHistorySize {
            errorHistory = Array(errorHistory.prefix(maxHistorySize))
        }
        
        // Log the error
        logError(context)
        
        // Set as current error for display
        currentError = context
        
        // Trigger haptic feedback based on severity
        triggerHapticFeedback(for: context.severity)
        
        let message = "Error handled: \(context.userMessage) - Category: \(context.category), Severity: \(context.severity)"
        PTLogger.general.error("\(message)")
    }
    
    func dismiss() {
        if let current = currentError, let dismissHandler = current.dismissHandler {
            dismissHandler()
        }
        currentError = nil
    }
    
    func clearHistory() {
        errorHistory.removeAll()
        PTLogger.general.info("Error history cleared")
    }
    
    // MARK: - Convenience Methods
    
    func handleNetworkError(_ error: Error, retryHandler: (() -> Void)? = nil) {
        handle(error, category: .network, retryHandler: retryHandler)
    }
    
    func handleAPIError(_ error: APIError, retryHandler: (() -> Void)? = nil) {
        handle(error, category: .api, retryHandler: retryHandler)
    }
    
    func handleDownloadError(_ error: DownloadError, retryHandler: (() -> Void)? = nil) {
        handle(error, category: .download, retryHandler: retryHandler)
    }
    
    func handleMediaError(_ error: Error, retryHandler: (() -> Void)? = nil) {
        handle(error, category: .media, retryHandler: retryHandler)
    }
    
    func handleStorageError(_ error: Error, retryHandler: (() -> Void)? = nil) {
        handle(error, category: .storage, retryHandler: retryHandler)
    }
    
    // MARK: - Private Methods
    
    private func createErrorContext(from error: Error, category: ErrorCategory, retryHandler: (() -> Void)?) -> ErrorContext {
        let (userMessage, severity, suggestedAction) = parseError(error, category: category)
        
        return ErrorContext(
            category: category,
            severity: severity,
            userMessage: userMessage,
            technicalDetails: error.localizedDescription,
            suggestedAction: suggestedAction,
            retryHandler: retryHandler,
            dismissHandler: { [weak self] in
                self?.currentError = nil
            }
        )
    }
    
    private func parseError(_ error: Error, category: ErrorCategory) -> (userMessage: String, severity: ErrorSeverity, suggestedAction: String?) {
        switch category {
        case .network:
            return parseNetworkError(error)
        case .api:
            return parseAPIError(error)
        case .storage:
            return parseStorageError(error)
        case .media:
            return parseMediaError(error)
        case .download:
            return parseDownloadError(error)
        case .transcription:
            return parseTranscriptionError(error)
        case .authentication:
            return parseAuthenticationError(error)
        case .ui:
            return parseUIError(error)
        case .system:
            return parseSystemError(error)
        }
    }
    
    private func parseNetworkError(_ error: Error) -> (String, ErrorSeverity, String?) {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return ("No internet connection available", .high, "Check your internet connection and try again")
            case .timedOut:
                return ("Request timed out", .medium, "Please try again")
            case .cannotFindHost:
                return ("Cannot connect to server", .high, "Check your internet connection")
            default:
                return ("Network error occurred", .medium, "Please try again")
            }
        }
        return ("Network connection failed", .medium, "Check your connection and try again")
    }
    
    private func parseAPIError(_ error: Error) -> (String, ErrorSeverity, String?) {
        if let apiError = error as? APIError {
            switch apiError {
            case .invalidURL:
                return ("Invalid request", .medium, "Please try again")
            case .invalidResponse:
                return ("Server response error", .medium, "Please try again")
            case .httpError(let statusCode):
                switch statusCode {
                case 404:
                    return ("Resource not found", .medium, nil)
                case 429:
                    return ("Too many requests", .low, "Please wait a moment and try again")
                case 500...599:
                    return ("Server error", .high, "Please try again later")
                default:
                    return ("Server error (\(statusCode))", .medium, "Please try again")
                }
            case .decodingError:
                return ("Data format error", .medium, "Please try again")
            case .networkError(let underlyingError):
                return parseNetworkError(underlyingError)
            case .notFound:
                return ("Resource not found", .medium, "Please try again")
            case .serverError:
                return ("Server error", .high, "Please try again later")
            case .rateLimited:
                return ("Too many requests", .low, "Please wait a moment and try again")
            case .unauthorized:
                return ("Access denied", .medium, "Please check your permissions")
            }
        }
        return ("API request failed", .medium, "Please try again")
    }
    
    private func parseStorageError(_ error: Error) -> (String, ErrorSeverity, String?) {
        return ("Storage error occurred", .high, "Please restart the app")
    }
    
    private func parseMediaError(_ error: Error) -> (String, ErrorSeverity, String?) {
        return ("Media playback error", .medium, "Try playing a different resource")
    }
    
    private func parseDownloadError(_ error: Error) -> (String, ErrorSeverity, String?) {
        if let downloadError = error as? DownloadError {
            switch downloadError {
            case .noDownloadableContent:
                return ("No downloadable content available", .low, nil)
            case .invalidDownloadURL:
                return ("Download link is invalid", .medium, "Try again later")
            case .networkError:
                return ("Download failed", .medium, "Check your connection and try again")
            case .downloadTaskNotFound:
                return ("Download task not found", .medium, "Try again later")
            case .fileSystemError:
                return ("Storage error", .high, "Check available storage space")
            case .fileValidationFailed:
                return ("File validation failed", .medium, "Try downloading again")
            case .fileSizeMismatch:
                return ("File size mismatch", .medium, "Try downloading again")
            case .unsupportedURL:
                return ("Unsupported download URL", .low, "This content cannot be downloaded")
            case .fileNotFound:
                return ("Download file not found", .medium, "Try downloading again")
            case .fileMoveFailed:
                return ("Failed to save download", .high, "Check available storage space")
            }
        }
        return ("Download error", .medium, "Please try again")
    }
    
    private func parseTranscriptionError(_ error: Error) -> (String, ErrorSeverity, String?) {
        return ("Transcription service error", .low, "Transcription will be available later")
    }
    
    private func parseAuthenticationError(_ error: Error) -> (String, ErrorSeverity, String?) {
        return ("Authentication error", .high, "Please check your credentials")
    }
    
    private func parseUIError(_ error: Error) -> (String, ErrorSeverity, String?) {
        return ("Interface error", .low, "Please try again")
    }
    
    private func parseSystemError(_ error: Error) -> (String, ErrorSeverity, String?) {
        return ("System error occurred", .critical, "Please restart the app")
    }
    
    private func logError(_ context: ErrorContext) {
        // Log error based on severity
        
        var logMessage = "[\(context.category)] \(context.userMessage)"
        
        if let technicalDetails = context.technicalDetails {
            logMessage += " | Technical: \(technicalDetails)"
        }
        
        if let suggestedAction = context.suggestedAction {
            logMessage += " | Suggestion: \(suggestedAction)"
        }
        
        switch context.severity {
        case .low:
            let msg = "\(context.category): \(context.userMessage)"
            PTLogger.general.info("\(msg)")
        case .medium:
            let msg = "\(context.category): \(context.userMessage)"
            PTLogger.general.warning("\(msg)")
        case .high:
            let msg = "\(context.category): \(context.userMessage)"
            PTLogger.general.error("\(msg)")
        case .critical:
            let msg = "CRITICAL \(context.category): \(context.userMessage)"
            PTLogger.general.error("\(msg)")
        }
    }
    
    private func triggerHapticFeedback(for severity: ErrorSeverity) {
        // Note: This will be updated to use MediaManager once singleton is removed
        switch severity {
        case .low:
            HapticFeedbackService.shared.lightImpact()
        case .medium:
            HapticFeedbackService.shared.warning()
        case .high:
            HapticFeedbackService.shared.error()
        case .critical:
            HapticFeedbackService.shared.error()
            // Double error feedback for critical issues
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                HapticFeedbackService.shared.error()
            }
        }
    }
}

// MARK: - SwiftUI Integration

extension ErrorCoordinator {
    
    var hasCurrentError: Bool {
        currentError != nil
    }
    
    var shouldShowErrorAlert: Bool {
        guard let error = currentError else { return false }
        return error.severity == .high || error.severity == .critical
    }
    
    var shouldShowErrorBanner: Bool {
        guard let error = currentError else { return false }
        return error.severity == .low || error.severity == .medium
    }
}

// MARK: - Environment Key

struct ErrorCoordinatorKey: EnvironmentKey {
    @MainActor
    static let defaultValue: ErrorCoordinator = ErrorCoordinator()
}

extension EnvironmentValues {
    var errorCoordinator: ErrorCoordinator {
        get { self[ErrorCoordinatorKey.self] }
        set { self[ErrorCoordinatorKey.self] = newValue }
    }
}

// MARK: - View Modifier

struct ErrorHandling: ViewModifier {
    @EnvironmentObject private var errorCoordinator: ErrorCoordinator
    
    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: .constant(errorCoordinator.shouldShowErrorAlert)) {
                if let error = errorCoordinator.currentError {
                    if let retryHandler = error.retryHandler {
                        Button("Try Again") {
                            retryHandler()
                            errorCoordinator.dismiss()
                        }
                    }
                    Button("OK") {
                        errorCoordinator.dismiss()
                    }
                }
            } message: {
                if let error = errorCoordinator.currentError {
                    Text(error.userMessage)
                }
            }
            .overlay(alignment: .top) {
                if errorCoordinator.shouldShowErrorBanner,
                   let error = errorCoordinator.currentError {
                    ErrorBanner(
                        message: error.userMessage,
                        severity: error.severity,
                        onDismiss: { errorCoordinator.dismiss() },
                        onRetry: error.retryHandler
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(), value: errorCoordinator.hasCurrentError)
                }
            }
    }
}

extension View {
    func withErrorHandling() -> some View {
        modifier(ErrorHandling())
    }
}

// MARK: - Error Banner Component

private struct ErrorBanner: View {
    let message: String
    let severity: ErrorSeverity
    let onDismiss: () -> Void
    let onRetry: (() -> Void)?
    
    private var backgroundColor: Color {
        switch severity {
        case .low:
            return PTDesignTokens.Colors.kleinBlue.opacity(0.1)
        case .medium:
            return PTDesignTokens.Colors.tang.opacity(0.1)
        case .high, .critical:
            return Color.red.opacity(0.1)
        }
    }
    
    private var iconColor: Color {
        switch severity {
        case .low:
            return PTDesignTokens.Colors.kleinBlue
        case .medium:
            return PTDesignTokens.Colors.tang
        case .high, .critical:
            return .red
        }
    }
    
    private var iconName: String {
        switch severity {
        case .low:
            return "info.circle.fill"
        case .medium:
            return "exclamationmark.triangle.fill"
        case .high, .critical:
            return "xmark.octagon.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: PTDesignTokens.Spacing.md) {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .font(.system(size: 16, weight: .medium))
            
            Text(message)
                .font(PTFont.ptBodyText)
                .foregroundColor(PTDesignTokens.Colors.ink)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
            
            Spacer()
            
            HStack(spacing: PTDesignTokens.Spacing.sm) {
                if let onRetry = onRetry {
                    Button("Retry") {
                        onRetry()
                    }
                    .font(PTFont.ptButtonText)
                    .foregroundColor(iconColor)
                }
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(PTDesignTokens.Colors.medium)
                }
            }
        }
        .padding(PTDesignTokens.Spacing.md)
        .background(backgroundColor)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(iconColor.opacity(0.3)),
            alignment: .bottom
        )
        .clipShape(RoundedRectangle(cornerRadius: PTDesignTokens.BorderRadius.md))
        .padding(.horizontal, PTDesignTokens.Spacing.screenEdges)
        .padding(.top, PTDesignTokens.Spacing.sm)
    }
}