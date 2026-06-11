import Foundation
import UniformTypeIdentifiers

enum FileHelpers {
    static let supportedExtensions: Set<String> = [
        "mp4", "mov", "mkv", "webm",
        "mp3", "wav", "aac", "m4a", "flac",
        "png", "jpg", "jpeg", "webp"
    ]

    static func isSupported(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    static var supportedContentTypes: [UTType] {
        supportedExtensions.compactMap { UTType(filenameExtension: $0) }
    }

    static func defaultDestinationFolder() -> URL {
        FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
    }

    static func safeOutputFilename(_ proposed: String) -> String? {
        let trimmed = proposed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains("/"),
              !trimmed.contains("\\"),
              trimmed != ".",
              trimmed != ".." else {
            return nil
        }
        let filename = trimmed.lowercased().hasSuffix(".mp4") ? trimmed : "\(trimmed).mp4"
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " ._-()"))
        guard filename.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        return filename
    }

    static func uniqueOutputURL(folder: URL, filename: String) -> URL {
        let baseURL = folder.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: baseURL.path) else { return baseURL }

        let stem = baseURL.deletingPathExtension().lastPathComponent
        let ext = baseURL.pathExtension
        var index = 1
        while true {
            let candidate = folder.appendingPathComponent("\(stem)-\(index).\(ext)")
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }

    static func formattedFileSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
