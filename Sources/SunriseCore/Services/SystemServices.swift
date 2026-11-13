import Foundation
#if os(macOS)
import ServiceManagement
#endif

public protocol WakeServiceProtocol: Sendable {
    /// Wakes the Mac every selected day at the sunrise start.
    func schedule(_ plan: SchedulePlan) async throws
    func cancel() async throws
}

public protocol LoginItemServiceProtocol: Sendable {
    func setEnabled(_ enabled: Bool) throws
}

public enum WakeError: LocalizedError, Equatable {
    case cancelled
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .cancelled: "Yönetici izni verilmedi, Mac uykudan uyanmayacak."
        case .failed(let output): "Uyanma saati ayarlanamadı: \(output)"
        }
    }
}

#if os(macOS)
/// Sets the repeating wake with `pmset`, which needs admin rights; macOS
/// shows its own password dialog for it.
public struct PmsetWakeService: WakeServiceProtocol {
    public init() {}

    public func schedule(_ plan: SchedulePlan) async throws {
        try await runAsAdmin("/usr/bin/pmset repeat wakeorpoweron \(plan.pmsetDays) \(plan.pmsetTime)")
    }

    public func cancel() async throws {
        try await runAsAdmin("/usr/bin/pmset repeat cancel")
    }

    private func runAsAdmin(_ command: String) async throws {
        let script = "do shell script \"\(command)\" with administrator privileges"
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            process.standardError = pipe
            process.standardOutput = pipe
            process.terminationHandler = { finished in
                let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                switch finished.terminationStatus {
                case 0: continuation.resume()
                case _ where output.contains("-128"): continuation.resume(throwing: WakeError.cancelled)
                default: continuation.resume(throwing: WakeError.failed(output.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: WakeError.failed(error.localizedDescription))
            }
        }
    }
}

/// Starts the app at login so the alarm survives restarts.
public struct LoginItemService: LoginItemServiceProtocol {
    public init() {}

    public func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        switch (enabled, service.status) {
        case (true, .enabled), (false, .notRegistered), (false, .notFound):
            return
        case (true, _):
            try service.register()
        case (false, _):
            try service.unregister()
        }
    }
}
#endif
