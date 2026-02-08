import Foundation

/// Service for interacting with local Ollama instance
@MainActor
class OllamaService {
    static let shared = OllamaService()

    private let baseURL = "http://localhost:11434"
    private var defaultModel: String?
    private var tagSuggestionsCache: [UUID: [String]] = [:]

    private init() {}

    // MARK: - Model Detection

    /// Auto-detect the best available Ollama model
    func detectDefaultModel() async -> String? {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ModelsResponse.self, from: data)

            // Prefer llama3 > llama2 > mistral > first available
            let preferredModels = ["llama3", "llama2", "mistral"]
            for preferred in preferredModels {
                if let model = response.models.first(where: { $0.name.contains(preferred) }) {
                    return model.name
                }
            }

            // Return first available model
            return response.models.first?.name
        } catch {
            print("Failed to detect Ollama models: \(error)")
            return nil
        }
    }

    // MARK: - Tag Generation

    /// Generate intelligent tag suggestions using LLM
    func generateTags(for text: String, app: String?, existingTags: [String], sessionID: UUID) async -> [String] {
        // Check cache first
        if let cached = tagSuggestionsCache[sessionID] {
            return cached
        }

        // Ensure we have a model
        if defaultModel == nil {
            defaultModel = await detectDefaultModel()
        }

        guard let model = defaultModel else {
            print("No Ollama model available")
            return []
        }

        // Construct prompt
        let appContext = app.map { "App: \($0)" } ?? ""
        let existingContext = existingTags.isEmpty ? "" : "Existing tags in system: \(existingTags.joined(separator: ", "))"

        let prompt = """
        Given this transcribed text and context, suggest 2-4 relevant tags.

        Text: "\(text.prefix(300))"
        \(appContext)
        \(existingContext)

        Suggest concise, lowercase tags that categorize this content.
        Focus on: topic, purpose, urgency, context.
        Return ONLY a comma-separated list of tags, nothing else.
        Example: work, meeting, important
        """

        do {
            let tags = try await callOllama(model: model, prompt: prompt)

            // Parse comma-separated response
            let suggestions = tags
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty && $0.count <= 20 } // Reasonable tag length
                .prefix(4) // Max 4 suggestions

            let result = Array(suggestions)

            // Cache the result
            tagSuggestionsCache[sessionID] = result

            return result
        } catch {
            print("LLM tag generation failed: \(error)")
            return []
        }
    }

    // MARK: - Ollama API Call

    private func callOllama(model: String, prompt: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            throw OllamaError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5.0 // 5 second timeout

        let requestBody = GenerateRequest(
            model: model,
            prompt: prompt,
            stream: false,
            options: GenerateOptions(
                temperature: 0.3, // More consistent
                num_predict: 50   // Short responses
            )
        )

        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OllamaError.requestFailed
        }

        let generateResponse = try JSONDecoder().decode(GenerateResponse.self, from: data)
        return generateResponse.response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Cache Management

    func clearCache() {
        tagSuggestionsCache.removeAll()
    }
}

// MARK: - Models

struct ModelsResponse: Codable {
    let models: [OllamaModel]
}

struct OllamaModel: Codable {
    let name: String
}

struct GenerateRequest: Codable {
    let model: String
    let prompt: String
    let stream: Bool
    let options: GenerateOptions
}

struct GenerateOptions: Codable {
    let temperature: Double
    let num_predict: Int
}

struct GenerateResponse: Codable {
    let response: String
    let done: Bool
}

enum OllamaError: Error {
    case invalidURL
    case requestFailed
    case invalidResponse
}
