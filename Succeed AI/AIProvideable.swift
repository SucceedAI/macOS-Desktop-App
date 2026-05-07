import Foundation

struct AIProviderError: LocalizedError, Equatable {
    let userMessage: String

    var errorDescription: String? {
        userMessage
    }
}

protocol AIProvideable {
    init(apiKey: String, apiUrl: String)
    func query(_ query: String, completion: @escaping (Result<String, AIProviderError>) -> Void) -> Void
    func getAiInstructions(_ query: String) -> String
}
