import AppKit
import SwiftUI
import WebKit

struct RichLearningPayload: Encodable, Equatable {
    let mode: String
    let artifacts: [LearningArtifact]
    let messages: [WorkspaceMessage]
    let focusedID: String?
    let liveAssistant: String
    let focusOnly: Bool
}

/// One local, themed renderer shared by inline replies and the organized canvas.
struct RichLearningView: NSViewRepresentable {
    let payload: RichLearningPayload
    let workspace: LearningWorkspaceStore
    let onLink: @MainActor (URL) -> Void
    var onFocus: (@MainActor () -> Void)? = nil
    @Binding var errorMessage: String?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(context.coordinator, name: "learning")
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.setValue(false, forKey: "drawsBackground")
        configure(context.coordinator, webView: view)
        guard let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Learning") else {
            context.coordinator.report("The learning renderer is missing from this build.")
            return view
        }
        view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        configure(context.coordinator, webView: view)
        context.coordinator.render(payload)
    }

    static func dismantleNSView(_ view: WKWebView, coordinator: Coordinator) {
        view.configuration.userContentController.removeScriptMessageHandler(forName: "learning")
        view.stopLoading()
    }

    private func configure(_ coordinator: Coordinator, webView: WKWebView) {
        coordinator.webView = webView
        coordinator.workspace = workspace
        coordinator.onLink = onLink
        coordinator.onFocus = onFocus
        coordinator.onError = { errorMessage = $0 }
    }

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        weak var webView: WKWebView?
        weak var workspace: LearningWorkspaceStore?
        var onLink: (@MainActor (URL) -> Void)?
        var onFocus: (@MainActor () -> Void)?
        var onError: (@MainActor (String) -> Void)?
        private var isReady = false
        private var pending: RichLearningPayload?
        private var rendered: RichLearningPayload?

        func render(_ payload: RichLearningPayload) {
            pending = payload
            guard isReady, payload != rendered, let webView else { return }
            do {
                let json = String(decoding: try JSONEncoder().encode(payload), as: UTF8.self)
                rendered = payload
                webView.evaluateJavaScript("window.renderLearning(\(json))") { [weak self] _, error in
                    if let error { self?.report(error.localizedDescription) }
                }
            } catch { report(error.localizedDescription) }
        }

        func report(_ message: String) { onError?(message) }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame, let body = message.body as? [String: String], let type = body["type"] else { return }
            do {
                switch type {
                case "ready":
                    isReady = true
                    if let pending { render(pending) }
                case "focus":
                    if let id = body["id"] { try workspace?.focus(id); onFocus?() }
                case "flashcard":
                    if let id = body["id"], let action = body["action"] { try workspace?.reviewFlashcard(id: id, action: action) }
                case "link":
                    if let value = body["url"], let url = URL(string: value),
                       ["https", "http", "screentutor-source"].contains(url.scheme?.lowercased() ?? "") { onLink?(url) }
                default: break
                }
            } catch { report(error.localizedDescription) }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { report(error.localizedDescription) }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { report(error.localizedDescription) }
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { report("The learning renderer stopped. Reopen the workspace.") }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard navigationAction.navigationType == .other, navigationAction.request.url?.isFileURL == true else { return .cancel }
            return .allow
        }
    }
}
