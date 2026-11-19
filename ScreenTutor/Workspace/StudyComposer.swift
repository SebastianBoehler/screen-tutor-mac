import SwiftUI

struct StudyComposer: View {
    let model: AppModel
    @State private var draft = ""
    @State private var isSending = false

    var body: some View {
        VStack(alignment: .leading, spacing: StudyDesign.controlGap) {
            if !model.assistantTranscript.isEmpty {
                Text(model.assistantTranscript).font(.callout).foregroundStyle(.secondary)
                    .lineLimit(3).textSelection(.enabled)
            }
            if !model.liveToolActivities.isEmpty { LiveToolActivityStrip(activities: model.liveToolActivities) }
            VStack(alignment: .leading, spacing: StudyDesign.controlGap) {
                TextField("Ask a question, share your attempt, or explain your thinking…", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain).lineLimit(2...6).onSubmit(send)
                    .accessibilityLabel("Message to your tutor")
                HStack(spacing: StudyDesign.controlGap) {
                    Menu {
                        ForEach(StudyMode.allCases, id: \.self) { mode in
                            Button(mode.title) {
                                do { try model.workspace.setMode(mode) }
                                catch { model.workspace.errorMessage = error.localizedDescription }
                            }
                        }
                    } label: {
                        Label(model.workspace.mode.title, systemImage: model.workspace.mode == .exam ? "checklist" : "book")
                    }.menuStyle(.borderlessButton).fixedSize()
                    Spacer()
                    if model.workspace.mode == .exam, model.phase.hasConversation {
                        Button("Review attempt") {
                            do { try model.workspace.setMode(.practice) }
                            catch { model.workspace.errorMessage = error.localizedDescription }
                            Task { await model.sendStudyMessage("Review my finished mock exam attempt against the course. Check actual answers and keep assisted work separate.") }
                        }
                    }
                    Button(action: model.toggleSession) {
                        Label(model.phase == .idle ? "Start voice" : model.microphoneControlState.compactLabel,
                              systemImage: model.microphoneControlState.symbolName)
                    }.disabled(!model.microphoneControlState.isEnabled)
                    if model.phase.hasConversation {
                        Button("End voice", systemImage: "stop") { Task { await model.stopSession() } }
                            .labelStyle(.iconOnly).help("End voice session")
                    }
                    Button("Send", systemImage: "arrow.up") { send() }
                        .labelStyle(.iconOnly).buttonStyle(.borderedProminent)
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !model.phase.hasConversation || isSending)
                        .help(model.phase.hasConversation ? "Send message" : "Start voice to send a message")
                }
                .controlSize(.small)
            }
            .padding(StudyDesign.inset)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: StudyDesign.contentRadius))
            .overlay(RoundedRectangle(cornerRadius: StudyDesign.contentRadius).strokeBorder(.separator, lineWidth: 0.5))
        }
        .frame(maxWidth: 860)
        .frame(maxWidth: .infinity)
    }

    private func send() {
        guard !isSending, !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let text = draft
        isSending = true
        Task {
            if await model.sendStudyMessage(text), draft == text { draft = "" }
            isSending = false
        }
    }
}
