import SwiftUI

struct LearningSidebar: View {
    let model: AppModel
    @Binding var destination: StudyDestination?
    let addCourse: () -> Void

    var body: some View {
        List(selection: $destination) {
            Section {
                ForEach(StudyDestination.allCases) { page in
                    Label(page.title, systemImage: page.symbol).tag(page)
                        .padding(.vertical, 3)
                }
            }
            Section {
                ForEach(model.courses.courses) { course in
                    Button {
                        destination = .canvas
                        Task { await model.selectStudyCourse(course.id) }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: course.id == model.courses.selectedCourseID ? "book.closed.fill" : "book.closed")
                                .foregroundStyle(.secondary)
                            Text(course.title).lineLimit(2)
                            Spacer(minLength: 0)
                            if course.id == model.courses.selectedCourseID { Image(systemName: "checkmark").font(.caption).foregroundStyle(.secondary) }
                        }.foregroundStyle(.primary).padding(.vertical, 5)
                    }
                    .buttonStyle(.plain).disabled(model.courses.isImporting)
                    .help(course.title)
                }
                Button(action: addCourse) { Label("Add course", systemImage: "plus") }
                    .buttonStyle(.plain).foregroundStyle(.secondary).padding(.vertical, 5)
            } header: { Text("Courses") }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                Image(systemName: model.phase.hasConversation ? "waveform" : "circle")
                    .foregroundStyle(model.phase.hasConversation ? Color.accentColor : .secondary)
                Text(model.phase.hasConversation ? model.statusTitle : "Voice not connected")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            }.padding(StudyDesign.inset)
        }
    }
}
