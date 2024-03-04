protocol AIProvideable {
    init(apiKey: String, apiUrl: String)
    func sendQuery(_ query: String, completion: @escaping (String) -> Void)
}
