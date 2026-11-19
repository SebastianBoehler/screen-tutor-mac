import WebKit
import XCTest
@testable import ScreenTutor

@MainActor
final class RichLearningRendererTests: XCTestCase {
    func testLocalRendererTypesetsMathDiagramsAndKeepsFlashcardAnswerHidden() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = LearningWorkspaceStore(rootURL: root)
        try workspace.presentArtifact(id: "step", title: "One update", markdown: "$$x_{t+1}=x_t-\\eta \\nabla L(x_t)$$\n\n```mermaid\nflowchart LR\n A[Attempt] --> B[Check]\n```", section: "Mechanism")
        try workspace.presentArtifact(id: "card", title: "Recall", markdown: "Which direction?", section: "Recall", flashcardAnswer: "Opposite the gradient.")
        try workspace.presentArtifact(id: "unsafe", title: "Untrusted content", markdown: "<img src=x onerror=\"window.injected=true\"><script>window.injected=true</script><a href=\"javascript:alert(1)\">Unsafe</a>", section: "Test")
        let coordinator = RichLearningView.Coordinator()
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(coordinator, name: "learning")
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 900, height: 700), configuration: configuration)
        coordinator.webView = webView
        coordinator.workspace = workspace
        var rendererError: String?
        coordinator.onError = { rendererError = $0 }
        webView.navigationDelegate = coordinator
        defer { webView.configuration.userContentController.removeScriptMessageHandler(forName: "learning") }
        let url = try XCTUnwrap(Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Learning"))
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        func render() {
            coordinator.render(RichLearningPayload(mode: "canvas", artifacts: workspace.artifacts, messages: workspace.messages,
                focusedID: workspace.focusedArtifactID, liveAssistant: "", focusOnly: false))
        }
        render()
        try await waitUntil { try await self.js(webView, "String(document.querySelectorAll('.katex').length > 0 && document.querySelectorAll('.mermaid svg').length > 0)") == "true" }
        XCTAssertNil(rendererError)
        let hidden = try await js(webView, "String(document.body.innerText.includes('Opposite the gradient.'))")
        XCTAssertEqual(hidden, "false")
        let safe = try await js(webView, "String(!window.injected && !document.querySelector('img') && !document.querySelector('a[href^=\"javascript:\"]'))")
        XCTAssertEqual(safe, "true")
        _ = try await js(webView, "document.querySelector('.flashcard-actions button').click(); 'clicked'")
        try await waitUntil { workspace.artifacts.first { $0.id == "card" }?.flashcard?.revealed == true }
        render()
        try await waitUntil { try await self.js(webView, "String(document.body.innerText.includes('Opposite the gradient.'))") == "true" }
    }

    private func js(_ view: WKWebView, _ script: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            view.evaluateJavaScript(script) { value, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: value as? String ?? "") }
            }
        }
    }

    private func waitUntil(_ condition: () async throws -> Bool) async throws {
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            if try await condition() { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTFail("The rich learning renderer did not reach its expected state.")
    }
}
