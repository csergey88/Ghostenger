import SwiftUI

struct ChatListView: View {
    @State private var viewModel = ChatListViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.conversations.isEmpty {
                    ContentUnavailableView(
                        "No conversations",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Start a conversation from the Contacts tab")
                    )
                } else {
                    List(viewModel.conversations) { conversation in
                        NavigationLink(value: conversation) {
                            ConversationRow(conversation: conversation)
                        }
                    }
                }
            }
            .navigationTitle("Chats")
            .navigationDestination(for: ConversationItem.self) { conversation in
                ChatView(conversationId: conversation.id)
            }
            .task {
                await viewModel.load()
            }
        }
    }
}

struct ConversationRow: View {
    let conversation: ConversationItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(conversation.displayName)
                .font(.headline)
            Text(conversation.lastMessage ?? "No messages yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}
