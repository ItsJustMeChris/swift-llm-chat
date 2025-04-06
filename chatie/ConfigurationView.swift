import SwiftUI

struct ConfigurationView: View {
    // API Key Section
    @AppStorage("openRouterApiKey") private var openRouterApiKey: String = ""
    @State private var isEditingApiKey: Bool = false

    // Model Management Section
    @EnvironmentObject var modelManager: ModelManager
    @State private var showingAddModelSheet = false
    @State private var modelToEdit: ModelOption? = nil // Keep for potential future use
    @State private var selection = Set<ModelOption.ID>()

    var body: some View {
        // Use Form directly as the main container for standard settings padding/spacing
        Form {
            Section("API Configuration") {
                apiKeySection
            }

            Section("Model Management") {
                // Embed the Table and buttons within the section
                modelTableSection
                modelActionButtons // Add buttons below the table
            }
        }
        // Apply padding to the Form itself for overall window spacing
        .padding()
        .frame(minWidth: 480, minHeight: 350) // Slightly wider for table columns
        .sheet(isPresented: $showingAddModelSheet) {
            // Present AddModelView centered, with environment object
            AddModelView()
                .environmentObject(modelManager)
        }
        // Removed commented out edit sheet code for cleanliness
    }

    // MARK: - Subviews

    // API Key View - LabeledContent provides good alignment
    private var apiKeySection: some View {
        // LabeledContent aligns the label and the control group horizontally
        LabeledContent {
            HStack {
                // Use placeholder text consistent with the image
                if isEditingApiKey {
                    TextField("API Key", text: $openRouterApiKey)
                } else {
                    SecureField("API Key", text: $openRouterApiKey)
                }
                // Visibility toggle button
                Button {
                    isEditingApiKey.toggle()
                } label: {
                    Image(systemName: isEditingApiKey ? "eye.slash" : "eye")
                }
                .buttonStyle(.plain) // Use plain style for inline buttons
            }
            .textFieldStyle(.roundedBorder) // Apply style to the HStack content
        } label: {
            // Standard text label
            Text("OpenRouter API Key")
        }
        // Form provides default spacing, explicit padding might not be needed
    }

    // Model Table View
    private var modelTableSection: some View {
        Table(modelManager.models, selection: $selection) {
            TableColumn("Name", value: \.name).width(min: 100) // Suggest min width
            TableColumn("ID", value: \.id).width(min: 150)
            TableColumn("Description") { model in
                Text(model.description.isEmpty ? "-" : model.description) // Show placeholder if empty
                    .lineLimit(1)
                    .truncationMode(.tail)
            }.width(min: 100)
            TableColumn("Badge") { model in
                 if let badge = model.badge, !badge.isEmpty {
                     Text(badge.uppercased()) // Keep badge styling
                         .font(.caption)
                         .padding(.horizontal, 5)
                         .padding(.vertical, 2)
                         .background(Color.secondary.opacity(0.15))
                         .cornerRadius(5)
                         .foregroundColor(.secondary)
                 } else {
                     Text("-") // Show placeholder for alignment
                 }
            }.width(ideal: 60) // Suggest ideal width for badge
        }
        .frame(minHeight: 150, idealHeight: 200) // Provide min/ideal height
    }

    // Buttons for Model Management Table
    private var modelActionButtons: some View {
        HStack {
            // Use standard bordered button style
            Button {
                showingAddModelSheet = true
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.bordered) // Apply bordered style
            .help("Add a new model")

            Button {
                removeSelectedModels()
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.bordered) // Apply bordered style
            .disabled(selection.isEmpty)
            .help("Remove selected model(s)")
            
            Spacer() // Keep buttons pushed to the left
        }
        // Add padding if needed, though Form section might handle it
        // .padding(.top, 5)
    }

    // MARK: - Actions

    private func removeSelectedModels() {
        let modelsToRemove = modelManager.models.filter { selection.contains($0.id) }
        modelManager.models.removeAll { modelsToRemove.contains($0) } // More efficient removal
        selection.removeAll()
    }
}

// MARK: - Add Model View (Sheet)

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
