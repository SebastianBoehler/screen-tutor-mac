import AppKit
import SwiftUI

struct ConversationStorageSettingsView: View {
    let model: ConversationHistoryModel

    var body: some View {
        Section("Conversation storage") {
            LabeledContent("Folder") {
                Text(model.historyDirectoryURL.path(percentEncoded: false))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            HStack {
                Button(
                    "Open Folder",
                    systemImage: "folder",
                    action: openHistoryDirectory
                )
                .disabled(model.conversationFileURLs.isEmpty)

                Button(
                    "Reveal All JSONL Files",
                    systemImage: "doc.on.doc",
                    action: revealAllConversationFiles
                )
                .disabled(model.conversationFileURLs.isEmpty)

                Menu("Reveal One JSONL", systemImage: "doc.text.magnifyingglass") {
                    ForEach(model.conversations) { conversation in
                        Button(conversationMenuTitle(conversation)) {
                            revealConversation(conversation)
                        }
                        .help(conversation.fileURL.path(percentEncoded: false))
                    }
                }
                .disabled(model.conversations.isEmpty)
            }

            if let errorMessage = model.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            } else {
                Text(storageSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task { await model.reload() }
    }

    private var storageSummary: String {
        let count = model.conversationFileURLs.count
        return count == 1
            ? "1 conversation JSONL file is stored locally."
            : "\(count) conversation JSONL files are stored locally."
    }

    private func openHistoryDirectory() {
        NSWorkspace.shared.open(model.historyDirectoryURL)
    }

    private func revealAllConversationFiles() {
        NSWorkspace.shared.activateFileViewerSelecting(model.conversationFileURLs)
    }

    private func revealConversation(_ conversation: ConversationProjection) {
        NSWorkspace.shared.activateFileViewerSelecting([conversation.fileURL])
    }

    private func conversationMenuTitle(_ conversation: ConversationProjection) -> String {
        guard let startedAt = conversation.startedAt else { return conversation.title }
        return "\(conversation.title) — \(startedAt.formatted(date: .abbreviated, time: .shortened))"
    }
}
