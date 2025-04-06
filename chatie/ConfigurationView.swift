import SwiftUI

struct ConfigurationView: View {
    @AppStorage("openRouterApiKey") private var openRouterApiKey: String = ""
    @State private var isEditingApiKey: Bool = false

    @EnvironmentObject var modelManager: ModelManager
    @State private var showingAddModelSheet = false
    @State private var selection = Set<ModelOption.ID>()
    @State private var draggingItem: ModelOption? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            GroupBox(label: Text("API Configuration").font(.headline)) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("OpenRouter API Key")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack {
                        if isEditingApiKey {
                            TextField("Enter your API Key", text: $openRouterApiKey)
                        } else {
                            SecureField("Enter your API Key", text: $openRouterApiKey)
                        }
                        Button {
                            isEditingApiKey.toggle()
                        } label: {
                            Image(systemName: isEditingApiKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                    }
                    .textFieldStyle(.roundedBorder)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
            }

            GroupBox(label: Text("Model Management").font(.headline)) {
                VStack(alignment: .leading, spacing: 12) {

                    List(selection: $selection) {
                        ForEach(modelManager.models) { model in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(model.name)
                                        .font(.body)
                                    Text(model.id)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if let badge = model.badge, !badge.isEmpty {
                                    Text(badge.uppercased())
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.15))
                                        .cornerRadius(5)
                                }
                            }
                            .padding(.vertical, 4)
                            .onDrag {
                                self.draggingItem = model
                                return NSItemProvider(object: NSString(string: model.id))
                            }
                            .onDrop(
                                of: [.text],
                                delegate: ModelDropDelegate(
                                    item: model,
                                    models: $modelManager.models,
                                    draggingItem: $draggingItem
                                )
                            )
                        }
                    }
                    .listStyle(.plain)
                    .frame(minHeight: 150, idealHeight: 200)

                    HStack {
                        Button {
                            showingAddModelSheet = true
                        } label: {
                            Label("Add Model", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            removeSelectedModels()
                        } label: {
                            Label("Remove Model(s)", systemImage: "minus")
                        }
                        .buttonStyle(.bordered)
                        .disabled(selection.isEmpty)

                        Spacer()
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
            }

            Spacer()
        }
        .padding()
        .frame(minWidth: 480, minHeight: 350)
        .sheet(isPresented: $showingAddModelSheet) {
            AddModelView()
                .environmentObject(modelManager)
        }
    }

    private func removeSelectedModels() {
        let modelsToRemove = modelManager.models.filter { selection.contains($0.id) }
        modelManager.models.removeAll { modelsToRemove.contains($0) }
        selection.removeAll()
    }
}

struct ModelDropDelegate: DropDelegate {
    let item: ModelOption
    @Binding var models: [ModelOption]
    @Binding var draggingItem: ModelOption?

    func dropEntered(info: DropInfo) {
        guard
            let draggingItem = draggingItem,
            draggingItem != item,
            let fromIndex = models.firstIndex(of: draggingItem),
            let toIndex = models.firstIndex(of: item)
        else {
            return
        }
        if models[toIndex] != draggingItem {
            withAnimation {
                models.move(fromOffsets: IndexSet(integer: fromIndex),
                            toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
            }
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        return true
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
        VStack(alignment: .leading, spacing: 0) {
            Text("Add New Model")
                .font(.title2)
                .padding()
            Divider()

            Form {
                Section {
                    TextField("Model ID (e.g., provider/model)", text: $modelId)
                        .textFieldStyle(.roundedBorder)
                    TextField("Display Name", text: $modelName)
                        .textFieldStyle(.roundedBorder)
                    TextField("Description (optional)", text: $modelDescription)
                        .textFieldStyle(.roundedBorder)
                    TextField("Badge (optional)", text: $modelBadge)
                        .textFieldStyle(.roundedBorder)
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

            Divider()
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Add") {
                    addModel()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(modelId.isEmpty || modelName.isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 350, idealWidth: 400)
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
            badge: modelBadge.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : modelBadge.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        modelManager.addModel(newModel)
        dismiss()
    }
}
