import Foundation

enum MediaType: String, Codable, CaseIterable, Sendable {
    case video
    case audio
    case image
    case unknown
}

struct MediaAsset: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let filename: String
    let path: String
    let type: MediaType
    let durationSeconds: Double?
    let width: Int?
    let height: Int?
    let frameRate: Double?
    let videoCodec: String?
    let audioCodec: String?
    let hasAudio: Bool?
    let sampleRate: Int?
    let channels: Int?
    let fileSizeBytes: Int64

    var url: URL {
        URL(fileURLWithPath: path)
    }
}
