import Foundation

// ServerApiProvider will first speak to a prixy API wrapper
// that will then speak to the specific AI API
class ServerApiProvider: AIProvideable {
    private var apiUrl: String
    private var apiKey: String
    private var licenseKey: String

    required init(apiKey: String, apiUrl: String) {
        self.apiKey = apiKey
        self.apiUrl = apiUrl
        self.licenseKey = "1:license needs to be stored in the user AppStorage" // format: <LICENSE_ID>:<LICENSE_KEY>
    }

    func query(_ query: String, completion: @escaping (String) -> Void) -> Void {
        guard let url = URL(string: apiUrl + "/query") else {
            completion("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Add Content Type
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add bearer token key to the request header
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // Add license key to header
        request.setValue(licenseKey, forHTTPHeaderField: "License")

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
                completion("Oops: Couldn't retrieve the response from AI server.")
            }
        }.resume()
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
