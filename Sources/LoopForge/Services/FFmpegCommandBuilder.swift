import Foundation

enum FFmpegCommandBuilderError: LocalizedError {
    case missingAsset(String)

    var errorDescription: String? {
        switch self {
        case .missingAsset(let id):
            return "The validated plan references a missing asset: \(id)"
        }
    }
}

struct FFmpegCommandBuilder {
    func build(from validated: ValidatedEditPlan) throws -> FFmpegCommand {
        let plan = validated.plan
        guard let baseVideo = validated.assetsByID[plan.video.baseFileId] else {
            throw FFmpegCommandBuilderError.missingAsset(plan.video.baseFileId)
        }

        var arguments = ["-hide_banner", "-nostdin", "-y"]
        if validated.durationPlan.videoShouldLoop {
            arguments += ["-stream_loop", "-1"]
        }
        if let start = plan.video.trimStartSeconds {
            arguments += ["-ss", TimeFormatter.ffmpeg(start)]
        }
        if let end = plan.video.trimEndSeconds {
            arguments += ["-to", TimeFormatter.ffmpeg(end)]
        }
        arguments += ["-i", baseVideo.path]

        var nextInputIndex = 1
        var externalAudioIndex: Int?
        if let audio = plan.audio, [.replace, .mix].contains(audio.mode), let audioID = audio.fileId {
            guard let asset = validated.assetsByID[audioID] else {
                throw FFmpegCommandBuilderError.missingAsset(audioID)
            }
            if validated.durationPlan.audioLoopCount > 1 {
                arguments += ["-stream_loop", "\(validated.durationPlan.audioLoopCount - 1)"]
            }
            arguments += ["-i", asset.path]
            externalAudioIndex = nextInputIndex
            nextInputIndex += 1
        }

        var overlayInputIndices: [Int] = []
        for overlay in plan.overlays {
            guard let asset = validated.assetsByID[overlay.fileId] else {
                throw FFmpegCommandBuilderError.missingAsset(overlay.fileId)
            }
            arguments += ["-loop", "1", "-i", asset.path]
            overlayInputIndices.append(nextInputIndex)
            nextInputIndex += 1
        }

        var filters: [String] = []
        var currentVideo = "[0:v]"
        var videoFilterNumber = 0

        func appendVideoFilter(_ expression: String) {
            let output = "[v\(videoFilterNumber)]"
            filters.append("\(currentVideo)\(expression)\(output)")
            currentVideo = output
            videoFilterNumber += 1
        }

        let exportWidth = validated.exportSettings.width
        let exportHeight = validated.exportSettings.height
        appendVideoFilter(
            "scale=\(exportWidth):\(exportHeight):force_original_aspect_ratio=decrease," +
            "pad=\(exportWidth):\(exportHeight):(ow-iw)/2:(oh-ih)/2:black"
        )

        for effect in plan.effects where effect.type == .fadeIn {
            appendVideoFilter(
                "fade=t=in:st=\(TimeFormatter.ffmpeg(effect.startSeconds)):" +
                "d=\(TimeFormatter.ffmpeg(effect.durationSeconds))"
            )
        }

        for (offset, overlay) in plan.overlays.enumerated() {
            let inputIndex = overlayInputIndices[offset]
            var overlayChain: [String] = []
            if overlay.width != nil || overlay.height != nil {
                let width = overlay.width.map(String.init) ?? "-1"
                let height = overlay.height.map(String.init) ?? "-1"
                overlayChain.append("scale=\(width):\(height)")
            }
            if let opacity = overlay.opacity, opacity < 1 {
                overlayChain += ["format=rgba", "colorchannelmixer=aa=\(format(opacity))"]
            }

            let overlayLabel: String
            if overlayChain.isEmpty {
                overlayLabel = "[\(inputIndex):v]"
            } else {
                overlayLabel = "[ov\(offset)]"
                filters.append("[\(inputIndex):v]\(overlayChain.joined(separator: ","))\(overlayLabel)")
            }

            let output = "[v\(videoFilterNumber)]"
            let position = overlayPosition(overlay)
            let enable: String
            if let end = overlay.endSeconds {
                enable = "between(t\\,\(format(overlay.startSeconds))\\,\(format(end)))"
            } else {
                enable = "gte(t\\,\(format(overlay.startSeconds)))"
            }
            filters.append("\(currentVideo)\(overlayLabel)overlay=\(position):enable=\(enable)\(output)")
            currentVideo = output
            videoFilterNumber += 1
        }

        appendVideoFilter(
            "fade=t=out:st=\(TimeFormatter.ffmpeg(validated.durationPlan.videoFadeStartSeconds)):" +
            "d=\(TimeFormatter.ffmpeg(validated.durationPlan.fadeDurationSeconds))"
        )

        var audioMap: String?
        if let audio = plan.audio {
            switch audio.mode {
            case .replace:
                if let externalAudioIndex {
                    var chain: [String] = []
                    if let volume = audio.volume, volume != 1 {
                        chain.append("volume=\(format(volume))")
                    }
                    chain += [
                        "atrim=duration=\(TimeFormatter.ffmpeg(validated.durationPlan.finalDurationSeconds))",
                        "asetpts=PTS-STARTPTS"
                    ]
                    if let fadeStart = validated.durationPlan.audioFadeStartSeconds {
                        chain.append(
                            "afade=t=out:st=\(TimeFormatter.ffmpeg(fadeStart)):" +
                            "d=\(TimeFormatter.ffmpeg(validated.durationPlan.fadeDurationSeconds))"
                        )
                    }
                    filters.append("[\(externalAudioIndex):a]\(chain.joined(separator: ","))[aout]")
                    audioMap = "[aout]"
                }
            case .keepOriginal:
                audioMap = "0:a?"
            case .mix:
                if let externalAudioIndex {
                    let volume = audio.volume ?? 1
                    filters.append("[\(externalAudioIndex):a]volume=\(format(volume))[external_audio]")
                    filters.append("[0:a][external_audio]amix=inputs=2:duration=longest:dropout_transition=2," +
                                   "atrim=duration=\(TimeFormatter.ffmpeg(validated.durationPlan.finalDurationSeconds))," +
                                   "afade=t=out:st=\(TimeFormatter.ffmpeg(validated.durationPlan.audioFadeStartSeconds ?? 0)):" +
                                   "d=\(TimeFormatter.ffmpeg(validated.durationPlan.fadeDurationSeconds))," +
                                   "asetpts=PTS-STARTPTS[aout]")
                    audioMap = "[aout]"
                }
            case .none:
                audioMap = nil
            }
        }

        if !filters.isEmpty {
            arguments += ["-filter_complex", filters.joined(separator: ";")]
        }
        arguments += ["-map", currentVideo == "[0:v]" ? "0:v:0" : currentVideo]
        if let audioMap {
            arguments += [
                "-map", audioMap,
                "-c:a", "aac",
                "-b:a", validated.exportSettings.audioBitrate.ffmpegValue
            ]
        } else {
            arguments += ["-an"]
        }

        arguments += [
            "-c:v", "libx264",
            "-preset", validated.exportSettings.encodingSpeed.ffmpegPreset,
            "-crf", "\(validated.exportSettings.quality.crf)",
            "-pix_fmt", "yuv420p",
            "-r", format(validated.exportSettings.fps)
        ]
        arguments += [
            "-t", TimeFormatter.ffmpeg(validated.durationPlan.finalDurationSeconds),
            "-movflags", "+faststart",
            validated.outputURL.path
        ]

        return FFmpegCommand(
            executablePath: validated.ffmpegPath,
            arguments: arguments,
            outputURL: validated.outputURL,
            durationSeconds: validated.durationPlan.finalDurationSeconds
        )
    }

    private func overlayPosition(_ overlay: OverlayPlan) -> String {
        let x = overlay.xMargin
        let y = overlay.yMargin
        switch overlay.position {
        case .topLeft:
            return "\(x):\(y)"
        case .topRight:
            return "main_w-overlay_w-\(x):\(y)"
        case .bottomLeft:
            return "\(x):main_h-overlay_h-\(y)"
        case .bottomRight:
            return "main_w-overlay_w-\(x):main_h-overlay_h-\(y)"
        case .center:
            return "(main_w-overlay_w)/2:(main_h-overlay_h)/2"
        }
    }

    private func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}
