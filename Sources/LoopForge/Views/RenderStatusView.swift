import SwiftUI

struct RenderStatusView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        if viewModel.state == .rendering || viewModel.state == .completed {
            GroupBox("Render Status") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(viewModel.state.label)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(Int(viewModel.progress * 100))%")
                            .monospacedDigit()
                    }
                    ProgressView(value: viewModel.progress)
                    if let duration = viewModel.validatedPlan?.durationPlan.finalDurationSeconds {
                        Text("Processed \(TimeFormatter.display(viewModel.processedSeconds)) of \(TimeFormatter.display(duration))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let outputURL = viewModel.outputURL {
                        HStack {
                            Text(outputURL.path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                            Spacer()
                            Button("Show in Finder") {
                                viewModel.revealOutput()
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}
