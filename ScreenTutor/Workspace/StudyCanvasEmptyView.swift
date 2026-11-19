import SwiftUI

struct StudyCanvasEmptyView: View {
    let model: AppModel
    let addCourse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: StudyDesign.sectionGap) {
            Image(systemName: model.courses.selectedCourse == nil ? "books.vertical" : "rectangle.on.rectangle")
                .font(.largeTitle).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 10) {
                Text(model.courses.selectedCourse == nil ? "Bring your course.\nBuild your understanding." : "What would you like\nto understand?")
                    .font(.largeTitle.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                Text(model.courses.selectedCourse == nil
                     ? "Add your materials. Talk through your thinking. Work with one clear idea at a time."
                     : "Start with a question or your own attempt. Your tutor builds the next explanation, diagram or exercise here.")
                    .font(.body).foregroundStyle(.secondary).lineSpacing(3)
            }
            if model.courses.selectedCourse == nil {
                Button("Add your first course", systemImage: "plus", action: addCourse).buttonStyle(.borderedProminent)
            } else if model.courses.selectedCourse?.materials.isEmpty == true {
                ImportCourseMaterialsButton(model: model)
            } else if !model.settings.hasAPIKey {
                SettingsLink { Label("Connect your OpenAI key", systemImage: "key") }.buttonStyle(.borderedProminent)
            } else {
                Button("Start voice", systemImage: "waveform", action: model.toggleSession).buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: 440, alignment: .leading)
        .padding(StudyDesign.sectionGap)
    }
}
