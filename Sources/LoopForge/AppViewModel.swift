import AppKit
import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published var assets: [MediaAsset] = []
    @Published var prompt = ""
    @Published var destinationFolder: URL
    @Published var outputFilename = "loopforge-output.mp4"
    @Published var state: AppState = .idle
    @Published var editPlan: EditPlan?
    @Published var validatedPlan: ValidatedEditPlan?
    @Published var progress = 0.0
    @Published var processedSeconds = 0.0
    @Published var outputURL: URL?
    @Published var errorMessage: String?
    @Published var showLogs = false
    @Published var showSettings = false
    @Published var isDropTargeted = false
    @Published var isRefiningPrompt = false
    @Published var showReadinessMessage = false
    @Published var openAIKey: String {
        didSet { KeychainStore.set(openAIKey, for: "openai") }
    }
    @Published var openRouterKey: String {
        didSet { KeychainStore.set(openRouterKey, for: "openrouter") }
    }

    let settings: SettingsStore
    let logs = LogStore()

    private let runner = FFmpegRunner()
    private var promptFailureReason: String?
    private var unsupportedPromptRequests: [String] = []

    init(settings: SettingsStore? = nil) {
        let settings = settings ?? SettingsStore()
        self.settings = settings
        destinationFolder = settings.savedDestinationFolder() ?? FileHelpers.defaultDestinationFolder()
        KeychainStore.migrateLegacyValueIfNeeded(for: "openai")
        KeychainStore.migrateLegacyValueIfNeeded(for: "openrouter")
        openAIKey = KeychainStore.value(for: "openai")
        openRouterKey = KeychainStore.value(for: "openrouter")
        showReadinessMessage = settings.shouldShowReadinessMessage
        let paths = resolvedPaths
        logs.append("App started.")
        logs.append("FFmpeg path: \(paths.ffmpeg ?? "not found")")
        logs.append("ffprobe path: \(paths.ffprobe ?? "not found")")
        logs.append("Destination folder: \(destinationFolder.path)")
    }

    func dismissReadinessMessage() {
        settings.markReadinessMessageShown()
        showReadinessMessage = false
    }

    var resolvedPaths: FFmpegPaths {
        FFmpegPathResolver.resolve(
            ffmpegOverride: settings.ffmpegOverride,
            ffprobeOverride: settings.ffprobeOverride
        )
    }

    var canStart: Bool {
        !assets.isEmpty && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && state != .analyzingFiles && state != .generatingPlan && state != .rendering
            && !isRefiningPrompt
    }

    var mentionSuggestions: [MediaAsset] {
        guard let query = activeMentionQuery else { return [] }
        return assets.filter {
            query.isEmpty || $0.filename.localizedCaseInsensitiveContains(query)
        }
    }

    private var activeMentionQuery: String? {
        guard let atIndex = prompt.lastIndex(of: "@") else { return nil }
        let queryStart = prompt.index(after: atIndex)
        let query = String(prompt[queryStart...])
        guard !query.contains(where: { $0.isWhitespace }) else { return nil }
        return query
    }

    func insertMention(_ asset: MediaAsset) {
        guard let atIndex = prompt.lastIndex(of: "@") else { return }
        prompt.replaceSubrange(atIndex..., with: "@\(asset.filename) ")
    }

    func addDroppedURLs(_ urls: [URL]) {
        Task {
            await analyze(urls: urls)
        }
    }

    func analyze(urls: [URL]) async {
        errorMessage = nil
        let uniqueURLs = urls.filter { url in
            !assets.contains(where: { $0.path == url.path })
        }
        guard !uniqueURLs.isEmpty else { return }
        guard let ffprobe = resolvedPaths.ffprobe else {
            fail("ffprobe was not found. Install FFmpeg or select ffprobe path in settings.")
            return
        }

        state = .analyzingFiles
        logs.append("Analyzing \(uniqueURLs.count) dropped file(s).")
        let analyzer = MediaAnalyzer(ffprobePath: ffprobe)

        for url in uniqueURLs {
            guard FileHelpers.isSupported(url) else {
                logs.append("Rejected unsupported file: \(url.lastPathComponent)")
                errorMessage = "\(url.lastPathComponent) is not a supported media type."
                continue
            }
            do {
                let asset = try await analyzer.analyze(url: url)
                guard asset.type != .unknown else {
                    throw MediaAnalyzerError.invalidResponse
                }
                assets.append(asset)
                logs.append(
                    "Analyzed \(asset.filename): \(asset.type.rawValue), " +
                    "duration \(asset.durationSeconds.map(TimeFormatter.display) ?? "n/a"), " +
                    "codec \(asset.videoCodec ?? asset.audioCodec ?? "n/a")."
                )
            } catch {
                logs.append("Analysis failed for \(url.lastPathComponent): \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            }
        }
        state = assets.isEmpty ? .idle : .ready
    }

    func removeAsset(_ asset: MediaAsset) {
        assets.removeAll { $0.id == asset.id }
        editPlan = nil
        validatedPlan = nil
        state = assets.isEmpty ? .idle : .ready
        logs.append("Removed \(asset.filename).")
    }

    func chooseDestination() {
        let panel = NSOpenPanel()
        panel.title = "Choose Output Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = destinationFolder
        if panel.runModal() == .OK, let url = panel.url {
            destinationFolder = url
            settings.saveDestinationFolder(url)
            logs.append("Destination folder: \(url.path)")
        }
    }

    func chooseMediaFiles() {
        let panel = NSOpenPanel()
        panel.title = "Choose Media Files"
        panel.prompt = "Add Files"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = FileHelpers.supportedContentTypes
        if panel.runModal() == .OK {
            addDroppedURLs(panel.urls)
        }
    }

    func start() {
        Task {
            await generatePlan()
        }
    }

    func generatePlan() async {
        errorMessage = nil
        editPlan = nil
        validatedPlan = nil
        outputURL = nil

        guard assets.contains(where: { $0.type == .video }) else {
            fail("Add at least one video file before starting.")
            return
        }
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            fail("Describe the video you want to create.")
            return
        }
        guard let safeOutputFilename = FileHelpers.safeOutputFilename(outputFilename) else {
            fail("Enter a valid output filename.")
            return
        }
        outputFilename = safeOutputFilename
        let paths = resolvedPaths
        guard paths.ffmpeg != nil else {
            fail("FFmpeg was not found. Install FFmpeg or select its path in settings.")
            return
        }
        guard paths.ffprobe != nil else {
            fail("ffprobe was not found. Install FFmpeg or select ffprobe path in settings.")
            return
        }

        do {
            let client = try makeClient()
            state = .generatingPlan
            logs.append("Generating edit plan with \(settings.provider.rawValue).")
            let intent = try await client.generateEditIntent(
                request: EditPlanRequest(userPrompt: prompt, assets: assets)
            )
            if let data = try? JSONEncoder.pretty.encode(intent) {
                logs.append("LLM JSON response:\n\(String(decoding: data, as: UTF8.self))")
            }
            let plan = try makeEditPlan(from: intent, outputFilename: safeOutputFilename)

            state = .validatingPlan
            let validated = try EditPlanValidator().validate(
                plan: plan,
                assets: assets,
                destinationFolder: destinationFolder,
                ffmpegPath: paths.ffmpeg,
                ffprobePath: paths.ffprobe,
                exportSettings: settings.exportSettingsSelection
            )
            validatedPlan = validated
            editPlan = validated.plan
            logDurationPlan(validated.durationPlan)
            logExportSettings(validated.exportSettings)
            logs.append("Edit plan validation passed.")
            unsupportedPromptRequests = validated.plan.unsupportedRequests
            if unsupportedPromptRequests.isEmpty {
                promptFailureReason = nil
            } else {
                promptFailureReason = "The generated plan contains unsupported requests."
                logs.append("Unsupported requests available to prompt refinement: \(unsupportedPromptRequests.joined(separator: "; "))")
            }
            state = .awaitingRenderConfirmation
        } catch {
            if case LLMClientError.invalidJSON(let details) = error {
                logs.append("Invalid AI JSON details: \(details)")
            }
            promptFailureReason = error.localizedDescription
            unsupportedPromptRequests = []
            fail(error.localizedDescription)
        }
    }

    func refinePrompt() {
        guard !isRefiningPrompt,
              !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        Task {
            isRefiningPrompt = true
            defer { isRefiningPrompt = false }
            do {
                let client = try makeClient()
                logs.append("Refining prompt with \(settings.provider.rawValue).")
                let refined = try await client.refinePrompt(
                    request: PromptRefinementRequest(
                        userPrompt: prompt,
                        assets: assets,
                        failureReason: promptFailureReason,
                        unsupportedRequests: unsupportedPromptRequests
                    )
                )
                prompt = refined
                promptFailureReason = nil
                unsupportedPromptRequests = []
                editPlan = nil
                validatedPlan = nil
                state = assets.isEmpty ? .idle : .ready
                errorMessage = nil
                logs.append("Prompt refined successfully.")
            } catch {
                logs.append("Prompt refinement failed: \(error.localizedDescription)")
                errorMessage = "The prompt could not be refined: \(error.localizedDescription)"
            }
        }
    }

    func testConnection() {
        Task {
            do {
                let client = try makeClient()
                logs.append("Testing \(settings.provider.rawValue) connection.")
                _ = try await client.testConnection()
                logs.append("Provider connection test passed.")
                errorMessage = nil
            } catch {
                fail(error.localizedDescription)
            }
        }
    }

    func render() {
        guard let validatedPlan else { return }
        Task {
            do {
                state = .rendering
                progress = 0
                processedSeconds = 0
                errorMessage = nil
                let command = try FFmpegCommandBuilder().build(from: validatedPlan)
                logs.append("Generated FFmpeg arguments:\n\(commandDescription(command))")
                logs.append("Rendering to \(command.outputURL.path)")

                try await runner.run(
                    command: command,
                    onProgress: { [weak self] progress, seconds in
                        Task { @MainActor in
                            self?.progress = progress
                            self?.processedSeconds = seconds
                        }
                    },
                    onLog: { [weak self] line in
                        Task { @MainActor in self?.logs.append("ffmpeg: \(line)") }
                    }
                )
                outputURL = command.outputURL
                progress = 1
                processedSeconds = command.durationSeconds
                state = .completed
                logs.append("Render completed: \(command.outputURL.path)")
            } catch {
                fail(error.localizedDescription)
            }
        }
    }

    func cancelRender() {
        runner.cancel()
        logs.append("Render cancellation requested.")
    }

    func cancelPlan() {
        editPlan = nil
        validatedPlan = nil
        state = assets.isEmpty ? .idle : .ready
    }

    func clear() {
        if state == .rendering {
            runner.cancel()
        }
        assets = []
        prompt = ""
        outputFilename = "loopforge-output.mp4"
        editPlan = nil
        validatedPlan = nil
        progress = 0
        processedSeconds = 0
        outputURL = nil
        errorMessage = nil
        isRefiningPrompt = false
        promptFailureReason = nil
        unsupportedPromptRequests = []
        state = .idle
        logs.append("Project cleared.")
    }

    func revealOutput() {
        guard let outputURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([outputURL])
    }

    private func makeClient() throws -> any LLMClient {
        switch settings.provider {
        case .openAICompatible:
            guard let url = providerURL(settings.openAIBaseURL), !settings.openAIModel.isEmpty else {
                throw LLMClientError.invalidURL
            }
            return OpenAICompatibleClient(
                baseURL: url,
                apiKey: openAIKey.trimmingCharacters(in: .whitespacesAndNewlines),
                model: settings.openAIModel
            )
        case .openRouter:
            guard let url = providerURL(settings.openRouterBaseURL), !settings.openRouterModel.isEmpty else {
                throw LLMClientError.invalidURL
            }
            return OpenRouterClient(
                baseURL: url,
                apiKey: openRouterKey.trimmingCharacters(in: .whitespacesAndNewlines),
                model: settings.openRouterModel
            )
        case .ollama:
            guard let url = providerURL(settings.ollamaBaseURL), !settings.ollamaModel.isEmpty else {
                throw LLMClientError.invalidURL
            }
            return OllamaClient(baseURL: url, model: settings.ollamaModel)
        }
    }

    private func commandDescription(_ command: FFmpegCommand) -> String {
        ([command.executablePath] + command.arguments).map { argument in
            argument.contains(" ") ? "\"\(argument)\"" : argument
        }.joined(separator: " ")
    }

    private func providerURL(_ value: String) -> URL? {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host != nil else {
            return nil
        }
        return url
    }

    private func makeEditPlan(from intent: EditIntent, outputFilename: String) throws -> EditPlan {
        guard let video = resolveAsset(reference: intent.videoFileId, type: .video) else {
            throw EditPlanValidationError(issues: ["The AI response did not select a valid uploaded video."])
        }
        let audio = intent.audioFileId.flatMap { resolveAsset(reference: $0, type: .audio) }
        if intent.audioFileId != nil, audio == nil {
            throw EditPlanValidationError(issues: ["The AI response did not select a valid uploaded audio file."])
        }
        let requestedAudioLoopCount = intent.requestedAudioLoopCount
            ?? UserPromptIntentParser.requestedAudioLoopCount(from: prompt)
        return EditPlan(
            summary: intent.summary,
            output: OutputSettings(
                format: "mp4",
                filename: outputFilename,
                targetDurationSeconds: intent.targetDurationSeconds,
                requestedAudioLoopCount: requestedAudioLoopCount,
                width: video.width,
                height: video.height,
                fps: video.frameRate
            ),
            video: VideoPlan(
                baseFileId: video.id,
                loop: false,
                trimStartSeconds: nil,
                trimEndSeconds: nil,
                resize: nil,
                preserveAspectRatio: true
            ),
            audio: audio.map {
                AudioPlan(
                    mode: .replace,
                    fileId: $0.id,
                    loop: false,
                    trimToOutputDuration: false,
                    keepOriginalAudio: false,
                    volume: 1
                )
            },
            overlays: intent.overlays,
            effects: [],
            unsupportedRequests: intent.unsupportedRequests,
            assumptions: intent.assumptions
        )
    }

    private func resolveAsset(reference: String, type: MediaType) -> MediaAsset? {
        let normalized = reference
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        return assets.first {
            $0.type == type &&
            ($0.id == normalized || $0.filename.caseInsensitiveCompare(normalized) == .orderedSame)
        }
    }

    private func logDurationPlan(_ plan: DurationPlan) {
        logs.append("Clean Loop Ending Mode duration plan:")
        logs.append("Requested target duration: \(plan.targetDurationSeconds.map(TimeFormatter.display) ?? "not provided")")
        if let requestedLoopCount = validatedPlan?.plan.output.requestedAudioLoopCount {
            logs.append("Requested audio loop count: \(requestedLoopCount)")
        }
        logs.append("Audio duration: \(plan.audioDurationSeconds.map(TimeFormatter.display) ?? "no external audio")")
        logs.append("Calculated audio loop count: \(plan.audioLoopCount)")
        logs.append("Final output duration: \(TimeFormatter.display(plan.finalDurationSeconds))")
        logs.append("Fade start time: \(TimeFormatter.display(plan.videoFadeStartSeconds))")
    }

    private func logExportSettings(_ settings: ResolvedExportSettings) {
        logs.append("Resolved export settings:")
        logs.append("Resolution: \(settings.width)x\(settings.height)")
        logs.append("Frame rate: \(String(format: "%.3f", settings.fps)) fps")
        logs.append("Quality: \(settings.quality.label) (CRF \(settings.quality.crf))")
        logs.append("Encoding speed: \(settings.encodingSpeed.label) (\(settings.encodingSpeed.ffmpegPreset))")
        logs.append("Audio quality: \(settings.audioBitrate.label)")
        if settings.isUpscaling {
            logs.append("Upscaling note: selected output is larger than the source.")
        }
    }

    private func fail(_ message: String) {
        errorMessage = message
        state = .failed(message)
        logs.append("Error: \(message)")
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
