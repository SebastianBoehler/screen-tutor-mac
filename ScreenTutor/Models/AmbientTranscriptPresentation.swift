import Foundation

struct AmbientTranscriptPresentation: Equatable, Sendable {
    let isEnabled: Bool
    let phase: SessionPhase
    let userText: String
    let assistantText: String
    let hasToolActivity: Bool

    init(
        isEnabled: Bool,
        phase: SessionPhase,
        userText: String,
        assistantText: String,
        hasToolActivity: Bool = false
    ) {
        self.isEnabled = isEnabled
        self.phase = phase
        self.userText = userText
        self.assistantText = assistantText
        self.hasToolActivity = hasToolActivity
    }

    var isExpanded: Bool {
        isEnabled
            && phase.hasConversation
            && (!userText.isEmpty || !assistantText.isEmpty)
    }

    var panelHeight: CGFloat {
        (isExpanded ? 248 : 120) + (hasToolActivity ? 42 : 0)
    }
}
