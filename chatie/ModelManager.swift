import Foundation
import Combine
import SwiftUI 

class ModelManager: ObservableObject {
    @Published var models: [ModelOption] = [] {
        didSet {
            saveModels()
        }
    }

    private let userDefaultsKey = "userDefinedModels"
    private let defaultModels: [ModelOption] = [

        .init(id: "openrouter/quasar-alpha", name: "Quasar Alpha", description: "Default model", badge: "DEFAULT"),
        .init(id: "meta-llama/llama-4-maverick:free", name: "Llama 4 Maverick", description: "Free Llama model", badge: "LLAMA")
    ]

    init() {
        loadModels()
    }

    func addModel(_ model: ModelOption) {

        if !models.contains(where: { $0.id == model.id }) {
            models.append(model)
        } else {

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

                if decodedModels.isEmpty {
                     models = defaultModels
                     saveModels() 
                } else {
                     models = decodedModels
                }
                return
            }
        }

        models = defaultModels
        saveModels() 
    }

    func getDefaultModel() -> ModelOption? {
        return models.first
    }
}
