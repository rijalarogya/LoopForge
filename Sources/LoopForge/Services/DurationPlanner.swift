import Foundation

struct DurationPlan: Equatable, Sendable {
    let targetDurationSeconds: Double?
    let finalDurationSeconds: Double
    let audioDurationSeconds: Double?
    let audioLoopCount: Int
    let videoShouldLoop: Bool
    let audioShouldLoop: Bool
    let audioFadeStartSeconds: Double?
    let videoFadeStartSeconds: Double
    let fadeDurationSeconds: Double
    let explanation: String
}

enum DurationPlannerError: LocalizedError, Equatable {
    case missingDuration
    case invalidTargetDuration
    case invalidVideoDuration
    case invalidAudioDuration
    case durationExceedsLimit

    var errorDescription: String? {
        switch self {
        case .missingDuration:
            return "A target duration or valid media duration is required."
        case .invalidTargetDuration:
            return "The requested target duration must be greater than zero."
        case .invalidVideoDuration:
            return "The selected video does not have a valid duration."
        case .invalidAudioDuration:
            return "The selected audio does not have a valid duration."
        case .durationExceedsLimit:
            return "The calculated final duration cannot exceed 12 hours."
        }
    }
}

struct DurationPlanner {
    static let cleanFadeDurationSeconds = 5.0
    static let maximumDurationSeconds = 43_200.0

    func plan(
        targetDurationSeconds: Double?,
        requestedAudioLoopCount: Int? = nil,
        videoDurationSeconds: Double?,
        audioDurationSeconds: Double?,
        hasExternalAudio: Bool,
        cleanLoopEndingMode: Bool = true
    ) throws -> DurationPlan {
        if let targetDurationSeconds,
           !targetDurationSeconds.isFinite || targetDurationSeconds <= 0 {
            throw DurationPlannerError.invalidTargetDuration
        }
        if let requestedAudioLoopCount, requestedAudioLoopCount < 1 {
            throw DurationPlannerError.invalidTargetDuration
        }
        guard let videoDurationSeconds,
              videoDurationSeconds.isFinite,
              videoDurationSeconds > 0 else {
            throw DurationPlannerError.invalidVideoDuration
        }

        let finalDuration: Double
        let audioLoopCount: Int
        let explanation: String

        if hasExternalAudio {
            guard let audioDurationSeconds,
                  audioDurationSeconds.isFinite,
                  audioDurationSeconds > 0 else {
                throw DurationPlannerError.invalidAudioDuration
            }
            if cleanLoopEndingMode {
                if let requestedAudioLoopCount {
                    audioLoopCount = requestedAudioLoopCount
                    finalDuration = Double(requestedAudioLoopCount) * audioDurationSeconds
                    explanation = "Used the requested \(requestedAudioLoopCount) complete audio loops."
                } else if let targetDurationSeconds {
                    audioLoopCount = max(1, Int(ceil(targetDurationSeconds / audioDurationSeconds)))
                    finalDuration = Double(audioLoopCount) * audioDurationSeconds
                    explanation = finalDuration > targetDurationSeconds
                        ? "Extended to finish a complete audio loop cleanly."
                        : "The requested duration already ends on a complete audio loop."
                } else {
                    audioLoopCount = 1
                    finalDuration = audioDurationSeconds
                    explanation = "No target duration was requested, so one complete audio loop is used."
                }
            } else {
                finalDuration = targetDurationSeconds ?? audioDurationSeconds
                audioLoopCount = max(1, Int(ceil(finalDuration / audioDurationSeconds)))
                explanation = "Exact duration mode."
            }
        } else {
            let resolvedDuration = targetDurationSeconds ?? videoDurationSeconds
            finalDuration = resolvedDuration
            audioLoopCount = 0
            explanation = targetDurationSeconds == nil
                ? "No target duration or external audio was provided, so the video duration is used."
                : "The requested duration is used because no external audio was selected."
        }

        guard finalDuration <= Self.maximumDurationSeconds else {
            throw DurationPlannerError.durationExceedsLimit
        }
        let fadeDuration = min(Self.cleanFadeDurationSeconds, finalDuration)
        let fadeStart = max(0, finalDuration - fadeDuration)
        return DurationPlan(
            targetDurationSeconds: targetDurationSeconds,
            finalDurationSeconds: finalDuration,
            audioDurationSeconds: hasExternalAudio ? audioDurationSeconds : nil,
            audioLoopCount: audioLoopCount,
            videoShouldLoop: videoDurationSeconds < finalDuration,
            audioShouldLoop: hasExternalAudio && audioLoopCount > 1,
            audioFadeStartSeconds: hasExternalAudio ? fadeStart : nil,
            videoFadeStartSeconds: fadeStart,
            fadeDurationSeconds: fadeDuration,
            explanation: explanation
        )
    }
}
