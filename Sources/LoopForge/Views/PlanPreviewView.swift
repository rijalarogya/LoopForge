import SwiftUI

struct PlanPreviewView: View {
    let plan: EditPlan
    let durationPlan: DurationPlan?
    let exportSettings: ResolvedExportSettings?
    let assets: [MediaAsset]
    let onRender: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Review Edit Plan")
                .font(.title2.bold())
            Text(plan.summary)
                .font(.headline)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    summaryRow("Mode", "Clean Loop Ending Mode")
                    if let durationPlan {
                        summaryRow("Requested duration", durationPlan.targetDurationSeconds.map(TimeFormatter.display) ?? "Not specified")
                        if let audioDuration = durationPlan.audioDurationSeconds {
                            summaryRow("Audio loop length", TimeFormatter.display(audioDuration))
                            summaryRow("Audio loops", "\(durationPlan.audioLoopCount)")
                        }
                        summaryRow("Final output duration", TimeFormatter.display(durationPlan.finalDurationSeconds))
                        summaryRow("Reason", durationPlan.explanation)
                        summaryRow(
                            "Ending",
                            "Final \(TimeFormatter.display(durationPlan.fadeDurationSeconds)) fades audio out and video to black."
                        )
                    }
                    summaryRow("Output", outputSummary)
                    if let exportSettings {
                        summaryRow("Quality", "\(exportSettings.quality.label) · CRF \(exportSettings.quality.crf)")
                        summaryRow("Encoding speed", exportSettings.encodingSpeed.label)
                        summaryRow("Audio quality", exportSettings.audioBitrate.label)
                        if exportSettings.isUpscaling {
                            summaryRow(
                                "Upscaling",
                                "The selected resolution is larger than the source and will not add source detail."
                            )
                            .foregroundStyle(.orange)
                        }
                    }
                    summaryRow("Video", videoSummary)
                    if let audioSummary {
                        summaryRow("Audio", audioSummary)
                    }
                    ForEach(Array(plan.overlays.enumerated()), id: \.offset) { _, overlay in
                        summaryRow("Overlay", overlaySummary(overlay))
                    }
                    ForEach(Array(plan.effects.filter { $0.type == .fadeIn }.enumerated()), id: \.offset) { _, effect in
                        summaryRow("Effect", effectSummary(effect))
                    }
                    if !plan.assumptions.isEmpty {
                        summaryRow("Assumptions", plan.assumptions.joined(separator: "\n"))
                    }
                    if !plan.unsupportedRequests.isEmpty {
                        summaryRow("Unsupported", plan.unsupportedRequests.joined(separator: "\n"))
                            .foregroundStyle(.orange)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Render Video", action: onRender)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
            }
        }
        .padding(24)
        .frame(width: 620, height: 520)
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }

    private var outputSummary: String {
        var parts = [
            "\(TimeFormatter.display(durationPlan?.finalDurationSeconds)) MP4",
            plan.output.filename
        ]
        if let width = exportSettings?.width, let height = exportSettings?.height {
            parts.append("\(width)x\(height)")
        }
        if let fps = exportSettings?.fps {
            parts.append("\(String(format: "%.2g", fps)) fps")
        }
        return parts.joined(separator: " · ")
    }

    private var videoSummary: String {
        let filename = assetName(plan.video.baseFileId)
        var text = "\(filename) is the base video"
        if durationPlan?.videoShouldLoop == true { text += " and will loop until the final duration" }
        if let start = plan.video.trimStartSeconds { text += ", starting at \(TimeFormatter.display(start))" }
        if let end = plan.video.trimEndSeconds { text += ", ending at \(TimeFormatter.display(end))" }
        return text + "."
    }

    private var audioSummary: String? {
        guard let audio = plan.audio, audio.mode != .none else { return nil }
        switch audio.mode {
        case .replace:
            let loops = durationPlan?.audioLoopCount ?? 1
            return "\(assetName(audio.fileId)) replaces the original audio and plays \(loops) complete loop\(loops == 1 ? "" : "s")."
        case .keepOriginal:
            return "The original video audio will be kept."
        case .mix:
            return "\(assetName(audio.fileId)) will be mixed with the original audio."
        case .none:
            return nil
        }
    }

    private func overlaySummary(_ overlay: OverlayPlan) -> String {
        let end = overlay.endSeconds.map { TimeFormatter.display($0) } ?? "the end"
        return "\(assetName(overlay.fileId)) appears \(overlay.position.rawValue.replacingOccurrences(of: "_", with: " ")) " +
            "from \(TimeFormatter.display(overlay.startSeconds)) to \(end)."
    }

    private func effectSummary(_ effect: EffectPlan) -> String {
        "\(effect.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized) at " +
            "\(TimeFormatter.display(effect.startSeconds)) for \(TimeFormatter.display(effect.durationSeconds))."
    }

    private func assetName(_ id: String?) -> String {
        guard let id else { return "External audio" }
        return assets.first(where: { $0.id == id })?.filename ?? id
    }
}
