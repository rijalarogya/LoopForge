import SwiftUI

struct MainView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 18) {
                    DropZoneView(viewModel: viewModel)
                    if !viewModel.assets.isEmpty {
                        FileListView(viewModel: viewModel)
                    }
                    PromptEditorView(viewModel: viewModel)
                    DestinationPickerView(viewModel: viewModel)
                    ExportSettingsView(viewModel: viewModel)
                    ProviderSettingsView(viewModel: viewModel)
                    actionBar
                    RenderStatusView(viewModel: viewModel)
                }
                .padding(24)
            }
        }
        .sheet(isPresented: planSheetBinding) {
            if let plan = viewModel.editPlan {
                PlanPreviewView(
                    plan: plan,
                    durationPlan: viewModel.validatedPlan?.durationPlan,
                    exportSettings: viewModel.validatedPlan?.exportSettings,
                    assets: viewModel.assets
                ) {
                    viewModel.render()
                } onCancel: {
                    viewModel.cancelPlan()
                }
            }
        }
        .sheet(isPresented: $viewModel.showLogs) {
            LogsView(logs: viewModel.logs)
        }
        .sheet(isPresented: $viewModel.showReadinessMessage) {
            readinessView
        }
        .alert("LoopForge", isPresented: errorBinding) {
            Button("OK") {
                viewModel.errorMessage = nil
                if case .failed = viewModel.state {
                    viewModel.state = viewModel.assets.isEmpty ? .idle : .ready
                }
            }
            Button("Show Logs") {
                viewModel.errorMessage = nil
                viewModel.showLogs = true
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var readinessView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 36))
                .foregroundStyle(.blue)
            Text("Welcome to LoopForge")
                .font(.title2.bold())
            Text(
                "Video processing runs locally. To interpret prompts, choose OpenAI-Compatible " +
                "or OpenRouter and enter your own API key, or run Ollama on this Mac."
            )
            .foregroundStyle(.secondary)
            Text("LoopForge does not include or operate a hosted AI service.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Continue") {
                    viewModel.dismissReadinessMessage()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 480)
        .interactiveDismissDisabled()
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("LoopForge")
                    .font(.title2.bold())
                Text("Create videos from files using natural language and FFmpeg.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Label(viewModel.state.label, systemImage: stateIcon)
                .foregroundStyle(stateColor)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var actionBar: some View {
        HStack {
            Button("Clear", action: viewModel.clear)
            Button("Show Logs") {
                viewModel.showLogs = true
            }
            Spacer()
            if viewModel.state == .rendering {
                Button("Cancel Render", role: .destructive) {
                    viewModel.cancelRender()
                }
            }
            Button {
                viewModel.start()
            } label: {
                if viewModel.state == .generatingPlan || viewModel.state == .validatingPlan {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Start")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canStart)
            .keyboardShortcut(.return, modifiers: [.command])
        }
    }

    private var planSheetBinding: Binding<Bool> {
        Binding(
            get: { viewModel.state == .awaitingRenderConfirmation && viewModel.editPlan != nil },
            set: { visible in
                if !visible && viewModel.state == .awaitingRenderConfirmation {
                    viewModel.cancelPlan()
                }
            }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private var stateIcon: String {
        switch viewModel.state {
        case .rendering, .generatingPlan, .validatingPlan, .analyzingFiles:
            return "arrow.triangle.2.circlepath"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        default:
            return "circle.fill"
        }
    }

    private var stateColor: Color {
        switch viewModel.state {
        case .completed: return .green
        case .failed: return .red
        case .rendering, .generatingPlan, .validatingPlan, .analyzingFiles: return .blue
        default: return .secondary
        }
    }
}
