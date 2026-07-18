import CoreGraphics
import Foundation

struct AvailableWindow: Encodable, Equatable, Sendable {
    let id: String
    let applicationName: String
    let title: String?

    enum CodingKeys: String, CodingKey {
        case title
        case id = "window_id"
        case applicationName = "application"
    }
}

struct CaptureWindowArguments: Decodable, Sendable {
    let windowID: String

    enum CodingKeys: String, CodingKey {
        case windowID = "window_id"
    }
}

struct CaptureWindowSelection: Equatable, Sendable {
    let windowID: CGWindowID
    let processID: pid_t
}

struct CaptureWindowCandidate: Sendable {
    let windowID: CGWindowID
    let processID: pid_t
    let applicationName: String
    let title: String?
    let frame: CGRect
    let layer: Int
    let frontToBackRank: Int
}

struct CaptureWindowCatalog: Sendable {
    let windows: [AvailableWindow]
    private let selectionsByID: [String: CaptureWindowSelection]

    init(
        candidates: [CaptureWindowCandidate],
        excludingProcessID: pid_t,
        tokenProvider: () -> String
    ) {
        let eligible = candidates
            .filter {
                $0.processID != excludingProcessID
                    && $0.layer == 0
                    && $0.frame.width >= 240
                    && $0.frame.height >= 160
                    && !$0.applicationName.isEmpty
            }
            .sorted { $0.frontToBackRank < $1.frontToBackRank }

        var windows: [AvailableWindow] = []
        var selections: [String: CaptureWindowSelection] = [:]
        for candidate in eligible {
            let token = tokenProvider()
            windows.append(
                AvailableWindow(
                    id: token,
                    applicationName: candidate.applicationName,
                    title: candidate.title?.isEmpty == false ? candidate.title : nil
                )
            )
            selections[token] = CaptureWindowSelection(
                windowID: candidate.windowID,
                processID: candidate.processID
            )
        }
        self.windows = windows
        selectionsByID = selections
    }

    func selection(for id: String) -> CaptureWindowSelection? {
        selectionsByID[id]
    }
}
