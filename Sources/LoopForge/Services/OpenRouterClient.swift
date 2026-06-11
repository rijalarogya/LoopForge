import Foundation

struct OpenRouterClient: LLMClient {
    let baseURL: URL
    let apiKey: String
    let model: String

    private var client: OpenAICompatibleClient {
        OpenAICompatibleClient(
            baseURL: baseURL,
            apiKey: apiKey,
            model: model,
            additionalHeaders: [
                "HTTP-Referer": "https://github.com/rijalarogya/LoopForge",
                "X-Title": "LoopForge"
            ]
        )
    }

    func testConnection() async throws -> Bool {
        try await client.testConnection()
    }

    func generateEditIntent(request: EditPlanRequest) async throws -> EditIntent {
        try await client.generateEditIntent(request: request)
    }

    func refinePrompt(request: PromptRefinementRequest) async throws -> String {
        try await client.refinePrompt(request: request)
    }
}
