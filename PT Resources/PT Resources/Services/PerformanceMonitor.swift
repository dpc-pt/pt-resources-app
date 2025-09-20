//
//  PerformanceMonitor.swift
//  PT Resources
//
//  Service for monitoring app performance and identifying bottlenecks
//

import Foundation
import SwiftUI
import os.log

// MARK: - Performance Metrics

struct PerformanceMetrics {
    let operation: String
    let duration: TimeInterval
    let memoryUsage: Int64
    let timestamp: Date

    var isSlow: Bool {
        duration > 0.5 // 500ms is considered slow
    }
}

// MARK: - Performance Monitor Protocol

protocol PerformanceMonitorProtocol {
    func startTiming(_ operation: String) -> String
    func endTiming(_ token: String)
    func recordMetric(_ operation: String, duration: TimeInterval)
    func logMemoryUsage()
    func logSlowOperations()
}

// MARK: - Performance Monitor Implementation

@MainActor
final class PerformanceMonitor: ObservableObject, PerformanceMonitorProtocol {

    static let shared = PerformanceMonitor()

    // MARK: - Published Properties

    @Published private(set) var slowOperations: [PerformanceMetrics] = []
    @Published private(set) var memoryUsageHistory: [Int64] = []
    @Published private(set) var averageResponseTime: TimeInterval = 0
    @Published private(set) var isMonitoringEnabled = false

    // MARK: - Private Properties

    private var timingTokens: [String: (operation: String, startTime: Date)] = [:]
    private var operationMetrics: [String: [TimeInterval]] = [:]
    private var memoryPressureLevel: DispatchSource.MemoryPressureEvent = .normal
    private let memoryPressureSource = DispatchSource.makeMemoryPressureSource(eventMask: .all, queue: .main)

    private init() {
        setupMemoryMonitoring()
    }

    // MARK: - Public Methods

    func startTiming(_ operation: String) -> String {
        guard isMonitoringEnabled else { return UUID().uuidString }

        let token = UUID().uuidString
        timingTokens[token] = (operation, Date())
        Logger.performance.debug("Started timing: \(operation)")
        return token
    }

    func endTiming(_ token: String) {
        guard isMonitoringEnabled,
              let (operation, startTime) = timingTokens[token] else { return }

        let duration = Date().timeIntervalSince(startTime)
        let memoryUsage = getCurrentMemoryUsage()

        timingTokens.removeValue(forKey: token)

        recordMetric(operation, duration: duration)

        let metric = PerformanceMetrics(
            operation: operation,
            duration: duration,
            memoryUsage: memoryUsage,
            timestamp: startTime
        )

        if metric.isSlow {
            slowOperations.append(metric)
            Logger.performance.warning("Slow operation detected: \(operation) took \(String(format: "%.2f", duration))s")
        }

        Logger.performance.debug("Completed timing: \(operation) in \(String(format: "%.2f", duration))s")
    }

    func recordMetric(_ operation: String, duration: TimeInterval) {
        if operationMetrics[operation] == nil {
            operationMetrics[operation] = []
        }
        operationMetrics[operation]?.append(duration)

        // Update average response time
        let allDurations = operationMetrics.values.flatMap { $0 }
        averageResponseTime = allDurations.reduce(0, +) / Double(max(1, allDurations.count))
    }

    func logMemoryUsage() {
        let memoryUsage = getCurrentMemoryUsage()
        memoryUsageHistory.append(memoryUsage)

        // Keep only last 100 measurements
        if memoryUsageHistory.count > 100 {
            memoryUsageHistory = Array(memoryUsageHistory.suffix(100))
        }

        Logger.performance.debug("Current memory usage: \(self.formatBytes(memoryUsage))")
    }

    func logSlowOperations() {
        guard !slowOperations.isEmpty else {
            Logger.performance.info("No slow operations detected")
            return
        }

        Logger.performance.warning("Found \(self.slowOperations.count) slow operations:")
        for metric in slowOperations {
            Logger.performance.warning("- \(metric.operation): \(String(format: "%.2f", metric.duration))s at \(metric.timestamp)")
        }
    }

    func enableMonitoring() {
        isMonitoringEnabled = true
        Logger.performance.info("Performance monitoring enabled")
    }

    func disableMonitoring() {
        isMonitoringEnabled = false
        Logger.performance.info("Performance monitoring disabled")
    }

    func clearSlowOperations() {
        slowOperations.removeAll()
    }

    func getPerformanceReport() -> String {
        var report = "Performance Report\n"
        report += "==================\n"
        report += "Average response time: \(String(format: "%.2f", averageResponseTime))s\n"
        report += "Slow operations: \(slowOperations.count)\n"
        report += "Memory usage: \(formatBytes(getCurrentMemoryUsage()))\n"

        if !operationMetrics.isEmpty {
            report += "\nOperation Averages:\n"
            for (operation, durations) in operationMetrics {
                let avg = durations.reduce(0, +) / Double(durations.count)
                report += "- \(operation): \(String(format: "%.2f", avg))s\n"
            }
        }

        return report
    }

    // MARK: - Private Methods

    private func setupMemoryMonitoring() {
        memoryPressureSource.setEventHandler { [weak self] in
            guard let self = self else { return }
            let event = self.memoryPressureSource.data

            if event.contains(.critical) {
                Logger.performance.error("Memory pressure: Critical")
                self.memoryPressureLevel = .critical
            } else if event.contains(.warning) {
                Logger.performance.warning("Memory pressure: Warning")
                self.memoryPressureLevel = .warning
            } else if event.contains(.normal) {
                Logger.performance.debug("Memory pressure: Normal")
                self.memoryPressureLevel = .normal
            } else {
                Logger.performance.debug("Memory pressure: Unknown")
            }
        }

        memoryPressureSource.resume()

        // Monitor memory usage periodically
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.logMemoryUsage()
        }
    }

    private func getCurrentMemoryUsage() -> Int64 {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
        let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            return Int64(taskInfo.phys_footprint)
        } else {
            return 0
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - View Extensions for Performance Monitoring

extension View {
    func withPerformanceTiming(_ operation: String) -> some View {
        modifier(PerformanceTimingModifier(operation: operation))
    }

    func withMemoryLogging() -> some View {
        modifier(MemoryLoggingModifier())
    }
}

// MARK: - Performance Timing Modifier

private struct PerformanceTimingModifier: ViewModifier {
    let operation: String
    @State private var timingToken: String?

    func body(content: Content) -> some View {
        content
            .task {
                self.timingToken = PerformanceMonitor.shared.startTiming(operation)
            }
            .onDisappear {
                if let token = self.timingToken {
                    PerformanceMonitor.shared.endTiming(token)
                }
            }
    }
}

// MARK: - Memory Logging Modifier

private struct MemoryLoggingModifier: ViewModifier {
    @State private var timer: Timer?

    func body(content: Content) -> some View {
        content
            .task {
                PerformanceMonitor.shared.logMemoryUsage()
                self.timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
                    PerformanceMonitor.shared.logMemoryUsage()
                }
            }
            .onDisappear {
                self.timer?.invalidate()
            }
    }
}

// MARK: - Logger Extension

extension Logger {
    static let performance = Logger(subsystem: "com.ptresources", category: "performance")
}

// MARK: - Convenience Functions

extension PerformanceMonitor {
    static func measureTime<T>(_ operation: String, block: () async throws -> T) async throws -> T {
        let token = shared.startTiming(operation)
        defer { shared.endTiming(token) }

        let result = try await block()
        return result
    }

    static func measureTime<T>(_ operation: String, block: () throws -> T) throws -> T {
        let token = shared.startTiming(operation)
        defer { shared.endTiming(token) }

        let result = try block()
        return result
    }
}

