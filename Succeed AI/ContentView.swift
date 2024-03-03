import SwiftUI

struct ContentView: View {
    @State private var inputText: String = ""
    @State private var outputText: String = ""
    var aiService: AIProvideable

    init(aiService: AIProvideable) {
        self.aiService = aiService
    }
    
    var body: some View {
        VStack {
            TextField("Enter your query", text: $inputText)
                .padding()

            Button("Send Request") {
                aiService.sendQuery(inputText) { response in
                    DispatchQueue.main.async {
                        self.outputText = response
                    }
                }
            }

            Text(outputText)
                .padding()
        }
        .frame(width: 400, height: 300)
    }
}
