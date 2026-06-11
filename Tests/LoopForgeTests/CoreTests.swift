import Foundation
import XCTest
@testable import LoopForge

final class CoreTests: XCTestCase {
    @MainActor
    func testDestinationFolderPersistsAcrossSettingsInstances() throws {
        let suiteName = "LoopForgeTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated UserDefaults.")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("SavedDestination-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        SettingsStore(defaults: defaults).saveDestinationFolder(folder)
        let restored = SettingsStore(defaults: defaults).savedDestinationFolder()
        XCTAssertEqual(restored?.standardizedFileURL.path, folder.standardizedFileURL.path)
    }

    @MainActor
    func testExportSettingsPersistAcrossSettingsInstances() throws {
        let suiteName = "LoopForgeExportTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated UserDefaults.")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = SettingsStore(defaults: defaults)
        settings.exportResolution = .custom
        settings.exportFrameRate = .fps60
        settings.exportQuality = .high
        settings.exportEncodingSpeed = .bestCompression
        settings.exportAudioBitrate = .kbps320
        settings.customExportWidth = "2560"
        settings.customExportHeight = "1440"

        let restored = SettingsStore(defaults: defaults)
        XCTAssertEqual(restored.exportResolution, .custom)
        XCTAssertEqual(restored.exportFrameRate, .fps60)
        XCTAssertEqual(restored.exportQuality, .high)
        XCTAssertEqual(restored.exportEncodingSpeed, .bestCompression)
        XCTAssertEqual(restored.exportAudioBitrate, .kbps320)
        XCTAssertEqual(restored.customExportWidth, "2560")
        XCTAssertEqual(restored.customExportHeight, "1440")
    }

    @MainActor
    func testLegacySettingsMigrateOnceToLoopForgeDefaults() {
        let currentSuite = "LoopForgeMigrationCurrent-\(UUID().uuidString)"
        let legacySuite = "LoopForgeMigrationLegacy-\(UUID().uuidString)"
        guard let current = UserDefaults(suiteName: currentSuite),
              let legacy = UserDefaults(suiteName: legacySuite) else {
            XCTFail("Could not create isolated UserDefaults.")
            return
        }
        defer {
            current.removePersistentDomain(forName: currentSuite)
            legacy.removePersistentDomain(forName: legacySuite)
        }

        legacy.set(ExportResolution.fullHD.rawValue, forKey: "exportResolution")
        legacy.set(ExportFrameRate.fps60.rawValue, forKey: "exportFrameRate")
        legacy.set("/tmp/legacy-output", forKey: "destinationFolderPath")

        let migrated = SettingsStore(defaults: current, legacyDefaults: legacy)
        XCTAssertEqual(migrated.exportResolution, .fullHD)
        XCTAssertEqual(migrated.exportFrameRate, .fps60)

        legacy.set(ExportResolution.uhd4K.rawValue, forKey: "exportResolution")
        let secondLaunch = SettingsStore(defaults: current, legacyDefaults: legacy)
        XCTAssertEqual(secondLaunch.exportResolution, .fullHD)
    }

    func testBundledFFmpegTakesPrecedenceOverOverridesAndFallbacks() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LoopForgeBundledTools-\(UUID().uuidString)", isDirectory: true)
        let bin = folder.appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let bundledFFmpeg = bin.appendingPathComponent("ffmpeg")
        let bundledFFprobe = bin.appendingPathComponent("ffprobe")
        XCTAssertTrue(FileManager.default.createFile(atPath: bundledFFmpeg.path, contents: Data()))
        XCTAssertTrue(FileManager.default.createFile(atPath: bundledFFprobe.path, contents: Data()))
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: bundledFFmpeg.path
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: bundledFFprobe.path
        )

        let paths = FFmpegPathResolver.resolve(
            ffmpegOverride: "/usr/bin/true",
            ffprobeOverride: "/usr/bin/true",
            resourceURL: folder,
            ffmpegFallbacks: [],
            ffprobeFallbacks: []
        )
        XCTAssertEqual(paths.ffmpeg, bundledFFmpeg.path)
        XCTAssertEqual(paths.ffprobe, bundledFFprobe.path)
    }

    func testFFmpegResolverFallsBackToManualOverride() {
        let paths = FFmpegPathResolver.resolve(
            ffmpegOverride: "/usr/bin/true",
            ffprobeOverride: "/usr/bin/true",
            resourceURL: nil,
            ffmpegFallbacks: [],
            ffprobeFallbacks: []
        )
        XCTAssertEqual(paths.ffmpeg, "/usr/bin/true")
        XCTAssertEqual(paths.ffprobe, "/usr/bin/true")
    }

    func testLegacyKeychainValueMigratesToLoopForgeService() {
        let account = "migration-test-\(UUID().uuidString)"
        defer {
            KeychainStore.removeValue(for: account)
            KeychainStore.removeValue(for: account, service: KeychainStore.legacyService)
        }

        KeychainStore.set(
            "legacy-secret",
            for: account,
            service: KeychainStore.legacyService
        )
        KeychainStore.migrateLegacyValueIfNeeded(for: account)

        XCTAssertEqual(KeychainStore.value(for: account), "legacy-secret")
    }

    @MainActor
    func testClearRetainsExportSettings() {
        let suiteName = "LoopForgeClearTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated UserDefaults.")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = SettingsStore(defaults: defaults)
        settings.exportResolution = .fullHD
        settings.exportFrameRate = .fps60
        settings.exportQuality = .high
        settings.exportEncodingSpeed = .fast
        settings.exportAudioBitrate = .kbps256

        AppViewModel(settings: settings).clear()

        XCTAssertEqual(settings.exportResolution, .fullHD)
        XCTAssertEqual(settings.exportFrameRate, .fps60)
        XCTAssertEqual(settings.exportQuality, .high)
        XCTAssertEqual(settings.exportEncodingSpeed, .fast)
        XCTAssertEqual(settings.exportAudioBitrate, .kbps256)
    }

    func testExportPresetMappings() {
        XCTAssertEqual(ExportResolution.uhd4K.dimensions?.width, 3840)
        XCTAssertEqual(ExportResolution.uhd4K.dimensions?.height, 2160)
        XCTAssertEqual(ExportResolution.fullHD.dimensions?.width, 1920)
        XCTAssertEqual(ExportResolution.fullHD.dimensions?.height, 1080)
        XCTAssertEqual(ExportResolution.hd.dimensions?.width, 1280)
        XCTAssertEqual(ExportResolution.hd.dimensions?.height, 720)

        XCTAssertEqual(ExportFrameRate.fps24.value, 24)
        XCTAssertEqual(ExportFrameRate.fps25.value, 25)
        XCTAssertEqual(ExportFrameRate.fps30.value, 30)
        XCTAssertEqual(ExportFrameRate.fps50.value, 50)
        XCTAssertEqual(ExportFrameRate.fps60.value, 60)

        XCTAssertEqual(ExportQuality.high.crf, 18)
        XCTAssertEqual(ExportQuality.balanced.crf, 20)
        XCTAssertEqual(ExportQuality.smallFile.crf, 24)
        XCTAssertEqual(ExportEncodingSpeed.fast.ffmpegPreset, "fast")
        XCTAssertEqual(ExportEncodingSpeed.balanced.ffmpegPreset, "medium")
        XCTAssertEqual(ExportEncodingSpeed.bestCompression.ffmpegPreset, "slow")
        XCTAssertEqual(ExportAudioBitrate.kbps128.ffmpegValue, "128k")
        XCTAssertEqual(ExportAudioBitrate.kbps192.ffmpegValue, "192k")
        XCTAssertEqual(ExportAudioBitrate.kbps256.ffmpegValue, "256k")
        XCTAssertEqual(ExportAudioBitrate.kbps320.ffmpegValue, "320k")
    }

    func testYouTubePresetMappings() {
        XCTAssertEqual(YouTubeExportPreset.uhd4K.resolution, .uhd4K)
        XCTAssertEqual(YouTubeExportPreset.fullHD.resolution, .fullHD)

        for preset in YouTubeExportPreset.allCases {
            XCTAssertEqual(preset.frameRate, .source)
            XCTAssertEqual(preset.quality, .high)
            XCTAssertEqual(preset.encodingSpeed, .bestCompression)
            XCTAssertEqual(preset.audioBitrate, .kbps320)
        }
    }

    @MainActor
    func testApplyingYouTubePresetUpdatesAndPersistsSettings() {
        let suiteName = "LoopForgeYouTubePresetTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated UserDefaults.")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = SettingsStore(defaults: defaults)
        settings.applyYouTubePreset(.uhd4K)

        XCTAssertEqual(settings.exportResolution, .uhd4K)
        XCTAssertEqual(settings.exportFrameRate, .source)
        XCTAssertEqual(settings.exportQuality, .high)
        XCTAssertEqual(settings.exportEncodingSpeed, .bestCompression)
        XCTAssertEqual(settings.exportAudioBitrate, .kbps320)

        let restored = SettingsStore(defaults: defaults)
        XCTAssertEqual(restored.exportResolution, .uhd4K)
        XCTAssertEqual(restored.exportFrameRate, .source)
        XCTAssertEqual(restored.exportQuality, .high)
        XCTAssertEqual(restored.exportEncodingSpeed, .bestCompression)
        XCTAssertEqual(restored.exportAudioBitrate, .kbps320)

        restored.exportFrameRate = .fps30
        XCTAssertEqual(restored.exportFrameRate, .fps30)
    }

    func testExportSettingsResolveSourceValuesAndUpscaling() throws {
        let source = try ExportSettingsResolver().resolve(
            selection: exportSelection(),
            sourceWidth: 320,
            sourceHeight: 180,
            sourceFPS: 23.976
        )
        XCTAssertEqual(source.width, 320)
        XCTAssertEqual(source.height, 180)
        XCTAssertEqual(source.fps, 23.976, accuracy: 0.001)
        XCTAssertFalse(source.isUpscaling)

        let upscaled = try ExportSettingsResolver().resolve(
            selection: exportSelection(resolution: .fullHD, frameRate: .fps30),
            sourceWidth: 1280,
            sourceHeight: 720,
            sourceFPS: 24
        )
        XCTAssertEqual(upscaled.width, 1920)
        XCTAssertEqual(upscaled.height, 1080)
        XCTAssertEqual(upscaled.fps, 30)
        XCTAssertTrue(upscaled.isUpscaling)
    }

    func testCustomExportDimensionsAreStrictlyValidated() {
        let resolver = ExportSettingsResolver()
        for selection in [
            exportSelection(resolution: .custom, customWidth: "", customHeight: "1080"),
            exportSelection(resolution: .custom, customWidth: "1919", customHeight: "1080"),
            exportSelection(resolution: .custom, customWidth: "8", customHeight: "1080"),
            exportSelection(resolution: .custom, customWidth: "20000", customHeight: "1080")
        ] {
            XCTAssertThrowsError(
                try resolver.resolve(
                    selection: selection,
                    sourceWidth: 320,
                    sourceHeight: 180,
                    sourceFPS: 24
                )
            )
        }
    }

    func testPromptRefinementDecoderAcceptsFencedJSON() throws {
        let response = """
        ```json
        {"refined_prompt":"Use @video.mp4 as the video and play @music.mp3 5 complete times."}
        ```
        """
        XCTAssertEqual(
            try PromptRefinementDecoder.decode(response),
            "Use @video.mp4 as the video and play @music.mp3 5 complete times."
        )
    }

    func testPromptRefinementRequestPreservesUploadedFilenames() throws {
        let request = PromptRefinementRequest(
            userPrompt: "Make something with @video.mp4.",
            assets: [videoAsset(), audioAsset()],
            failureReason: "Invalid plan",
            unsupportedRequests: ["unsupported action"]
        )
        let message = try PromptRefinementPromptBuilder.userMessage(for: request)
        XCTAssertTrue(message.contains("video.mp4"))
        XCTAssertTrue(message.contains("audio.m4a"))
        XCTAssertTrue(message.contains("unsupported action"))
    }

    func testLLMIntentSchemaDoesNotContainFinalDurationOrCommands() throws {
        let json = """
        {
          "summary": "Create a long clean loop.",
          "target_duration_seconds": 18000,
          "video_file_id": "video",
          "audio_file_id": "audio",
          "overlays": [],
          "unsupported_requests": [],
          "assumptions": []
        }
        """
        let intent = try EditIntentDecoder.decode(json)
        XCTAssertEqual(intent.targetDurationSeconds, 18_000)
        XCTAssertEqual(intent.videoFileId, "video")
        XCTAssertEqual(intent.audioFileId, "audio")
    }

    func testTolerantIntentDecoderAcceptsFencedJSONFilenamesAndMissingArrays() throws {
        let response = """
        Here is the plan:
        ```json
        {
          "description": "Loop the requested files.",
          "video_filename": "@video.mp4",
          "music_filename": "music.mp3",
          "audio_loop_count": "5"
        }
        ```
        """
        let intent = try EditIntentDecoder.decode(response)
        XCTAssertEqual(intent.videoFileId, "@video.mp4")
        XCTAssertEqual(intent.audioFileId, "music.mp3")
        XCTAssertEqual(intent.requestedAudioLoopCount, 5)
        XCTAssertEqual(intent.overlays, [])
        XCTAssertEqual(intent.unsupportedRequests, [])
    }

    func testTolerantIntentDecoderAcceptsLegacyNestedPlan() throws {
        let response = """
        {
          "summary": "Legacy response",
          "output": {"duration_seconds": 300},
          "video": {"base_file_id": "video"},
          "audio": {"mode": "replace", "file_id": "audio"},
          "overlays": [],
          "effects": [],
          "unsupported_requests": [],
          "assumptions": []
        }
        """
        let intent = try EditIntentDecoder.decode(response)
        XCTAssertEqual(intent.targetDurationSeconds, 300)
        XCTAssertEqual(intent.videoFileId, "video")
        XCTAssertEqual(intent.audioFileId, "audio")
    }

    func testPromptParserFindsRequestedMusicLoopCount() {
        let prompt = """
        @music.mp3 is the music.
        @video.mp4 is the video.
        I want a final combined video where the music is looped 5 times.
        """
        XCTAssertEqual(UserPromptIntentParser.requestedAudioLoopCount(from: prompt), 5)
    }

    func testExplicitFiveAudioLoopsDetermineFinalDuration() throws {
        let durationPlan = try DurationPlanner().plan(
            targetDurationSeconds: nil,
            requestedAudioLoopCount: 5,
            videoDurationSeconds: 10,
            audioDurationSeconds: 780,
            hasExternalAudio: true
        )
        XCTAssertEqual(durationPlan.audioLoopCount, 5)
        XCTAssertEqual(durationPlan.finalDurationSeconds, 3_900)
        XCTAssertEqual(durationPlan.videoFadeStartSeconds, 3_895)
        XCTAssertEqual(durationPlan.audioFadeStartSeconds, 3_895)
        XCTAssertTrue(durationPlan.videoShouldLoop)
        XCTAssertTrue(durationPlan.audioShouldLoop)
    }

    func testOutputFilenameNormalizationAndValidation() {
        XCTAssertEqual(FileHelpers.safeOutputFilename("my finished video"), "my finished video.mp4")
        XCTAssertEqual(FileHelpers.safeOutputFilename("custom-name.MP4"), "custom-name.MP4")
        XCTAssertNil(FileHelpers.safeOutputFilename("../escape.mp4"))
        XCTAssertNil(FileHelpers.safeOutputFilename("folder/output.mp4"))
    }

    func testProgressParser() {
        let seconds = ProgressParser.seconds(from: "frame=12 fps=30 time=01:02:03.50 bitrate=1k")
        XCTAssertNotNil(seconds)
        XCTAssertEqual(seconds!, 3723.5, accuracy: 0.001)
        let carriageReturnSeconds = ProgressParser.seconds(
            from: "frame=1\rframe=2 time=00:00:01.25 speed=1x"
        )
        XCTAssertNotNil(carriageReturnSeconds)
        XCTAssertEqual(carriageReturnSeconds!, 1.25, accuracy: 0.001)
        XCTAssertNil(ProgressParser.seconds(from: "no progress here"))
    }

    func testCleanLoopEndingFiveHourAcceptanceCase() throws {
        let durationPlan = try DurationPlanner().plan(
            targetDurationSeconds: 5 * 60 * 60,
            videoDurationSeconds: 10,
            audioDurationSeconds: 13 * 60,
            hasExternalAudio: true
        )

        XCTAssertEqual(durationPlan.audioLoopCount, 24)
        XCTAssertEqual(durationPlan.finalDurationSeconds, 312 * 60, accuracy: 0.001)
        XCTAssertTrue(durationPlan.videoShouldLoop)
        XCTAssertTrue(durationPlan.audioShouldLoop)
        XCTAssertEqual(durationPlan.audioFadeStartSeconds!, 312 * 60 - 5, accuracy: 0.001)
        XCTAssertEqual(durationPlan.videoFadeStartSeconds, 312 * 60 - 5, accuracy: 0.001)
        XCTAssertEqual(durationPlan.fadeDurationSeconds, 5)
        XCTAssertTrue(durationPlan.explanation.localizedCaseInsensitiveContains("complete audio loop"))
    }

    func testDurationPlannerFallbackRules() throws {
        let audioOnlyTarget = try DurationPlanner().plan(
            targetDurationSeconds: nil,
            videoDurationSeconds: 10,
            audioDurationSeconds: 780,
            hasExternalAudio: true
        )
        XCTAssertEqual(audioOnlyTarget.finalDurationSeconds, 780)
        XCTAssertEqual(audioOnlyTarget.audioLoopCount, 1)

        let requestedVideoOnly = try DurationPlanner().plan(
            targetDurationSeconds: 600,
            videoDurationSeconds: 10,
            audioDurationSeconds: nil,
            hasExternalAudio: false
        )
        XCTAssertEqual(requestedVideoOnly.finalDurationSeconds, 600)
        XCTAssertTrue(requestedVideoOnly.videoShouldLoop)

        let sourceVideoOnly = try DurationPlanner().plan(
            targetDurationSeconds: nil,
            videoDurationSeconds: 10,
            audioDurationSeconds: nil,
            hasExternalAudio: false
        )
        XCTAssertEqual(sourceVideoOnly.finalDurationSeconds, 10)
        XCTAssertFalse(sourceVideoOnly.videoShouldLoop)
    }

    func testCleanLoopCommandUsesCalculatedDurationAndFiniteAudioLoops() throws {
        let video = videoAsset(duration: 10)
        let audio = audioAsset(duration: 13 * 60)
        let plan = EditPlan(
            summary: "Create a five hour video.",
            output: OutputSettings(
                format: "mp4",
                filename: "five-hours.mp4",
                targetDurationSeconds: 5 * 60 * 60,
                requestedAudioLoopCount: nil,
                width: 320,
                height: 180,
                fps: 24
            ),
            video: VideoPlan(
                baseFileId: video.id,
                loop: false,
                trimStartSeconds: nil,
                trimEndSeconds: nil,
                resize: nil,
                preserveAspectRatio: true
            ),
            audio: AudioPlan(
                mode: .replace,
                fileId: audio.id,
                loop: false,
                trimToOutputDuration: false,
                keepOriginalAudio: false,
                volume: 1
            ),
            overlays: [],
            effects: [],
            unsupportedRequests: [],
            assumptions: []
        )
        let validated = try EditPlanValidator().validate(
            plan: plan,
            assets: [video, audio],
            destinationFolder: FileManager.default.temporaryDirectory,
            ffmpegPath: "/usr/bin/true",
            ffprobePath: "/usr/bin/true"
        )
        let command = try FFmpegCommandBuilder().build(from: validated)
        let filterGraph = command.arguments[command.arguments.firstIndex(of: "-filter_complex")! + 1]

        XCTAssertEqual(command.durationSeconds, 312 * 60, accuracy: 0.001)
        XCTAssertTrue(command.arguments.contains("23"))
        XCTAssertEqual(
            command.arguments[command.arguments.firstIndex(of: "-t")! + 1],
            "18720.000"
        )
        XCTAssertTrue(filterGraph.contains("fade=t=out:st=18715.000:d=5.000"))
        XCTAssertTrue(filterGraph.contains("afade=t=out:st=18715.000:d=5.000"))
        XCTAssertTrue(filterGraph.contains("atrim=duration=18720.000"))
        XCTAssertFalse(command.arguments.contains("18000.000"))
    }

    func testValidatorRejectsInventedOverlay() throws {
        let folder = FileManager.default.temporaryDirectory
        let plan = makePlan(overlays: [
            OverlayPlan(
                type: "image",
                fileId: "missing",
                position: .topRight,
                xMargin: 40,
                yMargin: 40,
                width: 180,
                height: nil,
                startSeconds: 0,
                endSeconds: 1,
                opacity: 1
            )
        ])

        XCTAssertThrowsError(
            try EditPlanValidator().validate(
                plan: plan,
                assets: [videoAsset()],
                destinationFolder: folder,
                ffmpegPath: "/usr/bin/true",
                ffprobePath: "/usr/bin/true"
            )
        ) { error in
            XCTAssertTrue(error.localizedDescription.contains("overlay"))
        }
    }

    func testCommandBuilderUsesArgumentArrayAndExpectedFilters() throws {
        let folder = FileManager.default.temporaryDirectory
        let video = videoAsset()
        let audio = audioAsset()
        let image = imageAsset()
        let plan = EditPlan(
            summary: "Loop with audio, overlay, and fade.",
            output: OutputSettings(
                format: "mp4",
                filename: "test-output.mp4",
                targetDurationSeconds: 10,
                requestedAudioLoopCount: nil,
                width: 1280,
                height: 720,
                fps: 30
            ),
            video: VideoPlan(
                baseFileId: video.id,
                loop: true,
                trimStartSeconds: nil,
                trimEndSeconds: nil,
                resize: ResizeSettings(width: 1280, height: 720),
                preserveAspectRatio: true
            ),
            audio: AudioPlan(
                mode: .replace,
                fileId: audio.id,
                loop: true,
                trimToOutputDuration: true,
                keepOriginalAudio: false,
                volume: 1
            ),
            overlays: [
                OverlayPlan(
                    type: "image",
                    fileId: image.id,
                    position: .bottomRight,
                    xMargin: 20,
                    yMargin: 30,
                    width: 100,
                    height: nil,
                    startSeconds: 0,
                    endSeconds: 5,
                    opacity: 0.8
                )
            ],
            effects: [
                EffectPlan(type: .fadeOutToBlack, startSeconds: 8, durationSeconds: 2)
            ],
            unsupportedRequests: [],
            assumptions: []
        )
        let validated = try EditPlanValidator().validate(
            plan: plan,
            assets: [video, audio, image],
            destinationFolder: folder,
            ffmpegPath: "/usr/bin/true",
            ffprobePath: "/usr/bin/true",
            exportSettings: exportSelection(
                resolution: .fullHD,
                frameRate: .fps60,
                quality: .smallFile,
                speed: .bestCompression,
                audioBitrate: .kbps320
            )
        )
        let command = try FFmpegCommandBuilder().build(from: validated)

        XCTAssertEqual(command.executablePath, "/usr/bin/true")
        XCTAssertTrue(command.arguments.contains("-stream_loop"))
        XCTAssertTrue(command.arguments.contains("-filter_complex"))
        let graph = command.arguments[command.arguments.firstIndex(of: "-filter_complex")! + 1]
        XCTAssertTrue(graph.contains("overlay=main_w-overlay_w-20:main_h-overlay_h-30"))
        XCTAssertTrue(graph.contains("fade=t=out"))
        XCTAssertTrue(graph.contains("scale=1920:1080:force_original_aspect_ratio=decrease"))
        XCTAssertTrue(graph.contains("pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black"))
        XCTAssertEqual(command.arguments[command.arguments.firstIndex(of: "-crf")! + 1], "24")
        XCTAssertEqual(command.arguments[command.arguments.firstIndex(of: "-preset")! + 1], "slow")
        XCTAssertEqual(command.arguments[command.arguments.firstIndex(of: "-b:a")! + 1], "320k")
        XCTAssertEqual(command.arguments[command.arguments.firstIndex(of: "-r")! + 1], "60.000")
        XCTAssertFalse(command.arguments.contains("/bin/bash"))
        XCTAssertFalse(command.arguments.contains("-c \""))
    }

    func testRealFFprobeAndRenderPipeline() async throws {
        let vendorResources = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Vendor/ffmpeg/arm64", isDirectory: true)
        let paths = FFmpegPathResolver.resolve(resourceURL: vendorResources)
        guard let ffmpeg = paths.ffmpeg, let ffprobe = paths.ffprobe else {
            throw XCTSkip("FFmpeg is not installed.")
        }

        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LoopForgeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let videoURL = folder.appendingPathComponent("video.mp4")
        let audioURL = folder.appendingPathComponent("music.m4a")
        let logoURL = folder.appendingPathComponent("logo.png")

        try await runTool(ffmpeg, [
            "-hide_banner", "-loglevel", "error", "-y",
            "-f", "lavfi", "-i", "color=c=blue:s=320x180:d=1:r=24",
            "-c:v", "libx264", "-pix_fmt", "yuv420p", videoURL.path
        ])
        try await runTool(ffmpeg, [
            "-hide_banner", "-loglevel", "error", "-y",
            "-f", "lavfi", "-i", "sine=frequency=440:duration=2",
            "-c:a", "aac", audioURL.path
        ])
        try await runTool(ffmpeg, [
            "-hide_banner", "-loglevel", "error", "-y",
            "-f", "lavfi", "-i", "color=c=white@0.8:s=40x40:d=1",
            "-frames:v", "1", logoURL.path
        ])

        let analyzer = MediaAnalyzer(ffprobePath: ffprobe)
        let video = try await analyzer.analyze(url: videoURL, id: "video")
        let audio = try await analyzer.analyze(url: audioURL, id: "audio")
        let logo = try await analyzer.analyze(url: logoURL, id: "logo")
        XCTAssertEqual(video.type, .video)
        XCTAssertEqual(audio.type, .audio)
        XCTAssertEqual(logo.type, .image)

        let plan = EditPlan(
            summary: "Acceptance render.",
            output: OutputSettings(
                format: "mp4",
                filename: "acceptance.mp4",
                targetDurationSeconds: 2,
                requestedAudioLoopCount: nil,
                width: 320,
                height: 180,
                fps: 24
            ),
            video: VideoPlan(
                baseFileId: video.id,
                loop: true,
                trimStartSeconds: nil,
                trimEndSeconds: nil,
                resize: ResizeSettings(width: 320, height: 180),
                preserveAspectRatio: true
            ),
            audio: AudioPlan(
                mode: .replace,
                fileId: audio.id,
                loop: false,
                trimToOutputDuration: true,
                keepOriginalAudio: false,
                volume: 1
            ),
            overlays: [
                OverlayPlan(
                    type: "image",
                    fileId: logo.id,
                    position: .topRight,
                    xMargin: 10,
                    yMargin: 10,
                    width: 40,
                    height: 40,
                    startSeconds: 0,
                    endSeconds: 1,
                    opacity: 0.8
                )
            ],
            effects: [
                EffectPlan(type: .fadeOutToBlack, startSeconds: 1.5, durationSeconds: 0.5)
            ],
            unsupportedRequests: [],
            assumptions: []
        )

        let validated = try EditPlanValidator().validate(
            plan: plan,
            assets: [video, audio, logo],
            destinationFolder: folder,
            ffmpegPath: ffmpeg,
            ffprobePath: ffprobe,
            exportSettings: exportSelection(
                resolution: .custom,
                frameRate: .fps30,
                quality: .high,
                speed: .fast,
                audioBitrate: .kbps256,
                customWidth: "640",
                customHeight: "360"
            )
        )
        let command = try FFmpegCommandBuilder().build(from: validated)
        var latestProgress = 0.0
        try await FFmpegRunner().run(
            command: command,
            onProgress: { progress, _ in latestProgress = max(latestProgress, progress) },
            onLog: { _ in }
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: command.outputURL.path))
        XCTAssertGreaterThan(latestProgress, 0.99)
        let rendered = try await analyzer.analyze(url: command.outputURL, id: "rendered")
        XCTAssertEqual(rendered.type, .video)
        XCTAssertEqual(rendered.width, 640)
        XCTAssertEqual(rendered.height, 360)
        XCTAssertEqual(rendered.frameRate ?? 0, 30, accuracy: 0.1)
        XCTAssertEqual(rendered.hasAudio, true)
        XCTAssertEqual(rendered.durationSeconds ?? 0, 2, accuracy: 0.15)
    }

    private func runTool(_ executable: String, _ arguments: [String]) async throws {
        let result = try await ProcessExecutor.run(executablePath: executable, arguments: arguments)
        guard result.terminationStatus == 0 else {
            XCTFail(String(decoding: result.standardError, as: UTF8.self))
            throw CocoaError(.fileWriteUnknown)
        }
    }

    private func makePlan(overlays: [OverlayPlan] = []) -> EditPlan {
        EditPlan(
            summary: "Test",
            output: OutputSettings(
                format: "mp4",
                filename: "output.mp4",
                targetDurationSeconds: 5,
                requestedAudioLoopCount: nil,
                width: 320,
                height: 180,
                fps: 24
            ),
            video: VideoPlan(
                baseFileId: "video",
                loop: false,
                trimStartSeconds: nil,
                trimEndSeconds: nil,
                resize: nil,
                preserveAspectRatio: true
            ),
            audio: nil,
            overlays: overlays,
            effects: [],
            unsupportedRequests: [],
            assumptions: []
        )
    }

    private func videoAsset(duration: Double = 5) -> MediaAsset {
        MediaAsset(
            id: "video",
            filename: "video.mp4",
            path: "/tmp/video.mp4",
            type: .video,
            durationSeconds: duration,
            width: 320,
            height: 180,
            frameRate: 24,
            videoCodec: "h264",
            audioCodec: nil,
            hasAudio: false,
            sampleRate: nil,
            channels: nil,
            fileSizeBytes: 100
        )
    }

    private func audioAsset(duration: Double = 10) -> MediaAsset {
        MediaAsset(
            id: "audio",
            filename: "audio.m4a",
            path: "/tmp/audio.m4a",
            type: .audio,
            durationSeconds: duration,
            width: nil,
            height: nil,
            frameRate: nil,
            videoCodec: nil,
            audioCodec: "aac",
            hasAudio: nil,
            sampleRate: 44_100,
            channels: 2,
            fileSizeBytes: 100
        )
    }

    private func imageAsset() -> MediaAsset {
        MediaAsset(
            id: "image",
            filename: "logo.png",
            path: "/tmp/logo.png",
            type: .image,
            durationSeconds: nil,
            width: 100,
            height: 100,
            frameRate: nil,
            videoCodec: "png",
            audioCodec: nil,
            hasAudio: nil,
            sampleRate: nil,
            channels: nil,
            fileSizeBytes: 100
        )
    }

    private func exportSelection(
        resolution: ExportResolution = .source,
        frameRate: ExportFrameRate = .source,
        quality: ExportQuality = .balanced,
        speed: ExportEncodingSpeed = .balanced,
        audioBitrate: ExportAudioBitrate = .kbps192,
        customWidth: String = "1920",
        customHeight: String = "1080"
    ) -> ExportSettingsSelection {
        ExportSettingsSelection(
            resolution: resolution,
            frameRate: frameRate,
            quality: quality,
            encodingSpeed: speed,
            audioBitrate: audioBitrate,
            customWidthText: customWidth,
            customHeightText: customHeight
        )
    }
}
