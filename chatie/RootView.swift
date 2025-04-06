import SwiftUI

struct RootView: View {
    @StateObject private var viewModel = ChatSessionsViewModel()
    // Access the ModelManager from the environment
    @EnvironmentObject var modelManager: ModelManager
    
    // Remove hardcoded models
    // let availableModels: [ModelOption] = [...]
    // let defaultModel = ...
    
    var body: some View {
        // Ensure there's a default model available from the manager
        let currentDefaultModel = modelManager.getDefaultModel() ?? ModelOption(id: "error/no-models", name: "Error", description: "No models configured")

        NavigationSplitView {
            SidebarView()
                .environmentObject(viewModel)
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 300)
        } detail: {
            NavigationStack {
                if let selectedChat = viewModel.selectedChat() {
                    ChatView(chatSession: selectedChat)
                        .id(selectedChat.id)
                        .toolbar {
                            ToolbarItem(placement: .navigation) {
                                CustomModelPickerButton(
                                    selectedModel: Binding<ModelOption>(
                                        // Use the manager's default if chat session has no model
                                        get: { selectedChat.model ?? currentDefaultModel },
                                        set: { newModel in
                                            selectedChat.model = newModel
                                        }
                                    ),
                                    // Use models from the manager
                                    options: modelManager.models
                                )
                            }
                        }
                } else {
                    ContentArea()
                }
            }
            .navigationTitle("")
        }
    }
}

struct ContentArea: View {
    var body: some View {
        Text("Welcome! Select or create a Chat in the sidebar.")
            .font(.title)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray.opacity(0.1))
    }
}

struct DetailContainer<Content: View>: View {
    @Binding var selectedModel: String
    let content: Content

    init(selectedModel: Binding<String>, @ViewBuilder content: () -> Content) {
        self._selectedModel = selectedModel
        self.content = content()
    }

    var body: some View {
        content
    }
}

// Make ModelOption Codable for storage and Hashable for lists/ForEach
struct ModelOption: Identifiable, Codable, Hashable, Equatable {
    var id: String // Keep as var if editing ID is needed, else let
    var name: String
    var description: String
    var badge: String? // Optional badge

    // Conformance for Identifiable (already implicitly via id)
    // Conformance for Equatable
    static func == (lhs: ModelOption, rhs: ModelOption) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.description == rhs.description &&
        lhs.badge == rhs.badge
    }
    
    // Conformance for Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(description)
        hasher.combine(badge)
    }
    
    // Example initializer (can be customized)
    init(id: String, name: String, description: String, badge: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.badge = badge
    }
}


struct CustomModelPickerButton: View {
    @Binding var selectedModel: ModelOption
    @State private var isOpen = false
    let options: [ModelOption]

    var body: some View {
        Button {
            isOpen.toggle()
        } label: {
            HStack(spacing: 6) {
                Text(selectedModel.name)
                    .font(.system(size: 14, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.05))
            )
        }
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            CustomModelPickerPopover(
                selectedModel: $selectedModel,
                options: options,
                isOpen: $isOpen,
            )
            .frame(width: 300)
            .frame(maxHeight: 300)
        }
        .buttonStyle(.plain)
    }
}

struct CustomModelPickerPopover: View {
    @Binding var selectedModel: ModelOption
    let options: [ModelOption]
    @Binding var isOpen: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Model")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding([.top, .horizontal])

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(options) { option in
                        // Removed check for option.isDisabled
                        Button {
                            selectedModel = option
                            isOpen = false
                        } label: {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(option.name)
                                            .fontWeight(.semibold)
                                            // Removed conditional foregroundColor based on isDisabled
                                            .foregroundColor(.primary) 

                                        if let badge = option.badge {
                                            Text(badge.uppercased())
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.gray.opacity(0.2))
                                                .cornerRadius(4)
                                                .foregroundColor(.gray)
                                        }
                                    }

                                    Text(option.description)
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                // Removed check for option.isDisabled
                                if selectedModel == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(option == selectedModel ? Color.accentColor.opacity(0.1) : Color.clear)
                            )
                        }
                        // Removed .disabled modifier
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}
