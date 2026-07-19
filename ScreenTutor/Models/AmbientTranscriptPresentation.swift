import Foundation

struct AmbientTranscriptPresentation: Equatable, Sendable {
    let isEnabled: Bool
    let phase: SessionPhase
    let userText: String
    let assistantText: String

    var isExpanded: Bool {
        isEnabled
            && phase.hasConversation
            && (!userText.isEmpty || !assistantText.isEmpty)
    }

    var panelHeight: CGFloat {
        isExpanded ? 248 : 120
    }
}
