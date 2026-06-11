import Foundation

struct ProcessResult: Sendable {
    let terminationStatus: Int32
    let standardOutput: Data
    let standardError: Data
}

enum ProcessExecutorError: LocalizedError {
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .launchFailed(let message):
            return "The process could not be started: \(message)"
        }
    }
}

enum ProcessExecutor {
    static func run(executablePath: String, arguments: [String]) async throws -> ProcessResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdout = Pipe()
            let stderr = Pipe()
            let outputBuffer = DataBuffer()
            let errorBuffer = DataBuffer()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            process.standardOutput = stdout
            process.standardError = stderr

            stdout.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    outputBuffer.append(data)
                }
            }
            stderr.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    errorBuffer.append(data)
                }
            }
            process.terminationHandler = { finished in
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil
                outputBuffer.append(stdout.fileHandleForReading.readDataToEndOfFile())
                errorBuffer.append(stderr.fileHandleForReading.readDataToEndOfFile())
                continuation.resume(returning: ProcessResult(
                    terminationStatus: finished.terminationStatus,
                    standardOutput: outputBuffer.value,
                    standardError: errorBuffer.value
                ))
            }

            do {
                try process.run()
            } catch {
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil
                continuation.resume(throwing: ProcessExecutorError.launchFailed(error.localizedDescription))
            }
        }
    }
}

private final class DataBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ newData: Data) {
        guard !newData.isEmpty else { return }
        lock.lock()
        data.append(newData)
        lock.unlock()
    }

    var value: Data {
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}
