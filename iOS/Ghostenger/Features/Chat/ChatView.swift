import SwiftUI

struct ChatView: View {
    let conversation: ConversationSummary

    @StateObject private var viewModel: ChatViewModel
    @EnvironmentObject var appState: AppState
    @State private var messageText = ""
    @FocusState private var isComposerFocused: Bool

    init(conversation: ConversationSummary) {
        self.conversation = conversation
        _viewModel = StateObject(wrappedValue: ChatViewModel(conversation: conversation))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Message list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message, isMine: message.senderID == appState.session?.userID)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let last = viewModel.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            // Typing indicator
            if viewModel.isTyping {
                HStack {
                    Text("typing...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }

            Divider()

            // Composer
            HStack(spacing: 12) {
                TextField("Message", text: $messageText, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.roundedBorder)
                    .focused($isComposerFocused)
                    .onChange(of: messageText) { _, _ in
                        viewModel.sendTypingIndicator(session: appState.session)
                    }

                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(messageText.isEmpty ? .secondary : .teal)
                }
                .disabled(messageText.isEmpty)
            }
            .padding()
        }
        .navigationTitle(conversation.name ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(session: appState.session) }
    }

    private func send() async {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messageText = ""
        await viewModel.sendMessage(text: text, session: appState.session)
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: DecryptedMessage
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 60) }

            Text(message.plaintext)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isMine ? Color.teal : Color(.systemGray5))
                .foregroundStyle(isMine ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            if !isMine { Spacer(minLength: 60) }
        }
    }
}
