import EchoelCore
import Foundation
#if canImport(MetricKit)
import MetricKit
#endif

/// The system's own reports on how the app ended — a crash's signal and exception, a hang's
/// length — written into the local diagnostic log (`DiagnosticLog.app`) when iOS hands them over,
/// usually at the next launch. Nothing leaves the device: the musician shares the log by hand
/// (About → Share Diagnostics). Only numbers reach the file — the termination reason and the call
/// stacks are text the system wrote and stay out, as the log's own rule says.
final class CrashReports: NSObject, Sendable {
    static let shared = CrashReports()

    /// Once, at launch, after the log began.
    func start() {
        #if canImport(MetricKit)
        MXMetricManager.shared.add(self)
        #endif
    }

    /// A number the report may lack, as the log writes it: -1 for none.
    static func value(_ number: NSNumber?) -> Double {
        guard let number else { return -1 }
        let value = number.doubleValue
        return value.isFinite ? value : -1
    }
}

#if canImport(MetricKit)
extension CrashReports: MXMetricManagerSubscriber {
    /// Called by MetricKit on a queue of its own; the log takes its own lock.
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            for crash in payload.crashDiagnostics ?? [] {
                DiagnosticLog.app.note("metrickit: crash", [("signal", Self.value(crash.signal)),
                                                             ("exceptionType", Self.value(crash.exceptionType)),
                                                             ("exceptionCode", Self.value(crash.exceptionCode))])
            }
            for hang in payload.hangDiagnostics ?? [] {
                let seconds = hang.hangDuration.converted(to: .seconds).value
                DiagnosticLog.app.note("metrickit: hang", [("s", seconds.isFinite ? seconds : -1)])
            }
            for cpu in payload.cpuExceptionDiagnostics ?? [] {
                let seconds = cpu.totalCPUTime.converted(to: .seconds).value
                DiagnosticLog.app.note("metrickit: cpu exception", [("cpu_s", seconds.isFinite ? seconds : -1)])
            }
            for disk in payload.diskWriteExceptionDiagnostics ?? [] {
                let bytes = disk.totalWritesCaused.converted(to: .bytes).value
                DiagnosticLog.app.note("metrickit: disk write exception", [("bytes", bytes.isFinite ? bytes : -1)])
            }
        }
    }
}
#endif
