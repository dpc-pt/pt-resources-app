//
//  PTLogger.swift
//  PT Resources
//
//  Centralized logging system for the PT Resources app
//

import Foundation
import OSLog

/// Centralized logging system with proper categorization and levels
struct PTLogger {
    private static let subsystem = "org.proctrust.ptresources"

    // MARK: - Log Categories

    static let api = Logger(subsystem: subsystem, category: "API")
    static let coreData = Logger(subsystem: subsystem, category: "CoreData")
    static let ui = Logger(subsystem: subsystem, category: "UI")
    static let audio = Logger(subsystem: subsystem, category: "Audio")
    static let download = Logger(subsystem: subsystem, category: "Download")
    static let fonts = Logger(subsystem: subsystem, category: "Fonts")
    static let general = Logger(subsystem: subsystem, category: "General")
    static let security = Logger(subsystem: subsystem, category: "Security")

    // MARK: - Convenience Methods

    static func apiRequest(_ message: String, metadata: [String: Any]? = nil) {
        log(message, level: .info, logger: api, metadata: metadata)
    }

    static func apiError(_ message: String, error: Error? = nil, metadata: [String: Any]? = nil) {
        log(message, level: .error, logger: api, error: error, metadata: metadata)
    }

    static func coreDataOperation(_ message: String, metadata: [String: Any]? = nil) {
        log(message, level: .info, logger: coreData, metadata: metadata)
    }

    static func coreDataError(_ message: String, error: Error? = nil, metadata: [String: Any]? = nil) {
        log(message, level: .error, logger: coreData, error: error, metadata: metadata)
    }

    static func uiEvent(_ message: String, metadata: [String: Any]? = nil) {
        log(message, level: .info, logger: ui, metadata: metadata)
    }

    static func uiError(_ message: String, error: Error? = nil, metadata: [String: Any]? = nil) {
        log(message, level: .error, logger: ui, error: error, metadata: metadata)
    }

    static func audioEvent(_ message: String, metadata: [String: Any]? = nil) {
        log(message, level: .info, logger: audio, metadata: metadata)
    }

    static func downloadProgress(_ message: String, metadata: [String: Any]? = nil) {
        log(message, level: .info, logger: download, metadata: metadata)
    }

    static func fontRegistration(_ message: String, metadata: [String: Any]? = nil) {
        log(message, level: .info, logger: fonts, metadata: metadata)
    }

    // MARK: - Private Methods

    private static func log(
        _ message: String,
        level: OSLogType,
        logger: Logger,
        error: Error? = nil,
        metadata: [String: Any]? = nil
    ) {
        let fullMessage = buildMessage(message, error: error, metadata: metadata)

        switch level {
        case .info:
            logger.info("\(fullMessage)")
        case .error:
            logger.error("\(fullMessage)")
        case .debug:
            logger.debug("\(fullMessage)")
        case .fault:
            logger.fault("\(fullMessage)")
        default:
            logger.log(level: level, "\(fullMessage)")
        }
    }

    private static func buildMessage(_ baseMessage: String, error: Error?, metadata: [String: Any]?) -> String {
        var components = [baseMessage]

        if let error = error {
            components.append("Error: \(error.localizedDescription)")
        }

        if let metadata = metadata {
            let metadataString = metadata.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            components.append("Metadata: \(metadataString)")
        }

        return components.joined(separator: " | ")
    }
}

// MARK: - Performance Logging

extension PTLogger {
    static func performanceStart(_ operation: String) -> String {
        let id = UUID().uuidString
        log("Starting \(operation)", level: .info, logger: general, metadata: ["operation_id": id])
        return id
    }

    static func performanceEnd(_ operation: String, operationId: String, duration: TimeInterval) {
        log("Completed \(operation)", level: .info, logger: general, metadata: [
            "operation_id": operationId,
            "duration_ms": Int(duration * 1000)
        ])
    }

    static func measurePerformance(_ operation: String, block: () throws -> Void) rethrows {
        let startTime = Date()
        let operationId = performanceStart(operation)

        defer {
            let duration = Date().timeIntervalSince(startTime)
            performanceEnd(operation, operationId: operationId, duration: duration)
        }

        try block()
    }
}

