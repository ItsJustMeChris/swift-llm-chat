import Foundation
import Combine
import SwiftUI // Needed for ObservableObject

class ModelManager: ObservableObject {
    @Published var models: [ModelOption] = [] {
        didSet {
            saveModels()
        }
    }

    private let userDefaultsKey = "userDefinedModels"
    private let defaultModels: [ModelOption] = [
        // Provide some sensible defaults in case storage is empty
        .init(id: "openrouter/quasar-alpha", name: "Quasar Alpha", description: "Default model", badge: "DEFAULT"),
        .init(id: "meta-llama/llama-4-maverick:free", name: "Llama 4 Maverick", description: "Free Llama model", badge: "LLAMA")
    ]

    init() {
        loadModels()
    }

    func addModel(_ model: ModelOption) {
        // Prevent duplicates based on ID
        if !models.contains(where: { $0.id == model.id }) {
            models.append(model)
        } else {
            // Optionally provide feedback that the model ID already exists
            print("Model with ID \(model.id) already exists.")
        }
    }

    func removeModel(at offsets: IndexSet) {
        models.remove(atOffsets: offsets)
    }
    
    func removeModel(_ model: ModelOption) {
        models.removeAll { $0.id == model.id }
    }

    private func saveModels() {
        if let encoded = try? JSONEncoder().encode(models) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    private func loadModels() {
        if let savedModels = UserDefaults.standard.data(forKey: userDefaultsKey) {
            if let decodedModels = try? JSONDecoder().decode([ModelOption].self, from: savedModels) {
                // Ensure we always have at least the defaults if storage somehow becomes empty after initial load
                if decodedModels.isEmpty {
                     models = defaultModels
                     saveModels() // Save defaults if storage was empty
                } else {
                     models = decodedModels
                }
                return
            }
        }
        // If loading fails or no data exists, load defaults
        models = defaultModels
        saveModels() // Save defaults for the first time
    }
    
    // Helper to get the first available model, useful for defaults elsewhere
    func getDefaultModel() -> ModelOption? {
        return models.first
    }
}
