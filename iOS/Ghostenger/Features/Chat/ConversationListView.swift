import SwiftUI

struct ConversationListView: View {
    @StateObject private var viewModel = ConversationListViewModel()
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.conversations.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "No Chats",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Start a conversation from Contacts")
                    )
                } else {
                    List(viewModel.conversations) { conv in
                        NavigationLink(value: conv) {
                            ConversationRow(conversation: conv)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Chats")
            .navigationDestination(for: ConversationSummary.self) { conv in
                ChatView(conversation: conv)
            }
            .task { await viewModel.load(session: appState.session) }
            .refreshable { await viewModel.load(session: appState.session) }
        }
    }
}

struct ConversationRow: View {
    let conversation: ConversationSummary

    var body: some View {
        HStack {
            Image(systemName: conversation.type == "group" ? "person.3.fill" : "person.fill")
                .frame(width: 44, height: 44)
                .background(Color.teal.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(conversation.name ?? "Direct Message")
                    .font(.headline)
                Text("Tap to open")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
