import Foundation

actor ConversationLogStore {
    nonisolated let rootDirectoryURL: URL

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        rootDirectoryURL: URL,
        fileManager: FileManager = .default
    ) {
        self.rootDirectoryURL = rootDirectoryURL
        self.fileManager = fileManager
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    nonisolated func fileURL(for conversationID: UUID) -> URL {
        rootDirectoryURL.appendingPathComponent(
            "\(conversationID.uuidString.lowercased()).jsonl",
            isDirectory: false
        )
    }

    func append(_ record: ConversationRecord) throws {
        try prepareRootDirectory()
        let destination = fileURL(for: record.conversationID)
        try prepareFile(at: destination)

        var bytes = Data()
        let handle = try FileHandle(forUpdating: destination)
        defer { try? handle.close() }

        let endOffset = try handle.seekToEnd()
        if endOffset > 0 {
            try handle.seek(toOffset: endOffset - 1)
            let finalByte = try handle.read(upToCount: 1)?.first
            if finalByte != 0x0A {
                bytes.append(0x0A)
            }
            try handle.seekToEnd()
        }

        bytes.append(try encoder.encode(record))
        bytes.append(0x0A)
        try handle.write(contentsOf: bytes)
        try handle.synchronize()
    }

    func loadConversation(_ conversationID: UUID) throws -> ConversationLog {
        let source = fileURL(for: conversationID)
        guard fileManager.fileExists(atPath: source.path) else {
            return ConversationLog(
                conversationID: conversationID,
                records: [],
                skippedLineCount: 0,
                fileURL: source
            )
        }

        let bytes = try Data(contentsOf: source)
        var records: [ConversationRecord] = []
        var skippedLineCount = 0
        for line in bytes.split(separator: 0x0A, omittingEmptySubsequences: true) {
            do {
                let record = try decoder.decode(ConversationRecord.self, from: Data(line))
                guard record.conversationID == conversationID else {
                    skippedLineCount += 1
                    continue
                }
                records.append(record)
            } catch {
                skippedLineCount += 1
            }
        }
        return ConversationLog(
            conversationID: conversationID,
            records: records,
            skippedLineCount: skippedLineCount,
            fileURL: source
        )
    }

    func loadAllConversations() throws -> [ConversationLog] {
        guard fileManager.fileExists(atPath: rootDirectoryURL.path) else { return [] }
        let files = try fileManager.contentsOfDirectory(
            at: rootDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return try files.compactMap { url in
            guard
                url.pathExtension == "jsonl",
                let conversationID = UUID(uuidString: url.deletingPathExtension().lastPathComponent)
            else { return nil }
            return try loadConversation(conversationID)
        }
    }

    static func applicationSupportDirectory(
        fileManager: FileManager = .default
    ) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("ScreenTutor", isDirectory: true)
            .appendingPathComponent("Conversations", isDirectory: true)
    }

    private func prepareRootDirectory() throws {
        try fileManager.createDirectory(
            at: rootDirectoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: rootDirectoryURL.path
        )
    }

    private func prepareFile(at url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            guard fileManager.createFile(
                atPath: url.path,
                contents: nil,
                attributes: [.posixPermissions: 0o600]
            ) else {
                throw CocoaError(.fileWriteUnknown)
            }
        }
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }
}
