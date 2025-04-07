import SwiftUI

struct RootView: View {

    @EnvironmentObject var chatSessionsViewModel: ChatSessionsViewModel
    @EnvironmentObject var modelManager: ModelManager

    var body: some View {

        let currentDefaultModel = modelManager.getDefaultModel() ?? ModelOption(id: "error/no-models", name: "Error", description: "No models configured")

        NavigationSplitView {

            SidebarView()

                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 300)
        } detail: {
            NavigationStack {

                if let selectedChat = chatSessionsViewModel.selectedChat() {

                    ChatView(chatSession: selectedChat)

                        .id(selectedChat.id)
                        .toolbar {
                            ToolbarItem(placement: .navigation) {

                                CustomModelPickerButton(
                                    selectedModel: Binding<ModelOption>(

                                        get: { selectedChat.model ?? currentDefaultModel },
                                        set: { newModel in
                                            if selectedChat.model != newModel {
                                                selectedChat.model = newModel

                                                Task {
                                                    await chatSessionsViewModel.chatDidChange(selectedChat)
                                                }
                                            }
                                        }
                                    ),

                                    options: modelManager.models
                                )
                            }
                        }
                } else {

                    ContentArea(chatSessionsViewModel: chatSessionsViewModel)
                }
            }
            .navigationTitle("")
        }

        .onChange(of: modelManager.models) { newModels in

            DispatchQueue.main.async {
                chatSessionsViewModel.setAvailableModels(newModels)
            }
        }
    }
}

struct ContentArea: View {

    @ObservedObject var chatSessionsViewModel: ChatSessionsViewModel

    var body: some View {
        VStack {
            Text("No Chat Selected")
                .font(.title)
                .foregroundColor(.secondary)
            Button("Create New Chat") {

                Task {
                    await chatSessionsViewModel.addNewChat()
                }
            }
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.05))
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
                            selectedModel = option
                            isOpen = false
                        } label: {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(option.name)
                                            .fontWeight(.semibold)

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

                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}
