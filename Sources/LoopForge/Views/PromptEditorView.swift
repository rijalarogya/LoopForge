import SwiftUI

struct PromptEditorView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        GroupBox("What do you want to create?") {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    if viewModel.prompt.isEmpty {
                        Text("Example: Loop @background.mp4 until @music.mp3 ends, add @logo.png to the top right for the first 10 seconds, and fade to black at the end.")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $viewModel.prompt)
                        .font(.body)
                        .frame(minHeight: 105)
                        .scrollContentBackground(.hidden)
                        .padding(.bottom, 28)

                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                viewModel.refinePrompt()
                            } label: {
                                if viewModel.isRefiningPrompt {
                                    ProgressView()
                                        .controlSize(.small)
                                        .frame(width: 18, height: 18)
                                } else {
                                    Image(systemName: "wand.and.sparkles")
                                        .frame(width: 18, height: 18)
                                }
                            }
                            .buttonStyle(.borderless)
                            .disabled(
                                viewModel.isRefiningPrompt ||
                                viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            )
                            .help("Refine the prompt using supported instructions")
                            .accessibilityLabel("Refine prompt")
                            .padding(8)
                        }
                    }
                }
                if !viewModel.mentionSuggestions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(viewModel.mentionSuggestions) { asset in
                                Button("@\(asset.filename)") {
                                    viewModel.insertMention(asset)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
                Text("Type @ to reference an uploaded file.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }
}
