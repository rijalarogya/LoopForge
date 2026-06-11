import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    static let currentBundleIdentifier = "com.arogya.loopforge"
    static let legacyBundleIdentifier = "com.local.PromptVideoBuilder"

    @Published var provider: AIProvider {
        didSet { defaults.set(provider.rawValue, forKey: Keys.provider) }
    }
    @Published var openAIBaseURL: String {
        didSet { defaults.set(openAIBaseURL, forKey: Keys.openAIBaseURL) }
    }
    @Published var openAIModel: String {
        didSet { defaults.set(openAIModel, forKey: Keys.openAIModel) }
    }
    @Published var openRouterBaseURL: String {
        didSet { defaults.set(openRouterBaseURL, forKey: Keys.openRouterBaseURL) }
    }
    @Published var openRouterModel: String {
        didSet { defaults.set(openRouterModel, forKey: Keys.openRouterModel) }
    }
    @Published var ollamaBaseURL: String {
        didSet { defaults.set(ollamaBaseURL, forKey: Keys.ollamaBaseURL) }
    }
    @Published var ollamaModel: String {
        didSet { defaults.set(ollamaModel, forKey: Keys.ollamaModel) }
    }
    @Published var ffmpegOverride: String {
        didSet { defaults.set(ffmpegOverride, forKey: Keys.ffmpegOverride) }
    }
    @Published var ffprobeOverride: String {
        didSet { defaults.set(ffprobeOverride, forKey: Keys.ffprobeOverride) }
    }
    @Published var exportResolution: ExportResolution {
        didSet { defaults.set(exportResolution.rawValue, forKey: Keys.exportResolution) }
    }
    @Published var exportFrameRate: ExportFrameRate {
        didSet { defaults.set(exportFrameRate.rawValue, forKey: Keys.exportFrameRate) }
    }
    @Published var exportQuality: ExportQuality {
        didSet { defaults.set(exportQuality.rawValue, forKey: Keys.exportQuality) }
    }
    @Published var exportEncodingSpeed: ExportEncodingSpeed {
        didSet { defaults.set(exportEncodingSpeed.rawValue, forKey: Keys.exportEncodingSpeed) }
    }
    @Published var exportAudioBitrate: ExportAudioBitrate {
        didSet { defaults.set(exportAudioBitrate.rawValue, forKey: Keys.exportAudioBitrate) }
    }
    @Published var customExportWidth: String {
        didSet { defaults.set(customExportWidth, forKey: Keys.customExportWidth) }
    }
    @Published var customExportHeight: String {
        didSet { defaults.set(customExportHeight, forKey: Keys.customExportHeight) }
    }

    private let defaults: UserDefaults

    init(
        defaults: UserDefaults = .standard,
        legacyDefaults: UserDefaults? = UserDefaults(suiteName: "com.local.PromptVideoBuilder")
    ) {
        Self.migrateLegacyDefaultsIfNeeded(from: legacyDefaults, to: defaults)
        self.defaults = defaults
        provider = AIProvider(rawValue: defaults.string(forKey: Keys.provider) ?? "") ?? .ollama
        openAIBaseURL = defaults.string(forKey: Keys.openAIBaseURL) ?? "https://api.openai.com/v1"
        openAIModel = defaults.string(forKey: Keys.openAIModel) ?? "gpt-4.1-mini"
        openRouterBaseURL = defaults.string(forKey: Keys.openRouterBaseURL) ?? "https://openrouter.ai/api/v1"
        openRouterModel = defaults.string(forKey: Keys.openRouterModel) ?? "openai/gpt-4.1-mini"
        ollamaBaseURL = defaults.string(forKey: Keys.ollamaBaseURL) ?? "http://localhost:11434"
        ollamaModel = defaults.string(forKey: Keys.ollamaModel) ?? "llama3.1:8b"
        ffmpegOverride = defaults.string(forKey: Keys.ffmpegOverride) ?? ""
        ffprobeOverride = defaults.string(forKey: Keys.ffprobeOverride) ?? ""
        exportResolution = ExportResolution(
            rawValue: defaults.string(forKey: Keys.exportResolution) ?? ""
        ) ?? .source
        exportFrameRate = ExportFrameRate(
            rawValue: defaults.string(forKey: Keys.exportFrameRate) ?? ""
        ) ?? .source
        exportQuality = ExportQuality(
            rawValue: defaults.string(forKey: Keys.exportQuality) ?? ""
        ) ?? .balanced
        exportEncodingSpeed = ExportEncodingSpeed(
            rawValue: defaults.string(forKey: Keys.exportEncodingSpeed) ?? ""
        ) ?? .balanced
        exportAudioBitrate = ExportAudioBitrate(
            rawValue: defaults.integer(forKey: Keys.exportAudioBitrate)
        ) ?? .kbps192
        customExportWidth = defaults.string(forKey: Keys.customExportWidth) ?? "1920"
        customExportHeight = defaults.string(forKey: Keys.customExportHeight) ?? "1080"
    }

    var shouldShowReadinessMessage: Bool {
        !defaults.bool(forKey: Keys.didShowReadinessMessage)
    }

    func markReadinessMessageShown() {
        defaults.set(true, forKey: Keys.didShowReadinessMessage)
    }

    func savedDestinationFolder() -> URL? {
        if let bookmarkData = defaults.data(forKey: Keys.destinationFolderBookmark) {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ), folderExists(url) {
                if isStale {
                    saveDestinationFolder(url)
                }
                return url
            }
        }

        if let path = defaults.string(forKey: Keys.destinationFolderPath) {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            if folderExists(url) {
                return url
            }
        }
        return nil
    }

    func saveDestinationFolder(_ url: URL) {
        defaults.set(url.path, forKey: Keys.destinationFolderPath)
        if let bookmarkData = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            defaults.set(bookmarkData, forKey: Keys.destinationFolderBookmark)
        }
    }

    var exportSettingsSelection: ExportSettingsSelection {
        ExportSettingsSelection(
            resolution: exportResolution,
            frameRate: exportFrameRate,
            quality: exportQuality,
            encodingSpeed: exportEncodingSpeed,
            audioBitrate: exportAudioBitrate,
            customWidthText: customExportWidth,
            customHeightText: customExportHeight
        )
    }

    func applyYouTubePreset(_ preset: YouTubeExportPreset) {
        exportResolution = preset.resolution
        exportFrameRate = preset.frameRate
        exportQuality = preset.quality
        exportEncodingSpeed = preset.encodingSpeed
        exportAudioBitrate = preset.audioBitrate
    }

    private func folderExists(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    private static func migrateLegacyDefaultsIfNeeded(
        from legacyDefaults: UserDefaults?,
        to defaults: UserDefaults
    ) {
        guard !defaults.bool(forKey: Keys.didMigrateLegacyDefaults),
              let legacyDefaults else {
            return
        }

        for key in Keys.migratedKeys where defaults.object(forKey: key) == nil {
            if let value = legacyDefaults.object(forKey: key) {
                defaults.set(value, forKey: key)
            }
        }
        defaults.set(true, forKey: Keys.didMigrateLegacyDefaults)
    }

    private enum Keys {
        static let provider = "provider"
        static let openAIBaseURL = "openAIBaseURL"
        static let openAIModel = "openAIModel"
        static let openRouterBaseURL = "openRouterBaseURL"
        static let openRouterModel = "openRouterModel"
        static let ollamaBaseURL = "ollamaBaseURL"
        static let ollamaModel = "ollamaModel"
        static let ffmpegOverride = "ffmpegOverride"
        static let ffprobeOverride = "ffprobeOverride"
        static let destinationFolderBookmark = "destinationFolderBookmark"
        static let destinationFolderPath = "destinationFolderPath"
        static let exportResolution = "exportResolution"
        static let exportFrameRate = "exportFrameRate"
        static let exportQuality = "exportQuality"
        static let exportEncodingSpeed = "exportEncodingSpeed"
        static let exportAudioBitrate = "exportAudioBitrate"
        static let customExportWidth = "customExportWidth"
        static let customExportHeight = "customExportHeight"
        static let didMigrateLegacyDefaults = "didMigrateLegacyDefaultsToLoopForge"
        static let didShowReadinessMessage = "didShowLoopForgeReadinessMessage"

        static let migratedKeys = [
            provider,
            openAIBaseURL,
            openAIModel,
            openRouterBaseURL,
            openRouterModel,
            ollamaBaseURL,
            ollamaModel,
            ffmpegOverride,
            ffprobeOverride,
            destinationFolderBookmark,
            destinationFolderPath,
            exportResolution,
            exportFrameRate,
            exportQuality,
            exportEncodingSpeed,
            exportAudioBitrate,
            customExportWidth,
            customExportHeight
        ]
    }
}
