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

            // Prefer gemma3 > qwen3 > llama3 > mistral > first available
            let preferredModels = ["gemma3", "qwen3", "llama3", "mistral"]
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

    // MARK: - Retrospective Analysis
    
    /// Generate a daily retrospective analysis from a list of sessions
    func generateRetrospective(sessions: [TranscriptionSession], customPrompt: String? = nil) async throws -> String {
        guard !sessions.isEmpty else {
            return "No voice memos found for this date."
        }
        
        // Ensure we have a model
        if defaultModel == nil {
            defaultModel = await detectDefaultModel()
        }
        
        guard let model = defaultModel else {
            throw OllamaError.modelUnavailable
        }
        
        // Format sessions for the prompt
        let formattedSessions = sessions.map { session in
            let time = session.timestamp.formatted(date: .omitted, time: .shortened)
            let app = session.targetAppName ?? "Unknown App"
            // Use sanitized text if available, otherwise original text
            let content = session.sanitizedText ?? session.text
            return "[\(app)] (\(time)): \(content)"
        }.joined(separator: "\n\n")
        
        let systemInstruction = customPrompt ?? """
        You are a personal retrospective assistant. Analyze the following voice memos recorded throughout the day.
        
        Group your analysis by Application Context (e.g., Slack, Notes, Cursor).
        
        For each group:
        1. Summarize the key themes or tasks.
        2. Identify any action items or outstanding questions.
        3. Provide a brief "Insight" or "Reflection" on the content.
        
        Finally, provide a "Daily Synthesis" summarizing the overall day.
        
        Format the output in Markdown.
        """
        
        let prompt = """
        \(systemInstruction)
        
        ---
        VOICE MEMOS:
        
        \(formattedSessions)
        """
        
        return try await callOllama(
            model: model,
            prompt: prompt,
            temperature: 0.7, // Higher creativity for analysis
            numPredict: 2000  // Allow longer response
        )
    }

    // MARK: - Dashboard Insight

    func generateDashboardInsight(voiceWords: Int, typedWords: Int, voiceWpm: Double, typedWpm: Double, topApp: String?, keyboardStats: [(keyboard: String, wpm: Double)], hourlyPattern: String) async -> String {
        if defaultModel == nil {
            defaultModel = await detectDefaultModel()
        }

        guard let model = defaultModel else {
            return fallbackInsight(voiceWords: voiceWords, typedWords: typedWords)
        }

        let total = voiceWords + typedWords
        let prompt = """
        You are a concise writing coach. Given today's productivity data, write ONE sentence (max 15 words) that's specific and encouraging. No emojis. No generic praise. Reference the actual numbers or patterns.

        Today: \(total) words (\(voiceWords) voice, \(typedWords) typed)
        Voice WPM: \(Int(voiceWpm)), Typed WPM: \(Int(typedWpm))
        Top app: \(topApp ?? "unknown")
        \(keyboardStats.isEmpty ? "" : "Keyboards: " + keyboardStats.map { "\($0.keyboard) at \(Int($0.wpm)) WPM" }.joined(separator: ", "))
        Activity: \(hourlyPattern)

        Write ONLY the one sentence, nothing else.
        """

        do {
            return try await callOllama(model: model, prompt: prompt, temperature: 0.7, numPredict: 40)
        } catch {
            return fallbackInsight(voiceWords: voiceWords, typedWords: typedWords)
        }
    }

    // MARK: - Dashboard Insight Bullets

    func generateInsightBullets(context: String) async -> [String] {
        if defaultModel == nil {
            defaultModel = await detectDefaultModel()
        }

        guard let model = defaultModel else {
            return ["Ollama not available — check if it's running."]
        }

        do {
            let response = try await callOllama(model: model, prompt: context, temperature: 0.7, numPredict: 200)
            let bullets = response
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(4)
            return Array(bullets)
        } catch {
            return ["Could not generate insights. Is Ollama running?"]
        }
    }

    private func fallbackInsight(voiceWords: Int, typedWords: Int) -> String {
        let total = voiceWords + typedWords
        if total == 0 { return "Ready to start capturing." }
        let dominant = voiceWords > typedWords ? "voice" : "typing"
        return "\(total) words today, mostly \(dominant)."
    }

    // MARK: - Ollama API Call

    private func callOllama(model: String, prompt: String, temperature: Double = 0.3, numPredict: Int = 50) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            throw OllamaError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60.0 // Extended timeout for analysis

        let requestBody = GenerateRequest(
            model: model,
            prompt: prompt,
            stream: false,
            options: GenerateOptions(
                temperature: temperature,
                num_predict: numPredict
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
    
    enum CodingKeys: String, CodingKey {
        case temperature
        case num_predict
    }
    
    init(temperature: Double, num_predict: Int) {
        self.temperature = temperature
        self.num_predict = num_predict
    }
}

struct GenerateResponse: Codable {
    let response: String
    let done: Bool
}

enum OllamaError: Error {
    case invalidURL
    case requestFailed
    case invalidResponse
    case modelUnavailable
}
