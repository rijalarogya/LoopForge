import Foundation

struct OllamaClient: LLMClient {
    let baseURL: URL
    let model: String

    func testConnection() async throws -> Bool {
        let request = URLRequest(url: baseURL.appendingPathComponent("api/tags"))
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw LLMClientError.ollamaUnavailable
            }
            return true
        } catch let error as LLMClientError {
            throw error
        } catch {
            throw LLMClientError.ollamaUnavailable
        }
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
        var request = URLRequest(url: baseURL.appendingPathComponent("api/chat"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = OllamaChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt)
            ],
            stream: false,
            format: "json",
            options: .init(temperature: 0)
        )
        request.httpBody = try JSONEncoder().encode(body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw LLMClientError.invalidResponse }
            guard (200..<300).contains(http.statusCode) else {
                throw LLMClientError.requestFailed(http.statusCode, String(decoding: data, as: UTF8.self))
            }
            let envelope = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
            return envelope.message.content
        } catch let error as LLMClientError {
            throw error
        } catch {
            throw LLMClientError.ollamaUnavailable
        }
    }
}

private struct OllamaChatRequest: Encodable {
    let model: String
    let messages: [Message]
    let stream: Bool
    let format: String
    let options: Options

    struct Message: Encodable {
        let role: String
        let content: String
    }

    struct Options: Encodable {
        let temperature: Double
    }
}

private struct OllamaChatResponse: Decodable {
    let message: Message

    struct Message: Decodable {
        let content: String
    }
}
