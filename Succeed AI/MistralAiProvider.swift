import Foundation

class MistralAiProvider: AIProvideable {
    private var aiUrl: String = "https://api.mistralai.com"
    private var apiKey: String = "" // replace with your actual API key

    func sendQuery(_ query: String, completion: @escaping (String) -> Void) {
        // Define the URL and request parameters
        // Replace with the actual API endpoint and your API key
        guard let url = URL(string: aiUrl + "/query") else {
            completion("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = ["query": query]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion("Error: Unable to encode request body")
            return
        }

        // Perform the network request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion("Error: \(error.localizedDescription)")
                return
            }
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                completion(responseString)
            } else {
                completion("Error: No data received")
            }
        }.resume()
    }
}
