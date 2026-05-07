import Foundation

// ServerApiProvider speaks to the product API wrapper, which then calls the AI provider.
class ServerApiProvider: AIProvideable {
    private var apiUrl: String
    private var apiKey: String

    required init(apiKey: String, apiUrl: String) {
        self.apiKey = apiKey
        self.apiUrl = apiUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    func query(_ query: String, completion: @escaping (Result<String, AIProviderError>) -> Void) -> Void {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, apiKey != "api_key" else {
            completion(.failure(AIProviderError(userMessage: "SucceedAI is not configured: missing API key.")))
            return
        }

        guard let url = URL(string: apiUrl + "/query") else {
            completion(.failure(AIProviderError(userMessage: "SucceedAI is not configured: invalid API URL.")))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60

        // Add Content Type
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add bearer token key to the request header
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        if let licenseKey = UserDefaults.standard.string(forKey: "licenseKey")?.trimmingCharacters(in: .whitespacesAndNewlines),
           !licenseKey.isEmpty {
            request.setValue(licenseKey, forHTTPHeaderField: "License")
        }

        // Prepare the payload
        let osInfo = SystemUtility.getOperatingSystemInfo()
        let formattedQuery = getAiInstructions(query)

        let requestBody: [String: Any] = [
            "query": formattedQuery,
            "systemInfo": osInfo
        ]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(AIProviderError(userMessage: "SucceedAI could not prepare the AI request.")))
            return
        }

        // Perform the network request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(AIProviderError(userMessage: "SucceedAI could not reach the AI service: \(error.localizedDescription)")))
                return
            }

            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                completion(.failure(AIProviderError(userMessage: self.userMessage(for: httpResponse.statusCode))))
                return
            }

            guard let data = data else {
                completion(.failure(AIProviderError(userMessage: "SucceedAI did not receive a response from the AI service.")))
                return
            }

            do {
                let serverResponse = try JSONDecoder().decode(ServerResponse.self, from: data)
                let content = serverResponse.content.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !content.isEmpty else {
                    completion(.failure(AIProviderError(userMessage: "SucceedAI received an empty AI response.")))
                    return
                }

                completion(.success(content))
            } catch {
                completion(.failure(AIProviderError(userMessage: "SucceedAI could not read the AI response.")))
            }
        }.resume()
    }

    private func userMessage(for statusCode: Int) -> String {
        switch statusCode {
        case 401, 403:
            return "SucceedAI could not authenticate with the AI service. Check the production API token."
        case 413:
            return "This prompt is too long for the AI service. Shorten it and try again."
        case 429:
            return "The AI service is busy or rate limited. Wait a moment and try again."
        case 500...599:
            return "The AI service is temporarily unavailable. Try again shortly."
        default:
            return "The AI service returned an unexpected response."
        }
    }

    func getAiInstructions(_ query: String) -> String {
        let instructionQuery = """
Follow the instruction from the text in triple quotes below:
\"\"\"\(query)\"\"\"

Do not return anything else other than the given instruction. Do not even mention any prefix wordings before the expecting response. ONLY the needed response, NOTHING ELSE. Do NOT wrap responses in quotes.
"""

        return instructionQuery
    }
}
