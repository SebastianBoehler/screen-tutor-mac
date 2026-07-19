import Foundation
import Observation

@MainActor
@Observable
final class ConversationHistoryModel {
    private(set) var conversations: [ConversationProjection] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    @ObservationIgnored private var logsByID: [UUID: ConversationLog] = [:]
    @ObservationIgnored private var pendingRecords: [ConversationRecord] = []
    @ObservationIgnored private var writeTask: Task<Void, Never>?

    let store: ConversationLogStore

    init(
        store: ConversationLogStore = ConversationLogStore(
            rootDirectoryURL: ConversationLogStore.applicationSupportDirectory()
        )
    ) {
        self.store = store
    }

    var historyDirectoryURL: URL {
        store.rootDirectoryURL
    }

    var conversationFileURLs: [URL] {
        conversations.map(\.fileURL)
    }

    func append(_ record: ConversationRecord) async throws {
        try await store.append(record)
        apply(record)
    }

    func record(_ record: ConversationRecord) {
        pendingRecords.append(record)
        startWriterIfNeeded()
    }

    func flush() async {
        while let writeTask {
            await writeTask.value
        }
    }

    func reload() async {
        isLoading = true
        defer { isLoading = false }
        await flush()
        do {
            let logs = try await store.loadAllConversations()
            logsByID = Dictionary(uniqueKeysWithValues: logs.map { ($0.conversationID, $0) })
            conversations = logs.map(ConversationProjection.init).sorted(by: Self.newestFirst)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func conversation(id: UUID) async -> ConversationProjection? {
        await flush()
        do {
            let projection = ConversationProjection(
                log: try await store.loadConversation(id)
            )
            errorMessage = nil
            return projection
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func deleteConversation(id: UUID) async {
        await flush()
        do {
            try await store.deleteConversation(id)
            logsByID[id] = nil
            conversations.removeAll { $0.id == id }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteAllConversations() async {
        await flush()
        do {
            try await store.deleteAllConversations()
            logsByID.removeAll()
            conversations.removeAll()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func newestFirst(
        _ lhs: ConversationProjection,
        _ rhs: ConversationProjection
    ) -> Bool {
        switch (lhs.startedAt, rhs.startedAt) {
        case let (left?, right?) where left != right:
            return left > right
        default:
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private func startWriterIfNeeded() {
        guard writeTask == nil else { return }
        writeTask = Task { [weak self] in
            await self?.drainWrites()
        }
    }

    private func drainWrites() async {
        while !pendingRecords.isEmpty {
            let record = pendingRecords.removeFirst()
            do {
                try await store.append(record)
                apply(record)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        writeTask = nil
    }

    private func apply(_ record: ConversationRecord) {
        let existing = logsByID[record.conversationID]
        guard existing?.records.contains(where: { $0.id == record.id }) != true else { return }
        let log = ConversationLog(
            conversationID: record.conversationID,
            records: (existing?.records ?? []) + [record],
            skippedLineCount: existing?.skippedLineCount ?? 0,
            fileURL: existing?.fileURL ?? store.fileURL(for: record.conversationID)
        )
        logsByID[record.conversationID] = log
        let projection = ConversationProjection(log: log)
        conversations.removeAll { $0.id == projection.id }
        conversations.append(projection)
        conversations.sort(by: Self.newestFirst)
    }
}
