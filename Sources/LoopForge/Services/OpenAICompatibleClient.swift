import Foundation

struct OpenAICompatibleClient: LLMClient {
    let baseURL: URL
    let apiKey: String
    let model: String
    var additionalHeaders: [String: String] = [:]

    func testConnection() async throws -> Bool {
        guard !apiKey.isEmpty else { throw LLMClientError.missingAPIKey }
        var request = URLRequest(url: baseURL.appendingPathComponent("models"))
        request.httpMethod = "GET"
        addHeaders(to: &request)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw LLMClientError.invalidResponse }
        if !(200..<300).contains(http.statusCode) {
            throw LLMClientError.requestFailed(http.statusCode, "Connection test failed.")
        }
        return true
    }

    func generateEditIntent(request planRequest: EditPlanRequest) async throws -> EditIntent {
        let content = try await chat(
            systemPrompt: EditPlanPromptBuilder.systemPrompt,
            userPrompt: try EditPlanPromptBuilder.userMessage(for: planRequest)
        )
        return try EditIntentDecoder.decode(content)
    }

    func refinePrompt(request refinementRequest: PromptRefinementRequest) async throws -> String {
        let content = try await chat(
            systemPrompt: PromptRefinementPromptBuilder.systemPrompt,
            userPrompt: try PromptRefinementPromptBuilder.userMessage(for: refinementRequest)
        )
        return try PromptRefinementDecoder.decode(content)
    }

    private func chat(systemPrompt: String, userPrompt: String) async throws -> String {
        guard !apiKey.isEmpty else { throw LLMClientError.missingAPIKey }
        let endpoint = baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addHeaders(to: &request)

        let body = ChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt)
            ],
            temperature: 0,
            responseFormat: .init(type: "json_object")
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw LLMClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(APIErrorEnvelope.self, from: data).error.message)
                ?? String(decoding: data, as: UTF8.self)
            throw LLMClientError.requestFailed(http.statusCode, message)
        }
        let envelope = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = envelope.choices.first?.message.content else {
            throw LLMClientError.invalidResponse
        }
        return content
    }

    private func addHeaders(to request: inout URLRequest) {
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        additionalHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }
    }
}

private struct ChatRequest: Encodable {
    let model: String
    let messages: [Message]
    let temperature: Double
    let responseFormat: ResponseFormat

    struct Message: Encodable {
        let role: String
        let content: String
    }

    struct ResponseFormat: Encodable {
        let type: String
    }

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case responseFormat = "response_format"
    }
}

private struct ChatResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String?
    }
}

private struct APIErrorEnvelope: Decodable {
    let error: APIError

    struct APIError: Decodable {
        let message: String
    }
}
