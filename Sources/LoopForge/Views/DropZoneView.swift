import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 34))
                .foregroundStyle(.tint)
            Text("Drag files here or click to browse")
                .font(.headline)
            Text("MP4, MOV, MKV, WebM, MP3, WAV, AAC, M4A, FLAC, PNG, JPG, or WebP")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 130)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(viewModel.isDropTargeted ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    viewModel.isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                    style: StrokeStyle(lineWidth: 1.5, dash: [7])
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            viewModel.chooseMediaFiles()
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Choose media files")
        .help("Click to browse for media files, or drag files here")
        .onDrop(of: [UTType.fileURL], isTargeted: $viewModel.isDropTargeted) { providers in
            loadURLs(from: providers)
            return true
        }
    }

    private func loadURLs(from providers: [NSItemProvider]) {
        let group = DispatchGroup()
        let lock = NSLock()
        var urls: [URL] = []
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                defer { group.leave() }
                guard let data,
                      let text = String(data: data, encoding: .utf8),
                      let url = URL(string: text) else { return }
                lock.lock()
                urls.append(url)
                lock.unlock()
            }
        }
        group.notify(queue: .main) {
            viewModel.addDroppedURLs(urls)
        }
    }
}
