import SwiftUI

struct FileListView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        GroupBox("Files") {
            VStack(spacing: 0) {
                ForEach(viewModel.assets) { asset in
                    HStack(spacing: 12) {
                        Image(systemName: icon(for: asset.type))
                            .frame(width: 24)
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(asset.filename)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Text(metadata(for: asset))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button {
                            viewModel.removeAsset(asset)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Remove \(asset.filename)")
                    }
                    .padding(.vertical, 9)
                    if asset.id != viewModel.assets.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func icon(for type: MediaType) -> String {
        switch type {
        case .video: return "film"
        case .audio: return "waveform"
        case .image: return "photo"
        case .unknown: return "questionmark.square"
        }
    }

    private func metadata(for asset: MediaAsset) -> String {
        var values = [asset.type.rawValue.capitalized]
        if let duration = asset.durationSeconds {
            values.append(TimeFormatter.display(duration))
        }
        if let width = asset.width, let height = asset.height {
            values.append("\(width)x\(height)")
        }
        if let codec = asset.videoCodec ?? asset.audioCodec {
            values.append(codec.uppercased())
        }
        values.append(FileHelpers.formattedFileSize(asset.fileSizeBytes))
        return values.joined(separator: " · ")
    }
}
