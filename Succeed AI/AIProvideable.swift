protocol AIProvideable {
    func sendQuery(_ query: String, completion: @escaping (String) -> Void)
}
