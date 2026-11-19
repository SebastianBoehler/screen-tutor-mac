import PDFKit
import SwiftUI

struct CourseSourceView: View {
    let source: CourseSourceLocation
    @Environment(\.dismiss) private var dismiss
    @State private var text: String?
    @State private var document: PDFDocument?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Course source · page \(source.page)", systemImage: "doc.text")
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }.padding(16)
            Divider()
            if let document {
                CoursePDFView(document: document, page: source.page)
            } else if let text {
                ScrollView { Text(text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(24) }
            } else if let errorMessage {
                ContentUnavailableView("Cannot read source", systemImage: "doc.badge.ellipsis", description: Text(errorMessage))
            } else { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
        }
        .frame(width: 850, height: 720)
        .task {
            do {
                if source.url.pathExtension.lowercased() == "pdf" {
                    guard let pdf = PDFDocument(url: source.url), !pdf.isLocked, pdf.pageCount > 0 else {
                        throw CourseLibraryError.invalid("This PDF is unavailable or locked.")
                    }
                    document = pdf
                } else { text = try String(contentsOf: source.url, encoding: .utf8) }
            }
            catch { errorMessage = error.localizedDescription }
        }
    }
}

struct CoursePDFView: NSViewRepresentable {
    let document: PDFDocument
    let page: Int

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = document
        if let document = view.document, let target = document.page(at: min(max(page - 1, 0), max(document.pageCount - 1, 0))) {
            view.go(to: target)
        }
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {}
}
