import SwiftUI

struct DestinationPickerView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        GroupBox("Save video to") {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "folder")
                        .foregroundStyle(.tint)
                    Text(viewModel.destinationFolder.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    Spacer()
                    Button("Choose Folder") {
                        viewModel.chooseDestination()
                    }
                }
                LabeledContent("Output filename") {
                    TextField("loopforge-output.mp4", text: $viewModel.outputFilename)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 280)
                        .onSubmit {
                            if let filename = FileHelpers.safeOutputFilename(viewModel.outputFilename) {
                                viewModel.outputFilename = filename
                            }
                        }
                }
            }
            .padding(.vertical, 4)
        }
    }
}
