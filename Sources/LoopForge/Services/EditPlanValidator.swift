import Foundation

struct EditPlanValidationError: LocalizedError, Equatable {
    let issues: [String]

    var errorDescription: String? {
        "The edit plan is not valid:\n" + issues.map { "• \($0)" }.joined(separator: "\n")
    }
}

struct EditPlanValidator {
    func validate(
        plan: EditPlan,
        assets: [MediaAsset],
        destinationFolder: URL,
        ffmpegPath: String?,
        ffprobePath: String?,
        exportSettings selection: ExportSettingsSelection = ExportSettingsSelection(
            resolution: .source,
            frameRate: .source,
            quality: .balanced,
            encodingSpeed: .balanced,
            audioBitrate: .kbps192,
            customWidthText: "1920",
            customHeightText: "1080"
        )
    ) throws -> ValidatedEditPlan {
        var issues: [String] = []
        let assetsByID = Dictionary(uniqueKeysWithValues: assets.map { ($0.id, $0) })

        guard assets.contains(where: { $0.type == .video }) else {
            throw EditPlanValidationError(issues: ["At least one video file is required."])
        }

        let baseVideo = assetsByID[plan.video.baseFileId]
        if baseVideo?.type != .video {
            issues.append("The base video file does not exist or is not a video.")
        }
        if let target = plan.output.targetDurationSeconds,
           !target.isFinite || target <= 0 {
            issues.append("Requested target duration must be greater than zero.")
        }
        if let loopCount = plan.output.requestedAudioLoopCount, loopCount < 1 {
            issues.append("Requested audio loop count must be at least one.")
        }
        if plan.output.format.lowercased() != "mp4" {
            issues.append("Only MP4 output is supported.")
        }
        guard let filename = FileHelpers.safeOutputFilename(plan.output.filename) else {
            issues.append("The output filename is not safe.")
            throw EditPlanValidationError(issues: issues)
        }

        var isDirectory: ObjCBool = false
        if !FileManager.default.fileExists(atPath: destinationFolder.path, isDirectory: &isDirectory) || !isDirectory.boolValue {
            issues.append("The destination folder does not exist.")
        } else if !FileManager.default.isWritableFile(atPath: destinationFolder.path) {
            issues.append("The destination folder is not writable.")
        }
        guard let ffmpegPath, FileManager.default.isExecutableFile(atPath: ffmpegPath) else {
            issues.append("FFmpeg was not found. Install FFmpeg or select its path in settings.")
            throw EditPlanValidationError(issues: issues)
        }
        guard let ffprobePath, FileManager.default.isExecutableFile(atPath: ffprobePath) else {
            issues.append("ffprobe was not found. Install FFmpeg or select ffprobe path in settings.")
            throw EditPlanValidationError(issues: issues)
        }

        if let resize = plan.video.resize {
            validateDimensions(width: resize.width, height: resize.height, label: "Resize", issues: &issues)
        }

        let resolvedExportSettings: ResolvedExportSettings
        do {
            resolvedExportSettings = try ExportSettingsResolver().resolve(
                selection: selection,
                sourceWidth: baseVideo?.width,
                sourceHeight: baseVideo?.height,
                sourceFPS: baseVideo?.frameRate
            )
        } catch {
            issues.append(error.localizedDescription)
            throw EditPlanValidationError(issues: issues)
        }

        var externalAudio: MediaAsset?
        if let audio = plan.audio {
            if [.replace, .mix].contains(audio.mode) {
                guard let id = audio.fileId, assetsByID[id]?.type == .audio else {
                    issues.append("The referenced audio file does not exist or is not audio.")
                    throw EditPlanValidationError(issues: issues)
                }
                externalAudio = assetsByID[id]
            }
            if audio.mode == .keepOriginal, assetsByID[plan.video.baseFileId]?.hasAudio != true {
                issues.append("The base video does not contain original audio to keep.")
            }
            if audio.mode == .mix, assetsByID[plan.video.baseFileId]?.hasAudio != true {
                issues.append("The base video does not contain original audio to mix.")
            }
            if let volume = audio.volume, (!volume.isFinite || volume < 0 || volume > 10) {
                issues.append("Audio volume must be between 0 and 10.")
            }
        }
        if plan.output.requestedAudioLoopCount != nil, externalAudio == nil {
            issues.append("An audio loop count requires an external audio file.")
        }

        for overlay in plan.overlays {
            if overlay.type != "image" || assetsByID[overlay.fileId]?.type != .image {
                issues.append("Every overlay must reference an uploaded image.")
            }
            if overlay.startSeconds < 0 {
                issues.append("Overlay start time cannot be negative.")
            }
            if let end = overlay.endSeconds, end <= overlay.startSeconds {
                issues.append("Overlay end time must be after its start time.")
            }
            if let opacity = overlay.opacity, (!opacity.isFinite || opacity < 0 || opacity > 1) {
                issues.append("Overlay opacity must be between 0 and 1.")
            }
            validateDimensions(width: overlay.width, height: overlay.height, label: "Overlay", issues: &issues)
        }

        let durationPlan: DurationPlan
        do {
            durationPlan = try DurationPlanner().plan(
                targetDurationSeconds: plan.output.targetDurationSeconds,
                requestedAudioLoopCount: plan.output.requestedAudioLoopCount,
                videoDurationSeconds: baseVideo?.durationSeconds,
                audioDurationSeconds: externalAudio?.durationSeconds,
                hasExternalAudio: externalAudio != nil,
                cleanLoopEndingMode: true
            )
        } catch {
            issues.append(error.localizedDescription)
            throw EditPlanValidationError(issues: issues)
        }

        for overlay in plan.overlays where overlay.startSeconds >= durationPlan.finalDurationSeconds {
            issues.append("Overlay start time must be before the output ends.")
        }

        for effect in plan.effects where effect.type == .fadeIn {
            if effect.startSeconds < 0 {
                issues.append("Fade start time cannot be negative.")
            }
            if !effect.durationSeconds.isFinite || effect.durationSeconds <= 0 {
                issues.append("Fade duration must be positive.")
            }
            if effect.startSeconds >= durationPlan.finalDurationSeconds {
                issues.append("Fade start time must be before the output ends.")
            }
        }

        if let start = plan.video.trimStartSeconds, start < 0 {
            issues.append("Video trim start cannot be negative.")
        }
        if let end = plan.video.trimEndSeconds,
           let start = plan.video.trimStartSeconds,
           end <= start {
            issues.append("Video trim end must be after trim start.")
        }

        guard issues.isEmpty else {
            throw EditPlanValidationError(issues: issues)
        }
        let outputURL = FileHelpers.uniqueOutputURL(folder: destinationFolder, filename: filename)
        return ValidatedEditPlan(
            plan: plan,
            durationPlan: durationPlan,
            exportSettings: resolvedExportSettings,
            assetsByID: assetsByID,
            destinationFolder: destinationFolder,
            outputURL: outputURL,
            ffmpegPath: ffmpegPath,
            ffprobePath: ffprobePath
        )
    }

    private func validateDimensions(width: Int?, height: Int?, label: String, issues: inout [String]) {
        for (name, value) in [("width", width), ("height", height)] {
            if let value, value < 16 || value > 16_384 {
                issues.append("\(label) \(name) must be between 16 and 16384 pixels.")
            } else if let value, value % 2 != 0 {
                issues.append("\(label) \(name) must be an even number for MP4 output.")
            }
        }
    }
}
