import SwiftUI
import UniformTypeIdentifiers

struct CourseMaterialsView: View {
    let model: AppModel
    let addCourse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: StudyDesign.sectionGap) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Course materials").font(.title2.weight(.semibold))
                    Text("PDFs, notes and past exams stay on this Mac. The tutor retrieves relevant, page-linked excerpts.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if model.courses.selectedCourse != nil { ImportCourseMaterialsButton(model: model) }
            }.padding([.horizontal, .top], StudyDesign.sectionGap)
            if let course = model.courses.selectedCourse, !course.materials.isEmpty {
                List(course.materials) { material in
                    HStack(spacing: StudyDesign.controlGap) {
                        Image(systemName: "doc.text").font(.title2).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(material.title)
                            Text("\(material.pages) \(material.pages == 1 ? "page" : "pages")").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Open") {
                            do { model.sourceToOpen = CourseSourceLocation(url: try model.courses.sourceURL(materialID: material.id), page: 1) }
                            catch { model.courses.errorMessage = error.localizedDescription }
                        }
                    }.padding(.vertical, StudyDesign.compact)
                }.listStyle(.inset)
            } else {
                ContentUnavailableView {
                    Label(model.courses.selectedCourse == nil ? "Add a course first" : "No materials yet", systemImage: "doc.text")
                } description: {
                    Text("Import searchable PDFs, Markdown or text. Scanned PDFs need a text layer.")
                } actions: {
                    if model.courses.selectedCourse == nil { Button("Add course", action: addCourse) }
                    else { ImportCourseMaterialsButton(model: model) }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if model.courses.isImporting { ProgressView(model.courses.importStatus).padding(StudyDesign.sectionGap) }
        }
    }
}

struct ImportCourseMaterialsButton: View {
    let model: AppModel
    @State private var isPresented = false

    var body: some View {
        Button("Import materials", systemImage: "plus") { isPresented = true }
            .disabled(model.courses.isImporting || model.courses.selectedCourseID == nil)
            .fileImporter(isPresented: $isPresented,
                allowedContentTypes: [.pdf, .plainText, UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)],
                allowsMultipleSelection: true) { result in
                do {
                    let urls = try result.get()
                    guard let id = model.courses.selectedCourseID else { return }
                    Task {
                        do { try await model.courses.importFiles(urls, into: id) }
                        catch { model.courses.errorMessage = error.localizedDescription }
                    }
                } catch { model.courses.errorMessage = error.localizedDescription }
            }
    }
}
