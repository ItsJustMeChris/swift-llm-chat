import SwiftUI

struct ConfigurationView: View {

    @AppStorage("openRouterApiKey") private var openRouterApiKey: String = ""
    @State private var isEditingApiKey: Bool = false

    @EnvironmentObject var modelManager: ModelManager
    @State private var showingAddModelSheet = false
    @State private var modelToEdit: ModelOption? = nil 
    @State private var selection = Set<ModelOption.ID>()

    var body: some View {

        Form {
            Section("API Configuration") {
                apiKeySection
            }

            Section("Model Management") {

                modelTableSection
                modelActionButtons 
            }
        }

        .padding()
        .frame(minWidth: 480, minHeight: 350) 
        .sheet(isPresented: $showingAddModelSheet) {

            AddModelView()
                .environmentObject(modelManager)
        }

    }

    private var apiKeySection: some View {

        LabeledContent {
            HStack {

                if isEditingApiKey {
                    TextField("API Key", text: $openRouterApiKey)
                } else {
                    SecureField("API Key", text: $openRouterApiKey)
                }

                Button {
                    isEditingApiKey.toggle()
                } label: {
                    Image(systemName: isEditingApiKey ? "eye.slash" : "eye")
                }
                .buttonStyle(.plain) 
            }
            .textFieldStyle(.roundedBorder) 
        } label: {

            Text("OpenRouter API Key")
        }

    }

    private var modelTableSection: some View {
        Table(modelManager.models, selection: $selection) {
            TableColumn("Name", value: \.name).width(min: 100) 
            TableColumn("ID", value: \.id).width(min: 150)
            TableColumn("Description") { model in
                Text(model.description.isEmpty ? "-" : model.description) 
                    .lineLimit(1)
                    .truncationMode(.tail)
            }.width(min: 100)
            TableColumn("Badge") { model in
                 if let badge = model.badge, !badge.isEmpty {
                     Text(badge.uppercased()) 
                         .font(.caption)
                         .padding(.horizontal, 5)
                         .padding(.vertical, 2)
                         .background(Color.secondary.opacity(0.15))
                         .cornerRadius(5)
                         .foregroundColor(.secondary)
                 } else {
                     Text("-") 
                 }
            }.width(ideal: 60) 
        }
        .frame(minHeight: 150, idealHeight: 200) 
    }

    private var modelActionButtons: some View {
        HStack {

            Button {
                showingAddModelSheet = true
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.bordered) 
            .help("Add a new model")

            Button {
                removeSelectedModels()
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.bordered) 
            .disabled(selection.isEmpty)
            .help("Remove selected model(s)")

            Spacer() 
        }

    }

    private func removeSelectedModels() {
        let modelsToRemove = modelManager.models.filter { selection.contains($0.id) }
        modelManager.models.removeAll { modelsToRemove.contains($0) } 
        selection.removeAll()
    }
}

struct AddModelView: View {
    @EnvironmentObject var modelManager: ModelManager
    @Environment(\.dismiss) var dismiss

    @State private var modelId: String = ""
    @State private var modelName: String = ""
    @State private var modelDescription: String = ""
    @State private var modelBadge: String = ""

    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {

        Form {
            Section { 
                LabeledContent("Model ID") {
                    TextField("unique-id (e.g., provider/model)", text: $modelId)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent("Display Name") {
                    TextField("User-Friendly Name", text: $modelName)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent("Description") {
                    TextField("Optional details", text: $modelDescription)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent("Badge") {
                    TextField("Optional short tag (e.g., FREE)", text: $modelBadge)
                        .textFieldStyle(.roundedBorder)
                }
            }

            if showError {
                 Section { 
                     Text(errorMessage)
                         .foregroundColor(.red)
                         .font(.callout) 
                 }
            }
        }
        .padding()
        .frame(minWidth: 350, idealWidth: 400) 
        .navigationTitle("Add New Model") 
        .toolbar { 
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    addModel()
                }
                .disabled(modelId.isEmpty || modelName.isEmpty) 
            }
        }
    }

    private func addModel() {
        guard !modelId.isEmpty, !modelName.isEmpty else {
            errorMessage = "Model ID and Name cannot be empty."
            showError = true
            return
        }

        if modelManager.models.contains(where: { $0.id.lowercased() == modelId.lowercased() }) {
             errorMessage = "A model with this ID already exists."
             showError = true
             return
        }

        let newModel = ModelOption(
            id: modelId.trimmingCharacters(in: .whitespacesAndNewlines),
            name: modelName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: modelDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            badge: modelBadge.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : modelBadge.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        modelManager.addModel(newModel)
        dismiss()
    }
}

struct ConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        ConfigurationView()
            .environmentObject(ModelManager()) 
    }
}
