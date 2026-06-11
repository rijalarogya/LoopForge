import Foundation

enum EditPlanPromptBuilder {
    static let systemPrompt = """
    You are an assistant that converts natural language video editing requests into a strict JSON edit plan.
    You do not write FFmpeg commands.
    You do not write shell commands.
    You only return valid JSON matching the provided schema.
    Identify only the user's editing intent, requested target duration, selected video file,
    selected external audio file, and optional image overlays.
    The app calculates the final duration and final audio/video fades deterministically.
    If the user explicitly requests an audio loop count, return that count exactly.
    Do not infer a loop count when the user only requests a duration.
    If the user asks for something unsupported, include it in unsupported_requests and create the closest supported plan.
    Always reference files by provided file_id.
    Never invent files.
    Never invent paths.
    Never return comments.
    Never return markdown.
    Return JSON only.
    """

    static func userMessage(for request: EditPlanRequest) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let assetData = try encoder.encode(request.assets.map(LLMAsset.init))
        let assetJSON = String(decoding: assetData, as: UTF8.self)

        return """
        USER REQUEST:
        \(request.userPrompt)

        AVAILABLE FILES:
        \(assetJSON)

        Return exactly this JSON shape. Use null where optional values are unknown or unused:
        {
          "summary": "string",
          "target_duration_seconds": 60,
          "requested_audio_loop_count": null,
          "video_file_id": "provided video file id",
          "audio_file_id": "provided audio file id or null",
          "overlays": [{
            "type": "image",
            "file_id": "provided file id",
            "position": "top_right",
            "x_margin": 40,
            "y_margin": 40,
            "width": 180,
            "height": null,
            "start_seconds": 0,
            "end_seconds": 10,
            "opacity": 1.0
          }],
          "unsupported_requests": [],
          "assumptions": []
        }

        Allowed overlay positions: top_left, top_right, bottom_left, bottom_right, center.
        Set target_duration_seconds to the duration explicitly requested by the user, converted to seconds.
        If the user did not request a duration, set target_duration_seconds to null.
        If the user explicitly says to loop or play the audio N times, set requested_audio_loop_count to N.
        Otherwise set requested_audio_loop_count to null.
        Do not round the target to an audio-loop boundary. The app will calculate the final duration.
        Do not add the automatic final fade to effects. The app always adds it.
        """
    }
}

private struct LLMAsset: Encodable {
    let fileID: String
    let filename: String
    let type: MediaType
    let durationSeconds: Double?
    let width: Int?
    let height: Int?
    let frameRate: Double?
    let videoCodec: String?
    let audioCodec: String?
    let hasAudio: Bool?
    let sampleRate: Int?
    let channels: Int?
    let fileSizeBytes: Int64

    init(_ asset: MediaAsset) {
        fileID = asset.id
        filename = asset.filename
        type = asset.type
        durationSeconds = asset.durationSeconds
        width = asset.width
        height = asset.height
        frameRate = asset.frameRate
        videoCodec = asset.videoCodec
        audioCodec = asset.audioCodec
        hasAudio = asset.hasAudio
        sampleRate = asset.sampleRate
        channels = asset.channels
        fileSizeBytes = asset.fileSizeBytes
    }

    enum CodingKeys: String, CodingKey {
        case filename, type, width, height, channels
        case fileID = "file_id"
        case durationSeconds = "duration_seconds"
        case frameRate = "frame_rate"
        case videoCodec = "video_codec"
        case audioCodec = "audio_codec"
        case hasAudio = "has_audio"
        case sampleRate = "sample_rate"
        case fileSizeBytes = "file_size_bytes"
    }
}
