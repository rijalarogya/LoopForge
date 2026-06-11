import SwiftUI

struct ExportSettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject private var settings: SettingsStore
    @State private var isShowingYouTubeGuide = false

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
        settings = viewModel.settings
    }

    var body: some View {
        GroupBox {
            VStack(spacing: 12) {
                LabeledContent("Resolution") {
                    Picker("Resolution", selection: $settings.exportResolution) {
                        ForEach(ExportResolution.allCases) { resolution in
                            Text(resolution.label).tag(resolution)
                        }
                    }
                    .labelsHidden()
                    .frame(minWidth: 220)
                }

                if settings.exportResolution == .custom {
                    HStack(spacing: 12) {
                        LabeledContent("Width") {
                            TextField("1920", text: $settings.customExportWidth)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 90)
                        }
                        LabeledContent("Height") {
                            TextField("1080", text: $settings.customExportHeight)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 90)
                        }
                    }
                }

                LabeledContent("Frame rate") {
                    Picker("Frame rate", selection: $settings.exportFrameRate) {
                        ForEach(ExportFrameRate.allCases) { frameRate in
                            Text(frameRate.label).tag(frameRate)
                        }
                    }
                    .labelsHidden()
                    .frame(minWidth: 220)
                }

                LabeledContent("Quality") {
                    Picker("Quality", selection: $settings.exportQuality) {
                        ForEach(ExportQuality.allCases) { quality in
                            Text(quality.label).tag(quality)
                        }
                    }
                    .labelsHidden()
                    .frame(minWidth: 220)
                }

                LabeledContent("Encoding speed") {
                    Picker("Encoding speed", selection: $settings.exportEncodingSpeed) {
                        ForEach(ExportEncodingSpeed.allCases) { speed in
                            Text(speed.label).tag(speed)
                        }
                    }
                    .labelsHidden()
                    .frame(minWidth: 220)
                }

                LabeledContent("Audio quality") {
                    Picker("Audio quality", selection: $settings.exportAudioBitrate) {
                        ForEach(ExportAudioBitrate.allCases) { bitrate in
                            Text(bitrate.label).tag(bitrate)
                        }
                    }
                    .labelsHidden()
                    .frame(minWidth: 220)
                }

                if isLikelyUpscaling {
                    Label(
                        "This resolution is larger than the source. Upscaling cannot add source detail.",
                        systemImage: "info.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text("MP4 · H.264 · AAC · Fit with black padding")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 4)
        } label: {
            HStack(spacing: 6) {
                Text("Export Settings")
                Button {
                    isShowingYouTubeGuide.toggle()
                } label: {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.blue)
                .accessibilityLabel("YouTube export settings guide")
                .help("Show recommended YouTube export settings")
                .popover(isPresented: $isShowingYouTubeGuide, arrowEdge: .bottom) {
                    youtubeGuide
                }
            }
        }
    }

    private var youtubeGuide: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("YouTube Export Guide")
                    .font(.headline)
                Text("Recommended settings for standard SDR uploads.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(YouTubeExportPreset.allCases) { preset in
                VStack(alignment: .leading, spacing: 7) {
                    Text(preset.title)
                        .font(.subheadline.bold())
                    Text(preset.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Apply \(preset.title) Settings") {
                        settings.applyYouTubePreset(preset)
                        isShowingYouTubeGuide = false
                    }
                    .accessibilityLabel("Apply \(preset.title) export settings")
                    .help("Use the recommended \(preset.title) export settings")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            }

            Divider()

            VStack(alignment: .leading, spacing: 5) {
                Label(
                    "Source FPS preserves the video's original frame rate.",
                    systemImage: "film"
                )
                Label(
                    "Use 60 fps only when the source is 50 or 60 fps.",
                    systemImage: "speedometer"
                )
                Label(
                    "Upscaling cannot restore detail missing from the source.",
                    systemImage: "arrow.up.left.and.arrow.down.right"
                )
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text("Output remains MP4 · H.264 · AAC · yuv420p")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 390)
    }

    private var isLikelyUpscaling: Bool {
        guard let source = viewModel.assets.first(where: { $0.type == .video }),
              let sourceWidth = source.width,
              let sourceHeight = source.height,
              let output = selectedDimensions else {
            return false
        }
        return output.width > sourceWidth || output.height > sourceHeight
    }

    private var selectedDimensions: (width: Int, height: Int)? {
        if let dimensions = settings.exportResolution.dimensions {
            return dimensions
        }
        if settings.exportResolution == .custom,
           let width = Int(settings.customExportWidth),
           let height = Int(settings.customExportHeight) {
            return (width, height)
        }
        return nil
    }
}
