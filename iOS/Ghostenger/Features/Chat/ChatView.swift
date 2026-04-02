import SwiftUI

struct ChatView: View {
    let conversationId: String
    @State private var viewModel: ChatViewModel

    init(conversationId: String) {
        self.conversationId = conversationId
        _viewModel = State(initialValue: ChatViewModel(conversationId: conversationId))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) {
                    if let last = viewModel.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider()

            HStack(spacing: 12) {
                TextField("Message", text: $viewModel.draftText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)

                Button {
                    Task { await viewModel.send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(viewModel.draftText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
    }
}

struct MessageBubble: View {
    let message: MessageItem

    var body: some View {
        HStack {
            if message.isOutgoing { Spacer() }
            Text("🔒 Encrypted message")
                .padding(10)
                .background(message.isOutgoing ? Color.accentColor : Color(.systemGray5))
                .foregroundStyle(message.isOutgoing ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            if !message.isOutgoing { Spacer() }
        }
    }
}
