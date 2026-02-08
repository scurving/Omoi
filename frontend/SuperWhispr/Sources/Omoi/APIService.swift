
import Foundation
import Combine

enum BackendError: LocalizedError {
    case notRunning
    case startupInProgress

    var errorDescription: String? {
        switch self {
        case .notRunning:
            return "Backend server is not available. Please try again in a moment."
        case .startupInProgress:
            return "Backend server is starting up. Please wait..."
        }
    }
}

struct TranscriptionResponse: Codable {
    let transcription: String
    let speech_duration: Double?  // Actual speech time from Whisper segments (excludes silence)
}

struct SynthesisResponse: Codable {
    let audio_data: String
    let sampling_rate: Int
}

struct SanitizeRequest: Codable {
    let text: String
    let instructions: String
}

struct SanitizeResponse: Codable {
    let sanitized_text: String
}

class APIService {
    private let baseURL = URL(string: "http://127.0.0.1:58724")!

    func transcribeAudio(fileURL: URL) -> AnyPublisher<TranscriptionResponse, Error> {
        // Check backend status
        switch BackendManager.shared.status {
        case .failed(_):
            return Fail(error: BackendError.notRunning)
                .eraseToAnyPublisher()
        case .starting:
            return Fail(error: BackendError.startupInProgress)
                .eraseToAnyPublisher()
        case .stopped:
            return Fail(error: BackendError.notRunning)
                .eraseToAnyPublisher()
        case .running:
            break
        }

        let url = baseURL.appendingPathComponent("transcribe")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var data = Data()
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        if let audioData = try? Data(contentsOf: fileURL) {
            data.append(audioData)
        }
        data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = data

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                guard (200...299).contains(httpResponse.statusCode) else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw NSError(domain: "TranscriptionError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
                return data
            }
            .decode(type: TranscriptionResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func synthesizeText(text: String) -> AnyPublisher<Data, Error> {
        // Check backend status
        switch BackendManager.shared.status {
        case .failed(_):
            return Fail(error: BackendError.notRunning)
                .eraseToAnyPublisher()
        case .starting:
            return Fail(error: BackendError.startupInProgress)
                .eraseToAnyPublisher()
        case .stopped:
            return Fail(error: BackendError.notRunning)
                .eraseToAnyPublisher()
        case .running:
            break
        }

        let url = baseURL.appendingPathComponent("synthesize")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["text": text]
        request.httpBody = try? JSONEncoder().encode(body)

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                guard (200...299).contains(httpResponse.statusCode) else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw NSError(domain: "SynthesisError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
                let synthesisResponse = try JSONDecoder().decode(SynthesisResponse.self, from: data)
                return Data(hexString: synthesisResponse.audio_data) ?? Data()
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func sanitizeText(text: String, instructions: String) async throws -> String {
        // Check backend status
        switch BackendManager.shared.status {
        case .failed(_):
            throw BackendError.notRunning
        case .starting:
            throw BackendError.startupInProgress
        case .stopped:
            throw BackendError.notRunning
        case .running:
            break
        }

        let url = baseURL.appendingPathComponent("sanitize")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let sanitizeRequest = SanitizeRequest(text: text, instructions: instructions)
        request.httpBody = try JSONEncoder().encode(sanitizeRequest)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        switch httpResponse.statusCode {
        case 200:
            let sanitizeResponse = try JSONDecoder().decode(SanitizeResponse.self, from: data)
            return sanitizeResponse.sanitized_text
        case 400:
            throw SanitizationError.invalidInput
        case 503:
            throw SanitizationError.ollamaNotRunning
        case 504:
            throw SanitizationError.timeout
        default:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SanitizationError.serverError(errorMessage)
        }
    }
}

enum SanitizationError: LocalizedError {
    case invalidInput
    case ollamaNotRunning
    case timeout
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "Text or instructions cannot be empty"
        case .ollamaNotRunning:
            return "Ollama is not running. Please start Ollama and try again."
        case .timeout:
            return "Sanitization request timed out. Please try again."
        case .serverError(let message):
            return "Sanitization failed: \(message)"
        }
    }
}

extension Data {
    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        var i = hexString.startIndex
        for _ in 0..<len {
            let j = hexString.index(i, offsetBy: 2)
            let bytes = hexString[i..<j]
            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            } else {
                return nil
            }
            i = j
        }
        self = data
    }
}
