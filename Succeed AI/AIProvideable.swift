protocol AIProvideable {
    init(apiKey: String)
    func sendQuery(_ query: String, completion: @escaping (String) -> Void)
}
