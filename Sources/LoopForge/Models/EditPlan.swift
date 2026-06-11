import Foundation

struct EditIntent: Codable, Equatable, Sendable {
    let summary: String
    let targetDurationSeconds: Double?
    let requestedAudioLoopCount: Int?
    let videoFileId: String
    let audioFileId: String?
    let overlays: [OverlayPlan]
    let unsupportedRequests: [String]
    let assumptions: [String]

    enum CodingKeys: String, CodingKey {
        case summary, overlays, assumptions
        case targetDurationSeconds = "target_duration_seconds"
        case requestedAudioLoopCount = "requested_audio_loop_count"
        case videoFileId = "video_file_id"
        case audioFileId = "audio_file_id"
        case unsupportedRequests = "unsupported_requests"
    }
}

struct EditPlan: Codable, Equatable, Sendable {
    let summary: String
    let output: OutputSettings
    let video: VideoPlan
    let audio: AudioPlan?
    let overlays: [OverlayPlan]
    let effects: [EffectPlan]
    let unsupportedRequests: [String]
    let assumptions: [String]

    enum CodingKeys: String, CodingKey {
        case summary, output, video, audio, overlays, effects, assumptions
        case unsupportedRequests = "unsupported_requests"
    }
}

struct OutputSettings: Codable, Equatable, Sendable {
    let format: String
    let filename: String
    let targetDurationSeconds: Double?
    let requestedAudioLoopCount: Int?
    let width: Int?
    let height: Int?
    let fps: Double?

    enum CodingKeys: String, CodingKey {
        case format, filename, width, height, fps
        case targetDurationSeconds = "target_duration_seconds"
        case requestedAudioLoopCount = "requested_audio_loop_count"
    }
}

struct VideoPlan: Codable, Equatable, Sendable {
    let baseFileId: String
    let loop: Bool
    let trimStartSeconds: Double?
    let trimEndSeconds: Double?
    let resize: ResizeSettings?
    let preserveAspectRatio: Bool

    enum CodingKeys: String, CodingKey {
        case loop, resize
        case baseFileId = "base_file_id"
        case trimStartSeconds = "trim_start_seconds"
        case trimEndSeconds = "trim_end_seconds"
        case preserveAspectRatio = "preserve_aspect_ratio"
    }
}

struct ResizeSettings: Codable, Equatable, Sendable {
    let width: Int?
    let height: Int?
}

struct AudioPlan: Codable, Equatable, Sendable {
    let mode: AudioMode
    let fileId: String?
    let loop: Bool
    let trimToOutputDuration: Bool
    let keepOriginalAudio: Bool
    let volume: Double?

    enum CodingKeys: String, CodingKey {
        case mode, loop, volume
        case fileId = "file_id"
        case trimToOutputDuration = "trim_to_output_duration"
        case keepOriginalAudio = "keep_original_audio"
    }
}

enum AudioMode: String, Codable, CaseIterable, Sendable {
    case replace
    case keepOriginal = "keep_original"
    case mix
    case none
}

struct OverlayPlan: Codable, Equatable, Sendable {
    let type: String
    let fileId: String
    let position: OverlayPosition
    let xMargin: Int
    let yMargin: Int
    let width: Int?
    let height: Int?
    let startSeconds: Double
    let endSeconds: Double?
    let opacity: Double?

    enum CodingKeys: String, CodingKey {
        case type, position, width, height, opacity
        case fileId = "file_id"
        case xMargin = "x_margin"
        case yMargin = "y_margin"
        case startSeconds = "start_seconds"
        case endSeconds = "end_seconds"
    }
}

enum OverlayPosition: String, Codable, CaseIterable, Sendable {
    case topLeft = "top_left"
    case topRight = "top_right"
    case bottomLeft = "bottom_left"
    case bottomRight = "bottom_right"
    case center
}

struct EffectPlan: Codable, Equatable, Sendable {
    let type: EffectType
    let startSeconds: Double
    let durationSeconds: Double

    enum CodingKeys: String, CodingKey {
        case type
        case startSeconds = "start_seconds"
        case durationSeconds = "duration_seconds"
    }
}

enum EffectType: String, Codable, CaseIterable, Sendable {
    case fadeIn = "fade_in"
    case fadeOutToBlack = "fade_out_to_black"
}

struct EditPlanRequest: Sendable {
    let userPrompt: String
    let assets: [MediaAsset]
}

struct PromptRefinementRequest: Sendable {
    let userPrompt: String
    let assets: [MediaAsset]
    let failureReason: String?
    let unsupportedRequests: [String]
}

struct ValidatedEditPlan: Sendable {
    let plan: EditPlan
    let durationPlan: DurationPlan
    let exportSettings: ResolvedExportSettings
    let assetsByID: [String: MediaAsset]
    let destinationFolder: URL
    let outputURL: URL
    let ffmpegPath: String
    let ffprobePath: String
}

struct FFmpegCommand: Equatable, Sendable {
    let executablePath: String
    let arguments: [String]
    let outputURL: URL
    let durationSeconds: Double
}
