import Foundation

// ServerApiProvider will first speak to a prixy API wrapper
// that will then speak to the specific AI API
class ServerApiProvider: AIProvideable {
    private var apiUrl: String
    private var apiKey: String

    required init(apiKey: String, apiUrl: String) {
        self.apiKey = apiKey
        self.apiUrl = apiUrl
    }

    func query(_ query: String, completion: @escaping (String) -> Void) {
        guard let url = URL(string: apiUrl + "/query") else {
            completion("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Add Content Type
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add bearer token key to the request header
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // Prepare the payload
        let osInfo = SystemUtility.getOperatingSystemInfo()
        let requestBody: [String: Any] = [
            "query": query,
            "systemInfo": osInfo
        ]
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
            guard let data = data else {
                completion("Error: No data received")
                return
            }
            do {
                let serverResponse = try JSONDecoder().decode(ServerResponse.self, from: data)
                completion(serverResponse.content)
            } catch {
                completion("Error: Could not decode the response")
            }
        }.resume()
    }
}
