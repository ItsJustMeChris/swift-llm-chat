import SwiftUI

struct RootView: View {
    @StateObject private var viewModel = ChatSessionsViewModel()
    
    let availableModels: [ModelOption] = [
        .init(id: "openrouter/quasar-alpha", name: "Quasar Alpha", description: "Probably gpt-os", badge: "wOw", isDisabled: false),
        .init(id: "meta-llama/llama-4-maverick:free", name: "Llama 4 Maverick", description: "LLAMA 4 FREE", badge: nil, isDisabled: false),
    ]
    
    let defaultModel = ModelOption(id: "openrouter/quasar-alpha", name: "Quasar Alpha", description: "Probably gpt-os", badge: "wOw", isDisabled: false)
    
    var body: some View {
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
                                        get: { selectedChat.model ?? defaultModel },
                                        set: { newModel in
                                            selectedChat.model = newModel
                                        }
                                    ),
                                    options: availableModels
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

struct ModelOption: Identifiable, Equatable {
    var id: String
    let name: String
    let description: String
    let badge: String?
    let isDisabled: Bool

    static func == (lhs: ModelOption, rhs: ModelOption) -> Bool {
        lhs.id == rhs.id
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
                        Button {
                            if !option.isDisabled {
                                selectedModel = option
                                isOpen = false
                            }
                        } label: {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(option.name)
                                            .fontWeight(.semibold)
                                            .foregroundColor(option.isDisabled ? .gray : .primary)

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

                                if selectedModel == option && !option.isDisabled {
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
                        .disabled(option.isDisabled)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}
