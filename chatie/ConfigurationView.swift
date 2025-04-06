import SwiftUI

struct ConfigurationView: View {
    // API Key Section
    @AppStorage("openRouterApiKey") private var openRouterApiKey: String = ""
    @State private var isEditingApiKey: Bool = false

    // Model Management Section
    @EnvironmentObject var modelManager: ModelManager
    @State private var showingAddModelSheet = false
    @State private var modelToEdit: ModelOption? = nil
    @State private var selection = Set<ModelOption.ID>() // For Table selection

    var body: some View {
        // Use VStack with padding for overall structure, Form for sections
        VStack {
            Form {
                Section("API Configuration") { // Use String directly for Section header
                    apiKeySection
                }

                Section("Model Management") {
                    modelTableSection // Renamed from modelListSection
                }
            }
            // Add a bottom bar for controls
            HStack {
                Button {
                    showingAddModelSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add a new model")

                Button {
                    removeSelectedModels()
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selection.isEmpty) // Disable if nothing is selected
                .help("Remove selected model(s)")
                
                Spacer() // Pushes buttons to the left
            }
            .padding([.horizontal, .bottom])
        }
        .frame(minWidth: 450, minHeight: 350) // Adjusted size
        .sheet(isPresented: $showingAddModelSheet) {
            AddModelView() // Keep AddModelView as is for now
                // Pass the manager to the sheet if it needs to add directly
                .environmentObject(modelManager)
        }
        // Optional: Add sheet for editing existing models if needed
        // .sheet(item: $modelToEdit) { model in
        //     EditModelView(model: model)
        //         .environmentObject(modelManager)
        // }
    }

    // Extracted API Key View using LabeledContent
    private var apiKeySection: some View {
        LabeledContent { // Use LabeledContent for standard alignment
            HStack {
                if isEditingApiKey {
                    TextField("API Key", text: $openRouterApiKey)
                        .textFieldStyle(.roundedBorder)
                } else {
                    SecureField("API Key", text: $openRouterApiKey)
                        .textFieldStyle(.roundedBorder)
                }
                Button {
                    isEditingApiKey.toggle()
                } label: {
                    Image(systemName: isEditingApiKey ? "eye.slash" : "eye")
                }
                .buttonStyle(.plain) // Keep button style minimal
            }
        } label: {
            Text("OpenRouter API Key")
            // Add help text below the label if desired
            // Text("Stored locally for OpenRouter requests.").font(.caption).foregroundColor(.gray)
        }
        .padding(.bottom, 5) // Add some spacing below
    }

    // Extracted Model Table View
    private var modelTableSection: some View {
        // Use Table for a structured, column-based view
        Table(modelManager.models, selection: $selection) {
            TableColumn("Name", value: \.name)
            TableColumn("ID", value: \.id)
            TableColumn("Description") { model in
                Text(model.description)
                    .lineLimit(1) // Prevent long descriptions from expanding row height excessively
                    .truncationMode(.tail)
            }
            TableColumn("Badge") { model in
                 // Display badge similar to before, but aligned in its column
                 if let badge = model.badge, !badge.isEmpty {
                     Text(badge.uppercased())
                         .font(.caption) // Slightly larger font for table
                         .padding(.horizontal, 5)
                         .padding(.vertical, 2)
                         .background(Color.secondary.opacity(0.15)) // Subtle background
                         .cornerRadius(5)
                         .foregroundColor(.secondary) // Use secondary color for less emphasis
                 } else {
                     Text("") // Ensure column alignment
                 }
            }
            // Add more columns if needed
        }
        // Set a reasonable height for the table
        .frame(minHeight: 150)
        // Note: .onDelete doesn't work directly with Table. Removal is handled by the '-' button.
    }

    // Function to remove models selected in the Table
    private func removeSelectedModels() {
        // Get the actual ModelOption objects corresponding to the selected IDs
        let modelsToRemove = modelManager.models.filter { selection.contains($0.id) }
        for model in modelsToRemove {
            modelManager.removeModel(model) // Use the removeModel(_:) method
        }
        selection.removeAll() // Clear selection after removal
    }
}

// New View for Adding Models (can be in the same file or separate)
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
        // Use Form for standard macOS sheet layout
        Form {
            Section { // Group fields without a header
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

            // Display error message if present
            if showError {
                 Section { // Put error in its own section for visibility
                     Text(errorMessage)
                         .foregroundColor(.red)
                         .font(.callout) // Slightly larger than caption
                 }
            }
        }
        .padding()
        .frame(minWidth: 350, idealWidth: 400) // Adjust sheet size
        .navigationTitle("Add New Model") // Use navigationTitle for sheet title
        .toolbar { // Add standard Cancel/Add buttons to toolbar
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    addModel()
                }
                .disabled(modelId.isEmpty || modelName.isEmpty) // Validation
            }
        }
    }


    private func addModel() {
        guard !modelId.isEmpty, !modelName.isEmpty else {
            errorMessage = "Model ID and Name cannot be empty."
            showError = true
            return
        }
        // Basic check for existing ID (ModelManager also checks, but good to have here too)
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


// Preview needs the EnvironmentObject
struct ConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        ConfigurationView()
            .environmentObject(ModelManager()) // Provide a dummy manager for preview
    }
}
