import Foundation

enum FFmpegRunnerError: LocalizedError {
    case launchFailed(String)
    case renderFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .launchFailed(let message):
            return "FFmpeg could not be started: \(message)"
        case .renderFailed:
            return "FFmpeg could not render the video. Open logs for details."
        }
    }
}

final class FFmpegRunner {
    private var process: Process?
    private let lock = NSLock()

    func run(
        command: FFmpegCommand,
        onProgress: @escaping (Double, Double) -> Void,
        onLog: @escaping (String) -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stderr = Pipe()
            process.executableURL = URL(fileURLWithPath: command.executablePath)
            process.arguments = command.arguments
            process.standardOutput = Pipe()
            process.standardError = stderr

            lock.lock()
            self.process = process
            lock.unlock()

            let streamBuffer = StreamBuffer()
            stderr.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                let chunk = String(decoding: data, as: UTF8.self)
                for line in streamBuffer.append(chunk) {
                    onLog(line)
                    if let seconds = ProgressParser.seconds(from: line) {
                        let progress = min(max(seconds / command.durationSeconds, 0), 1)
                        onProgress(progress, seconds)
                    }
                }
            }

            process.terminationHandler = { [weak self] finished in
                stderr.fileHandleForReading.readabilityHandler = nil
                let remaining = stderr.fileHandleForReading.readDataToEndOfFile()
                let finalText = streamBuffer.finish(with: String(decoding: remaining, as: UTF8.self))
                for line in finalText.components(separatedBy: .newlines) where !line.isEmpty {
                    onLog(line)
                    if let seconds = ProgressParser.seconds(from: line) {
                        let progress = min(max(seconds / command.durationSeconds, 0), 1)
                        onProgress(progress, seconds)
                    }
                }
                self?.lock.lock()
                self?.process = nil
                self?.lock.unlock()
                if finished.terminationStatus == 0 {
                    onProgress(1, command.durationSeconds)
                    continuation.resume()
                } else {
                    continuation.resume(throwing: FFmpegRunnerError.renderFailed(finished.terminationStatus))
                }
            }

            do {
                try process.run()
            } catch {
                stderr.fileHandleForReading.readabilityHandler = nil
                self.lock.lock()
                self.process = nil
                self.lock.unlock()
                continuation.resume(throwing: FFmpegRunnerError.launchFailed(error.localizedDescription))
            }
        }
    }

    func cancel() {
        lock.lock()
        let activeProcess = process
        lock.unlock()
        activeProcess?.terminate()
    }
}

private final class StreamBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var pendingText = ""

    func append(_ chunk: String) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        pendingText += chunk.replacingOccurrences(of: "\r", with: "\n")
        let parts = pendingText.components(separatedBy: .newlines)
        pendingText = parts.last ?? ""
        return parts.dropLast().filter { !$0.isEmpty }
    }

    func finish(with remaining: String) -> String {
        lock.lock()
        defer { lock.unlock() }
        let result = pendingText + remaining.replacingOccurrences(of: "\r", with: "\n")
        pendingText = ""
        return result
    }
}
