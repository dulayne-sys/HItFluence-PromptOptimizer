import Foundation

/// The app contacts ONLY a loopback Ollama instance. No cloud services or API keys.
actor LocalOllamaClient {
    static let shared = LocalOllamaClient()

    private let session: URLSession
    private let loopback = "http://127.0.0.1:11434"

    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 240
        configuration.timeoutIntervalForResource = 300
        session = URLSession(configuration: configuration)
    }

    func installedModelNames() async throws -> [String] {
        let url = try endpoint("/api/tags")
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        do {
            let (data, response) = try await session.data(for: request)
            try validate(response)
            let result = try JSONDecoder().decode(TagResponse.self, from: data)
            return result.models.map(\.name).sorted()
        } catch {
            throw LocalModelError.connection(error.localizedDescription)
        }
    }

    func generate(model: String, input: String, instructions: String) async throws -> String {
        guard !model.isEmpty else { throw LocalModelError.modelNotInstalled }
        let url = try endpoint("/api/chat")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 240
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ChatRequest(
            model: model,
            messages: [
                ChatMessage(role: "system", content: instructions),
                ChatMessage(role: "user", content: PromptRules.userEnvelope(input))
            ],
            stream: false,
            options: .init(temperature: 0.2)
        ))
        do {
            let (data, response) = try await session.data(for: request)
            try Task.checkCancellation()
            try validate(response)
            let result = try JSONDecoder().decode(ChatResponse.self, from: data)
            guard let content = result.message?.content, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw LocalModelError.emptyResponse
            }
            return content
        } catch let error as LocalModelError {
            throw error
        } catch {
            throw LocalModelError.connection(error.localizedDescription)
        }
    }

    private func endpoint(_ path: String) throws -> URL {
        guard let url = URL(string: loopback + path), url.host == "127.0.0.1" else {
            throw LocalModelError.invalidEndpoint
        }
        return url
    }

    private func validate(_ response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
            throw LocalModelError.invalidResponse
        }
    }

    private struct TagResponse: Decodable {
        struct Model: Decodable { let name: String }
        let models: [Model]
    }

    private struct ChatMessage: Codable { let role: String; let content: String }
    private struct ChatRequest: Encodable {
        let model: String
        let messages: [ChatMessage]
        let stream: Bool
        let options: Options
    }
    private struct Options: Encodable { let temperature: Double }
    private struct ChatResponse: Decodable {
        struct Message: Decodable { let content: String? }
        let message: Message?
    }
}

enum LocalModelError: LocalizedError {
    case modelNotInstalled, invalidEndpoint, invalidResponse, emptyResponse, connection(String)
    var errorDescription: String? {
        switch self {
        case .modelNotInstalled: "No matching local model is installed. Open Ollama and install the selected model."
        case .invalidEndpoint: "The local model endpoint is invalid."
        case .invalidResponse: "The local model returned an error. Check Ollama's model status."
        case .emptyResponse: "The local model generated an empty response."
        case .connection(let reason): "Could not use local Ollama: \(reason)"
        }
    }
}
