import Foundation

struct FFmpegPaths: Equatable, Sendable {
    let ffmpeg: String?
    let ffprobe: String?
}

enum FFmpegPathResolver {
    static let ffmpegCandidates = [
        "/opt/homebrew/bin/ffmpeg",
        "/usr/local/bin/ffmpeg",
        "/usr/bin/ffmpeg"
    ]

    static let ffprobeCandidates = [
        "/opt/homebrew/bin/ffprobe",
        "/usr/local/bin/ffprobe",
        "/usr/bin/ffprobe"
    ]

    static func resolve(
        ffmpegOverride: String? = nil,
        ffprobeOverride: String? = nil,
        resourceURL: URL? = Bundle.main.resourceURL,
        ffmpegFallbacks: [String] = ffmpegCandidates,
        ffprobeFallbacks: [String] = ffprobeCandidates
    ) -> FFmpegPaths {
        let bundledFFmpeg = resourceURL?
            .appendingPathComponent("bin/ffmpeg", isDirectory: false).path
        let bundledFFprobe = resourceURL?
            .appendingPathComponent("bin/ffprobe", isDirectory: false).path

        return FFmpegPaths(
            ffmpeg: validExecutable(bundledFFmpeg)
                ?? validExecutable(ffmpegOverride)
                ?? ffmpegFallbacks.first(where: isExecutable),
            ffprobe: validExecutable(bundledFFprobe)
                ?? validExecutable(ffprobeOverride)
                ?? ffprobeFallbacks.first(where: isExecutable)
        )
    }

    private static func validExecutable(_ path: String?) -> String? {
        guard let path, !path.isEmpty, isExecutable(path) else { return nil }
        return path
    }

    private static func isExecutable(_ path: String) -> Bool {
        FileManager.default.isExecutableFile(atPath: path)
    }
}
