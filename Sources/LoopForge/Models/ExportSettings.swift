import Foundation

enum ExportResolution: String, Codable, CaseIterable, Identifiable, Sendable {
    case source
    case uhd4K
    case fullHD
    case hd
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .source: return "Source"
        case .uhd4K: return "4K (3840x2160)"
        case .fullHD: return "1080p (1920x1080)"
        case .hd: return "720p (1280x720)"
        case .custom: return "Custom"
        }
    }

    var dimensions: (width: Int, height: Int)? {
        switch self {
        case .uhd4K: return (3840, 2160)
        case .fullHD: return (1920, 1080)
        case .hd: return (1280, 720)
        case .source, .custom: return nil
        }
    }
}

enum ExportFrameRate: String, Codable, CaseIterable, Identifiable, Sendable {
    case source
    case fps24
    case fps25
    case fps30
    case fps50
    case fps60

    var id: String { rawValue }

    var label: String {
        switch self {
        case .source: return "Source"
        case .fps24: return "24 fps"
        case .fps25: return "25 fps"
        case .fps30: return "30 fps"
        case .fps50: return "50 fps"
        case .fps60: return "60 fps"
        }
    }

    var value: Double? {
        switch self {
        case .source: return nil
        case .fps24: return 24
        case .fps25: return 25
        case .fps30: return 30
        case .fps50: return 50
        case .fps60: return 60
        }
    }
}

enum ExportQuality: String, Codable, CaseIterable, Identifiable, Sendable {
    case high
    case balanced
    case smallFile

    var id: String { rawValue }

    var label: String {
        switch self {
        case .high: return "High"
        case .balanced: return "Balanced"
        case .smallFile: return "Small File"
        }
    }

    var crf: Int {
        switch self {
        case .high: return 18
        case .balanced: return 20
        case .smallFile: return 24
        }
    }
}

enum ExportEncodingSpeed: String, Codable, CaseIterable, Identifiable, Sendable {
    case fast
    case balanced
    case bestCompression

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fast: return "Fast"
        case .balanced: return "Balanced"
        case .bestCompression: return "Best Compression"
        }
    }

    var ffmpegPreset: String {
        switch self {
        case .fast: return "fast"
        case .balanced: return "medium"
        case .bestCompression: return "slow"
        }
    }
}

enum ExportAudioBitrate: Int, Codable, CaseIterable, Identifiable, Sendable {
    case kbps128 = 128
    case kbps192 = 192
    case kbps256 = 256
    case kbps320 = 320

    var id: Int { rawValue }
    var label: String { "\(rawValue) kbps" }
    var ffmpegValue: String { "\(rawValue)k" }
}

struct ExportSettingsSelection: Equatable, Sendable {
    let resolution: ExportResolution
    let frameRate: ExportFrameRate
    let quality: ExportQuality
    let encodingSpeed: ExportEncodingSpeed
    let audioBitrate: ExportAudioBitrate
    let customWidthText: String
    let customHeightText: String
}

struct ResolvedExportSettings: Equatable, Sendable {
    let width: Int
    let height: Int
    let fps: Double
    let quality: ExportQuality
    let encodingSpeed: ExportEncodingSpeed
    let audioBitrate: ExportAudioBitrate
    let isUpscaling: Bool
}

enum YouTubeExportPreset: String, CaseIterable, Identifiable, Sendable {
    case uhd4K
    case fullHD

    var id: String { rawValue }

    var title: String {
        switch self {
        case .uhd4K: return "YouTube 4K"
        case .fullHD: return "YouTube 1080p"
        }
    }

    var resolution: ExportResolution {
        switch self {
        case .uhd4K: return .uhd4K
        case .fullHD: return .fullHD
        }
    }

    var frameRate: ExportFrameRate { .source }
    var quality: ExportQuality { .high }
    var encodingSpeed: ExportEncodingSpeed { .bestCompression }
    var audioBitrate: ExportAudioBitrate { .kbps320 }

    var summary: String {
        "\(resolution.label) · Source FPS · High quality · Best Compression · 320 kbps audio"
    }
}
