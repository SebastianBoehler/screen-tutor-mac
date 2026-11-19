import SwiftUI

struct NewStudyCourseSheet: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: StudyDesign.sectionGap) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Add a course").font(.title2.weight(.semibold))
                Text("Keep its materials, artifacts and learning memory together.").foregroundStyle(.secondary)
            }
            TextField("Course name", text: $title).textFieldStyle(.roundedBorder).onSubmit(create)
            if let errorMessage { Text(errorMessage).font(.callout).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Add course", action: create).buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(StudyDesign.sectionGap).frame(width: 420)
    }

    private func create() {
        do {
            let course = try model.courses.createCourse(title: title)
            Task { await model.selectStudyCourse(course.id); dismiss() }
        } catch { errorMessage = error.localizedDescription }
    }
}
