import Foundation

protocol LLMClient: Sendable {
    func testConnection() async throws -> Bool
    func generateEditIntent(request: EditPlanRequest) async throws -> EditIntent
    func refinePrompt(request: PromptRefinementRequest) async throws -> String
}

enum LLMClientError: LocalizedError {
    case invalidURL
    case missingAPIKey
    case requestFailed(Int, String)
    case invalidResponse
    case invalidJSON(String)
    case ollamaUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The provider base URL is invalid."
        case .missingAPIKey:
            return "Add an API key or switch to Ollama local mode."
        case .requestFailed(let status, let message):
            return "The AI provider returned HTTP \(status): \(message)"
        case .invalidResponse:
            return "The AI provider returned an unexpected response."
        case .invalidJSON:
            return "The AI model returned an invalid edit plan. Try simplifying your prompt."
        case .ollamaUnavailable:
            return "Ollama is not running. Start Ollama and try again."
        }
    }
}

enum PromptRefinementDecoder {
    static func decode(_ text: String) throws -> String {
        guard let jsonText = extractJSONObject(from: text),
              let data = jsonText.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let prompt = (object["refined_prompt"] as? String)
                ?? (object["prompt"] as? String) else {
            throw LLMClientError.invalidJSON(text)
        }
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw LLMClientError.invalidJSON("The refined prompt was empty.")
        }
        return trimmed
    }

    private static func extractJSONObject(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}"),
              start <= end else {
            return nil
        }
        return String(trimmed[start...end])
    }
}

enum EditIntentDecoder {
    static func decode(_ text: String) throws -> EditIntent {
        guard let jsonText = extractJSONObject(from: text),
              let data = jsonText.data(using: .utf8),
              var object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMClientError.invalidJSON(text)
        }
        if let wrapped = object["intent"] as? [String: Any] {
            object = wrapped
        } else if let wrapped = object["edit_plan"] as? [String: Any] {
            object = wrapped
        }

        let nestedVideo = object["video"] as? [String: Any]
        let nestedAudio = object["audio"] as? [String: Any]
        let nestedOutput = object["output"] as? [String: Any]

        guard let videoReference = string(
            in: object,
            keys: ["video_file_id", "base_file_id", "video_id", "video_filename", "video"]
        ) ?? nestedVideo.flatMap({
            string(in: $0, keys: ["base_file_id", "video_file_id", "file_id", "filename"])
        }), !videoReference.isEmpty else {
            throw LLMClientError.invalidJSON("Missing video_file_id.")
        }

        let overlays: [OverlayPlan]
        if let rawOverlays = object["overlays"], !(rawOverlays is NSNull) {
            do {
                let overlayData = try JSONSerialization.data(withJSONObject: rawOverlays)
                overlays = try JSONDecoder().decode([OverlayPlan].self, from: overlayData)
            } catch {
                throw LLMClientError.invalidJSON("Invalid overlays: \(error.localizedDescription)")
            }
        } else {
            overlays = []
        }

        return EditIntent(
            summary: string(in: object, keys: ["summary", "description"]) ?? "Create the requested video.",
            targetDurationSeconds: double(
                in: object,
                keys: ["target_duration_seconds", "targetDurationSeconds", "duration_seconds"]
            ) ?? nestedOutput.flatMap({
                double(in: $0, keys: ["target_duration_seconds", "duration_seconds"])
            }),
            requestedAudioLoopCount: integer(
                in: object,
                keys: ["requested_audio_loop_count", "audio_loop_count", "music_loop_count", "loop_count"]
            ) ?? nestedAudio.flatMap({
                integer(in: $0, keys: ["requested_audio_loop_count", "audio_loop_count", "loop_count"])
            }),
            videoFileId: videoReference,
            audioFileId: string(
                in: object,
                keys: ["audio_file_id", "music_file_id", "audio_id", "audio_filename", "music_filename", "audio", "music"]
            ) ?? nestedAudio.flatMap({
                string(in: $0, keys: ["file_id", "audio_file_id", "filename"])
            }),
            overlays: overlays,
            unsupportedRequests: stringArray(in: object, key: "unsupported_requests"),
            assumptions: stringArray(in: object, key: "assumptions")
        )
    }

    private static func extractJSONObject(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}"),
              start <= end else {
            return nil
        }
        return String(trimmed[start...end])
    }

    private static func string(in object: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = object[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, trimmed.lowercased() != "null" {
                    return trimmed
                }
            }
        }
        return nil
    }

    private static func double(in object: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let number = object[key] as? NSNumber {
                return number.doubleValue
            }
            if let value = object[key] as? String, let number = Double(value) {
                return number
            }
        }
        return nil
    }

    private static func integer(in object: [String: Any], keys: [String]) -> Int? {
        guard let value = double(in: object, keys: keys), value.isFinite else { return nil }
        return Int(value)
    }

    private static func stringArray(in object: [String: Any], key: String) -> [String] {
        if let values = object[key] as? [String] {
            return values
        }
        if let value = object[key] as? String, !value.isEmpty {
            return [value]
        }
        return []
    }
}
