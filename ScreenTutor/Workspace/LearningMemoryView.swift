import SwiftUI

struct LearningMemoryView: View {
    let workspace: LearningWorkspaceStore
    var embedded = false
    @Environment(\.dismiss) private var dismiss
    @State private var editing: LearnerInsight?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Learning memory").font(.title2.weight(.semibold))
                Spacer()
                if !embedded { Button("Done") { dismiss() }.keyboardShortcut(.cancelAction) }
            }
            Text("Observed reasoning and teaching hypotheses. You can correct these notes; they do not establish mastery.")
                .foregroundStyle(.secondary)
            if workspace.insights.isEmpty {
                ContentUnavailableView("Your reasoning comes first", systemImage: "brain",
                    description: Text("As you explain your thinking, the tutor can remember useful connections and specific stumbling blocks here."))
            } else {
                List(workspace.insights) { insight in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(insight.observation).font(.headline)
                            Spacer()
                            Button("Edit") { editing = insight }
                        }
                        Text("Evidence: \(insight.evidence)").textSelection(.enabled)
                        Text("Teaching hypothesis: \(insight.teachingImplication)").foregroundStyle(.secondary)
                    }.padding(.vertical, 8)
                }
            }
        }
        .padding(StudyDesign.sectionGap).frame(minWidth: 480, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
        .sheet(item: $editing) { insight in LearningInsightEditor(insight: insight, workspace: workspace) }
    }
}

private struct LearningInsightEditor: View {
    let insight: LearnerInsight
    let workspace: LearningWorkspaceStore
    @Environment(\.dismiss) private var dismiss
    @State private var observation = ""
    @State private var evidence = ""
    @State private var implication = ""
    @State private var errorMessage: String?

    var body: some View {
        Form {
            TextField("Observation", text: $observation, axis: .vertical)
            TextField("Your explanation or response", text: $evidence, axis: .vertical)
            TextField("Teaching hypothesis", text: $implication, axis: .vertical)
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            HStack {
                Button("Remove note", role: .destructive) {
                    do { try workspace.removeInsight(id: insight.id); dismiss() }
                    catch { errorMessage = error.localizedDescription }
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Save") {
                    do {
                        try workspace.updateInsight(id: insight.id, observation: observation, evidence: evidence, implication: implication)
                        dismiss()
                    } catch { errorMessage = error.localizedDescription }
                }.buttonStyle(.borderedProminent)
            }
        }
        .formStyle(.grouped).padding(16).frame(width: 620, height: 350)
        .onAppear { observation = insight.observation; evidence = insight.evidence; implication = insight.teachingImplication }
    }
}
