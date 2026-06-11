import Foundation

enum AppState: Equatable {
    case idle
    case analyzingFiles
    case ready
    case generatingPlan
    case validatingPlan
    case awaitingRenderConfirmation
    case rendering
    case completed
    case failed(String)

    var label: String {
        switch self {
        case .idle: return "Idle"
        case .analyzingFiles: return "Analyzing files"
        case .ready: return "Ready"
        case .generatingPlan: return "Generating edit plan"
        case .validatingPlan: return "Validating edit plan"
        case .awaitingRenderConfirmation: return "Ready to render"
        case .rendering: return "Rendering"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
}

enum AIProvider: String, CaseIterable, Identifiable {
    case openAICompatible = "OpenAI-Compatible"
    case openRouter = "OpenRouter"
    case ollama = "Ollama Local"

    var id: String { rawValue }
}
