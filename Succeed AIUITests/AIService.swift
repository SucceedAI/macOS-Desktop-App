protocol AIService {
    func fetchSuggestions(for query: String, completion: @escaping (Result<String, Error>) -> Void)
}
