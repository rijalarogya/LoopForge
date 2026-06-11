import Foundation

enum MediaAnalyzerError: LocalizedError {
    case unsupportedFile(String)
    case ffprobeFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unsupportedFile(let filename):
            return "\(filename) is not a supported media type."
        case .ffprobeFailed:
            return "This file could not be analyzed. It may be damaged or unsupported."
        case .invalidResponse:
            return "ffprobe returned media metadata in an unexpected format."
        }
    }
}

struct MediaAnalyzer {
    let ffprobePath: String

    func analyze(url: URL, id: String = UUID().uuidString) async throws -> MediaAsset {
        guard FileHelpers.isSupported(url) else {
            throw MediaAnalyzerError.unsupportedFile(url.lastPathComponent)
        }

        let result = try await ProcessExecutor.run(
            executablePath: ffprobePath,
            arguments: [
                "-v", "error",
                "-print_format", "json",
                "-show_format",
                "-show_streams",
                url.path
            ]
        )
        guard result.terminationStatus == 0 else {
            throw MediaAnalyzerError.ffprobeFailed(
                String(data: result.standardError, encoding: .utf8) ?? ""
            )
        }

        let response = try JSONDecoder().decode(FFprobeResponse.self, from: result.standardOutput)
        let videoStream = response.streams.first { $0.codecType == "video" }
        let audioStream = response.streams.first { $0.codecType == "audio" }
        let extensionName = url.pathExtension.lowercased()
        let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "webp"]

        let mediaType: MediaType
        if imageExtensions.contains(extensionName) {
            mediaType = .image
        } else if videoStream != nil {
            mediaType = .video
        } else if audioStream != nil {
            mediaType = .audio
        } else {
            mediaType = .unknown
        }

        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)
            ?? Int64(response.format?.size ?? "") ?? 0
        let duration = parseDouble(response.format?.duration)
            ?? parseDouble(videoStream?.duration)
            ?? parseDouble(audioStream?.duration)

        return MediaAsset(
            id: id,
            filename: url.lastPathComponent,
            path: url.path,
            type: mediaType,
            durationSeconds: mediaType == .image ? nil : duration,
            width: videoStream?.width,
            height: videoStream?.height,
            frameRate: parseFrameRate(videoStream?.averageFrameRate ?? videoStream?.realFrameRate),
            videoCodec: videoStream?.codecName,
            audioCodec: audioStream?.codecName,
            hasAudio: mediaType == .video ? audioStream != nil : nil,
            sampleRate: Int(audioStream?.sampleRate ?? ""),
            channels: audioStream?.channels,
            fileSizeBytes: fileSize
        )
    }

    private func parseDouble(_ value: String?) -> Double? {
        guard let value, let number = Double(value), number.isFinite else { return nil }
        return number
    }

    private func parseFrameRate(_ value: String?) -> Double? {
        guard let value else { return nil }
        let parts = value.split(separator: "/")
        if parts.count == 2, let numerator = Double(parts[0]), let denominator = Double(parts[1]), denominator != 0 {
            return numerator / denominator
        }
        return Double(value)
    }
}

private struct FFprobeResponse: Decodable {
    let streams: [FFprobeStream]
    let format: FFprobeFormat?
}

private struct FFprobeStream: Decodable {
    let codecName: String?
    let codecType: String?
    let width: Int?
    let height: Int?
    let averageFrameRate: String?
    let realFrameRate: String?
    let duration: String?
    let sampleRate: String?
    let channels: Int?

    enum CodingKeys: String, CodingKey {
        case width, height, duration, channels
        case codecName = "codec_name"
        case codecType = "codec_type"
        case averageFrameRate = "avg_frame_rate"
        case realFrameRate = "r_frame_rate"
        case sampleRate = "sample_rate"
    }
}

private struct FFprobeFormat: Decodable {
    let duration: String?
    let size: String?
}
