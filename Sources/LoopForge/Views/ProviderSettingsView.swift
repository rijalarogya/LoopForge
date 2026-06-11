import SwiftUI

struct ProviderSettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject private var settings: SettingsStore

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
        settings = viewModel.settings
    }

    var body: some View {
        GroupBox("AI Provider") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Provider", selection: $settings.provider) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .pickerStyle(.segmented)

                switch settings.provider {
                case .openAICompatible:
                    providerFields(
                        baseURL: $settings.openAIBaseURL,
                        model: $settings.openAIModel,
                        apiKey: $viewModel.openAIKey
                    )
                case .openRouter:
                    providerFields(
                        baseURL: $settings.openRouterBaseURL,
                        model: $settings.openRouterModel,
                        apiKey: $viewModel.openRouterKey
                    )
                case .ollama:
                    LabeledContent("Base URL") {
                        TextField("http://localhost:11434", text: $settings.ollamaBaseURL)
                            .textFieldStyle(.roundedBorder)
                    }
                    LabeledContent("Model") {
                        TextField("llama3.1:8b", text: $settings.ollamaModel)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                DisclosureGroup("FFmpeg paths", isExpanded: $viewModel.showSettings) {
                    VStack(spacing: 8) {
                        LabeledContent("FFmpeg") {
                            TextField("Auto-detect", text: $settings.ffmpegOverride)
                                .textFieldStyle(.roundedBorder)
                        }
                        LabeledContent("ffprobe") {
                            TextField("Auto-detect", text: $settings.ffprobeOverride)
                                .textFieldStyle(.roundedBorder)
                        }
                        HStack {
                            Text("Detected: \(viewModel.resolvedPaths.ffmpeg ?? "FFmpeg missing")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                    .padding(.top, 8)
                }

                HStack {
                    Spacer()
                    Button("Test Connection") {
                        viewModel.testConnection()
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func providerFields(
        baseURL: Binding<String>,
        model: Binding<String>,
        apiKey: Binding<String>
    ) -> some View {
        LabeledContent("Base URL") {
            TextField("https://api.example.com/v1", text: baseURL)
                .textFieldStyle(.roundedBorder)
        }
        LabeledContent("Model") {
            TextField("Model name", text: model)
                .textFieldStyle(.roundedBorder)
        }
        LabeledContent("API key") {
            SecureField("Required", text: apiKey)
                .textFieldStyle(.roundedBorder)
        }
    }
}
