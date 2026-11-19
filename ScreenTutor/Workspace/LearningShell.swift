import SwiftUI

enum StudyDestination: String, CaseIterable, Identifiable {
    case canvas, materials, plan, memory
    var id: Self { self }
    var title: String {
        switch self { case .canvas: "Study"; case .materials: "Materials"; case .plan: "Learning plan"; case .memory: "Learning memory" }
    }
    var symbol: String {
        switch self { case .canvas: "rectangle.on.rectangle"; case .materials: "doc.text"; case .plan: "calendar"; case .memory: "brain" }
    }
}

struct LearningShell: View {
    @Bindable var model: AppModel
    @State private var destination: StudyDestination? = .canvas
    @State private var showsConversation = false
    @State private var showsNewCourse = false
    @State private var showsCamera = false
    @State private var focused = true
    @State private var renderError: String?

    var body: some View {
        NavigationSplitView {
            LearningSidebar(model: model, destination: $destination, addCourse: { showsNewCourse = true })
                .navigationSplitViewColumnWidth(min: 200, ideal: 224, max: 280)
        } detail: {
            VStack(spacing: 0) {
                if let error = model.errorMessage ?? model.courses.errorMessage ?? model.workspace.errorMessage ?? renderError {
                    HStack(spacing: StudyDesign.controlGap) {
                        Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                        Spacer()
                        SettingsLink { Text("Settings") }
                    }.font(.callout).padding(StudyDesign.inset).background(.red.opacity(0.05))
                }
                switch destination ?? .canvas {
                case .canvas: canvas
                case .materials: CourseMaterialsView(model: model, addCourse: { showsNewCourse = true })
                case .plan: StudyDashboardView(model: model)
                case .memory: LearningMemoryView(workspace: model.workspace, embedded: true)
                }
            }
            .navigationTitle(model.courses.selectedCourse?.title ?? "ScreenTutor")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Desk camera", systemImage: model.deskCamera.isRunning ? "camera.fill" : "camera") { showsCamera = true }
                        .help("Show your notes to the tutor")
                    Button("Conversation", systemImage: "bubble.left.and.bubble.right") { showsConversation.toggle() }
                        .help("Show or hide the conversation")
                    SettingsLink { Label("Settings", systemImage: "gearshape") }
                }
            }
        }
        .inspector(isPresented: $showsConversation) {
            VStack(spacing: 0) {
                HStack {
                    Text("Conversation").font(.headline)
                    Spacer()
                    Button("Close conversation", systemImage: "xmark") { showsConversation = false }
                        .labelStyle(.iconOnly).buttonStyle(.plain)
                }.padding(StudyDesign.inset)
                RichLearningView(payload: payload("conversation"), workspace: model.workspace,
                    onLink: model.handleLearningLink, onFocus: { destination = .canvas; focused = true }, errorMessage: $renderError)
            }.inspectorColumnWidth(min: 280, ideal: 340, max: 440)
        }
        .frame(minWidth: 880, minHeight: 600)
        .sheet(isPresented: $showsNewCourse) { NewStudyCourseSheet(model: model) }
        .sheet(isPresented: $showsCamera) { DeskCameraView(model: model) }
        .sheet(item: $model.sourceToOpen) { CourseSourceView(source: $0) }
        .onChange(of: model.workspace.focusedArtifactID) { focused = true; destination = .canvas }
    }

    private var canvas: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: StudyDesign.sectionGap) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.workspace.learningGoal?.objective ?? "Learning canvas")
                        .font(.title3.weight(.semibold)).lineLimit(2)
                    Text(model.phase.hasConversation ? model.statusDetail : "One concept. Your reasoning. The next step.")
                        .font(.callout).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: StudyDesign.inset)
                if !model.workspace.artifacts.isEmpty {
                    Picker("Canvas view", selection: $focused) {
                        Text("Focus").tag(true)
                        Text("Overview").tag(false)
                    }.labelsHidden().pickerStyle(.segmented).frame(width: 148)
                }
            }
            .padding(.horizontal, StudyDesign.sectionGap).padding(.vertical, 20)
            if model.courses.selectedCourse == nil || model.workspace.artifacts.isEmpty {
                StudyCanvasEmptyView(model: model, addCourse: { showsNewCourse = true })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                RichLearningView(payload: payload("canvas"), workspace: model.workspace,
                    onLink: model.handleLearningLink, onFocus: { focused = true }, errorMessage: $renderError)
            }
            StudyComposer(model: model)
                .padding(.horizontal, StudyDesign.sectionGap).padding(.bottom, StudyDesign.sectionGap).padding(.top, StudyDesign.inset)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func payload(_ mode: String) -> RichLearningPayload {
        RichLearningPayload(mode: mode, artifacts: model.workspace.artifacts, messages: model.workspace.messages,
            focusedID: model.workspace.focusedArtifactID, liveAssistant: mode == "conversation" ? model.assistantTranscript : "", focusOnly: focused)
    }
}
