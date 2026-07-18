import AppKit
import SwiftUI

struct ConversationHistoryView: View {
    let model: ConversationHistoryModel
    @State private var selection: UUID?

    private var selectedConversation: ConversationProjection? {
        model.conversations.first { $0.id == selection }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let errorMessage = model.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.red.opacity(0.08))
            }

            NavigationSplitView {
                conversationList
                    .navigationTitle("Conversations")
                    .navigationSplitViewColumnWidth(min: 220, ideal: 260)
            } detail: {
                conversationDetail
            }
        }
        .frame(minWidth: 680, minHeight: 480)
        .task {
            await model.reload()
            selectFirstConversationIfNeeded()
        }
        .onChange(of: model.conversations.map(\.id)) {
            selectFirstConversationIfNeeded()
        }
        .toolbar {
            ToolbarItemGroup {
                Button("Reload", systemImage: "arrow.clockwise") {
                    Task { await model.reload() }
                }
                Button("Reveal JSONL", systemImage: "folder") {
                    revealSelectedLog()
                }
                .disabled(selectedConversation == nil)
            }
        }
    }

    private var conversationList: some View {
        List(model.conversations, selection: $selection) { conversation in
            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.title)
                    .font(.headline)
                    .lineLimit(2)
                HStack {
                    if let startedAt = conversation.startedAt {
                        Text(startedAt, format: .dateTime.day().month().hour().minute())
                    }
                    Spacer()
                    Text("\(conversation.messages.count)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .tag(conversation.id)
        }
        .overlay {
            if model.conversations.isEmpty, !model.isLoading {
                ContentUnavailableView(
                    "No conversations yet",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Completed voice turns will appear here.")
                )
            }
        }
    }

    @ViewBuilder
    private var conversationDetail: some View {
        if let conversation = selectedConversation {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if conversation.skippedLineCount > 0 {
                        Label(
                            "Skipped \(conversation.skippedLineCount) unreadable JSONL record(s).",
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.callout)
                        .foregroundStyle(.orange)
                    }
                    ForEach(conversation.messages) { message in
                        ConversationMessageView(message: message)
                    }
                }
                .padding(24)
                .frame(maxWidth: 760, alignment: .leading)
            }
            .navigationTitle(conversation.title)
        } else {
            ContentUnavailableView(
                "Select a conversation",
                systemImage: "text.bubble",
                description: Text("Choose a saved conversation from the sidebar.")
            )
        }
    }

    private func selectFirstConversationIfNeeded() {
        if selection == nil || !model.conversations.contains(where: { $0.id == selection }) {
            selection = model.conversations.first?.id
        }
    }

    private func revealSelectedLog() {
        let url = selectedConversation?.fileURL ?? model.historyDirectoryURL
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

private struct ConversationMessageView: View {
    let message: ConversationMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(
                    message.role == .user ? "You" : "ScreenTutor",
                    systemImage: message.role == .user ? "person.fill" : "sparkles"
                )
                .font(.caption.weight(.semibold))
                Spacer()
                Text(message.timestamp, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(message.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            message.role == .user ? Color.accentColor.opacity(0.10) : Color.secondary.opacity(0.09),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}
