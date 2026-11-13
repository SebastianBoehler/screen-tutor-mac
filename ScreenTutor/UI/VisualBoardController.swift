import AppKit
import WebKit

/// A floating, resizable teaching board. The voice tutor writes Markdown with
/// LaTeX math ($...$, $$...$$) and ```mermaid diagrams; the board renders it
/// next to whatever the learner is doing, and pins the active desk task on top.
@MainActor
final class VisualBoardController: NSObject, WKNavigationDelegate {
    private let panel: NSPanel
    private let webView: WKWebView
    private var isLoaded = false
    private var pendingScript: String?
    private var visual: BoardVisual?
    private var task: DeskTask?

    struct BoardVisual: Encodable {
        let title: String
        let markdown: String
    }

    override init() {
        let configuration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: configuration)
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 640),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        panel.title = "Tutor Board"
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = webView
        panel.setFrameAutosaveName("ScreenTutorVisualBoard")
        if panel.frame.origin == .zero, let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.maxX - 580, y: frame.maxY - 660))
        }
        webView.loadHTMLString(Self.html, baseURL: URL(string: "https://screentutor.local/"))
    }

    var isVisible: Bool { panel.isVisible }

    func show(title: String, markdown: String) {
        visual = BoardVisual(title: title, markdown: markdown)
        render()
        panel.orderFrontRegardless()
    }

    func setTask(_ task: DeskTask?) {
        self.task = task
        render()
        if task != nil { panel.orderFrontRegardless() }
    }

    func clear() {
        visual = nil
        render()
        if task == nil { panel.orderOut(nil) }
    }

    func toggle() {
        if panel.isVisible { panel.orderOut(nil) } else { render(); panel.orderFrontRegardless() }
    }

    private func render() {
        struct Payload: Encodable {
            let visual: BoardVisual?
            let task: TaskPayload?
        }
        struct TaskPayload: Encodable {
            let title: String
            let prompt: String
            let label: String
        }
        let payload = Payload(
            visual: visual,
            task: task.map { TaskPayload(title: $0.title, prompt: $0.prompt, label: $0.taskKind.boardLabel) }
        )
        guard
            let data = try? JSONEncoder().encode(payload),
            let json = String(data: data, encoding: .utf8)
        else { return }
        let script = "window.renderBoard(\(json));"
        if isLoaded {
            webView.evaluateJavaScript(script)
        } else {
            pendingScript = script
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoaded = true
        if let script = pendingScript {
            pendingScript = nil
            webView.evaluateJavaScript(script)
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        // Links in tutor content open in the default browser, never inside the board.
        if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
            NSWorkspace.shared.open(url)
            return .cancel
        }
        return .allow
    }

    private static let html = """
        <!doctype html><html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css">
        <script src="https://cdn.jsdelivr.net/npm/marked@12.0.2/marked.min.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/contrib/auto-render.min.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/mermaid@10.9.1/dist/mermaid.min.js"></script>
        <style>
        :root{color-scheme:light dark;--fg:#1d1d1f;--muted:#6e6e73;--card:#f5f5f7;--accent:#0a84ff;--bg:#ffffff}
        @media (prefers-color-scheme: dark){:root{--fg:#f5f5f7;--muted:#a1a1a6;--card:#2c2c2e;--bg:#1c1c1e}}
        body{margin:0;padding:18px 20px 28px;font:15px/1.5 -apple-system,system-ui;color:var(--fg);background:var(--bg)}
        .task{background:var(--card);border-left:4px solid var(--accent);border-radius:10px;padding:10px 14px;margin-bottom:16px}
        .task .label{font-size:11px;letter-spacing:.06em;text-transform:uppercase;color:var(--accent);font-weight:600}
        .task h3{margin:2px 0 4px;font-size:16px}
        h1{font-size:21px;margin:4px 0 10px} h2{font-size:18px} h3{font-size:16px}
        pre{background:var(--card);padding:10px;border-radius:8px;overflow:auto}
        code{font-family:ui-monospace,Menlo,monospace;font-size:13px}
        table{border-collapse:collapse} td,th{border:1px solid var(--muted);padding:4px 8px}
        .empty{color:var(--muted);text-align:center;margin-top:30vh}
        .mermaid{background:#fff;border-radius:8px;padding:8px;text-align:center}
        </style></head><body><div id="root"><p class="empty">The tutor's visuals appear here.</p></div>
        <script>
        function esc(s){return String(s).replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]))}
        function md(s){
          if(!window.marked) return '<pre>'+esc(s)+'</pre>';
          const math=[]; // protect LaTeX from Markdown emphasis parsing
          s=s.replace(/\\$\\$[\\s\\S]+?\\$\\$|\\$[^$\\n]+?\\$/g,m=>{math.push(m);return '@@MATH'+(math.length-1)+'@@'});
          let h=marked.parse(s);
          return h.replace(/@@MATH(\\d+)@@/g,(_,i)=>esc(math[+i]));
        }
        window.renderBoard=async function(p){
          let h='';
          if(p.task){h+='<div class="task"><div class="label">'+esc(p.task.label||'Your task')+'</div><h3>'+esc(p.task.title)+'</h3>'+md(p.task.prompt)+'</div>'}
          if(p.visual){h+='<h1>'+esc(p.visual.title)+'</h1>'+md(p.visual.markdown)}
          if(!h){h='<p class="empty">The tutor\\'s visuals appear here.</p>'}
          const root=document.getElementById('root'); root.innerHTML=h;
          root.querySelectorAll('pre code.language-mermaid').forEach(c=>{const d=document.createElement('div');d.className='mermaid';d.textContent=c.textContent;c.parentElement.replaceWith(d)});
          if(window.renderMathInElement){renderMathInElement(root,{delimiters:[{left:'$$',right:'$$',display:true},{left:'$',right:'$',display:false},{left:'\\\\[',right:'\\\\]',display:true},{left:'\\\\(',right:'\\\\)',display:false}],throwOnError:false})}
          if(window.mermaid){try{mermaid.initialize({startOnLoad:false,theme:'neutral'});await mermaid.run({querySelector:'.mermaid'})}catch(e){}}
        };
        </script></body></html>
        """
}
