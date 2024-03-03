import Foundation

class UserSettings: ObservableObject {
    @Published var fontSize: Double {
        didSet {
            UserDefaults.standard.set(fontSize, forKey: "fontSize")
        }
    }
    
    init() {
        self.fontSize = UserDefaults.standard.double(forKey: "fontSize")
        if self.fontSize == 0 {
            self.fontSize = 12.0  // Default Value
        }
    }
}
