import Foundation

struct PCM16Accumulator: Sendable {
    private var trailingByte: UInt8?

    mutating func append(_ data: Data) -> Data {
        guard !data.isEmpty else { return Data() }
        var combined = Data()
        if let trailingByte {
            combined.append(trailingByte)
            self.trailingByte = nil
        }
        combined.append(data)

        if combined.count.isMultiple(of: 2) { return combined }
        trailingByte = combined.removeLast()
        return combined
    }

    mutating func finish() throws {
        guard trailingByte == nil else {
            trailingByte = nil
            throw AudioIOError.malformedOutputPCM
        }
    }

    mutating func reset() {
        trailingByte = nil
    }
}
