protocol AIProvideable {
    init(apiKey: String, apiUrl: String)
    func query(_ query: String, completion: @escaping (String) -> Void) -> Void
    func getAiInstructions(_ query: String) -> String
}
