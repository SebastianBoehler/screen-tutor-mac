import AppKit
import WebKit

struct LessonPlayerState: Sendable, Equatable {
    var videoID = ""
    var title = ""
    var time: Double = 0
    var duration: Double = 0
    /// YouTube player state: -1 unstarted, 0 ended, 1 playing, 2 paused, 3 buffering, 5 cued.
    var playerState = -1
    var rate: Double = 1
    var loop: ClosedRange<Double>?
    var errorCode: Int?

    var isPlaying: Bool { playerState == 1 || playerState == 3 }

    var summary: [String: String] {
        var fields = [
            "video_id": videoID,
            "title": title,
            "time": YouTubeCatalog.timestamp(time),
            "time_seconds": String(Int(time)),
            "duration": YouTubeCatalog.timestamp(duration),
            "state": isPlaying ? "playing" : (playerState == 0 ? "ended" : "paused"),
            "rate": String(format: "%.2g", rate)
        ]
        if let loop { fields["loop"] = "\(YouTubeCatalog.timestamp(loop.lowerBound))–\(YouTubeCatalog.timestamp(loop.upperBound))" }
        return fields
    }
}

enum LessonPlayerError: LocalizedError {
    case notOpen
    case playerError(Int)
    case notReady

    var errorDescription: String? {
        switch self {
        case .notOpen: "No video is open. Use play_video first."
        case .playerError(let code):
            code == 101 || code == 150 || code == 153
                ? "This video does not allow playback outside YouTube (error \(code)). Pick another one."
                : "The YouTube player reported error \(code)."
        case .notReady: "The video player did not become ready in time."
        }
    }
}

/// ScreenTutor's own YouTube window (IFrame Player API in a WKWebView), so the
/// tutor can play, pause, seek, loop and slow down the video it is teaching with.
@MainActor
final class LessonPlayerController: NSObject, WKScriptMessageHandler, NSWindowDelegate {
    private var panel: NSPanel?
    private var webView: WKWebView?
    private(set) var state = LessonPlayerState()
    private var readyWaiters: [CheckedContinuation<Void, Error>] = []
    /// Called when the player paused itself at a planned point (seconds).
    var onAutoPause: ((Double) -> Void)?
    private(set) var pausePoints: [Double] = []

    var isOpen: Bool { panel?.isVisible == true }
    var windowNumber: Int? { panel.map(\.windowNumber) }

    /// Opens the player (or reuses it) and waits until the video is ready.
    func play(videoID: String, title: String, start: Double = 0, pauseAt: [Double] = []) async throws {
        guard YouTubeCatalog.isValidVideoID(videoID) else { throw YouTubeError.invalidVideoID }
        let webView = ensureWindow(title: title)
        state = LessonPlayerState(videoID: videoID, title: title)
        webView.loadHTMLString(Self.html(videoID: videoID, start: Int(start)), baseURL: Self.origin)
        panel?.title = title.isEmpty ? "Lesson video" : title
        panel?.orderFrontRegardless()
        try await waitUntilReady(timeout: 12)
        try await setPauses(pauseAt)
    }

    /// Planned points where the video pauses itself (segmenting for recall questions).
    func setPauses(_ seconds: [Double]) async throws {
        pausePoints = Array(Set(seconds.filter { $0 > 0 })).sorted()
        let list = pausePoints.map { String(format: "%.1f", $0) }.joined(separator: ",")
        try await run("st.setPauses([\(list)])")
    }

    /// Chapter ends after `start`, at least `minimumGap` apart, at most `limit`.
    nonisolated static func chapterPauses(_ chapters: [VideoChapter], after start: Double, minimumGap: Double = 90, limit: Int = 8) -> [Double] {
        var points: [Double] = []
        var last = start
        for chapter in chapters where Double(chapter.seconds) > start + 45 {
            let point = Double(chapter.seconds)
            if point - last >= minimumGap {
                points.append(point)
                last = point
            }
            if points.count == limit { break }
        }
        return points
    }

    func play() async throws { try await run("st.play()") }
    func pause() async throws { try await run("st.pause()") }
    func seek(to seconds: Double) async throws { try await run("st.seek(\(max(0, seconds)))") }
    func setRate(_ rate: Double) async throws { try await run("st.rate(\(min(max(rate, 0.25), 2)))") }

    func loop(from start: Double, to end: Double) async throws {
        guard end > start else { return }
        try await run("st.loop(\(start), \(end))")
    }

    func clearLoop() async throws { try await run("st.unloop()") }

    func close() {
        webView?.evaluateJavaScript("st && st.pause()")
        panel?.orderOut(nil)
    }

    private func run(_ script: String) async throws {
        guard let webView, isOpen else { throw LessonPlayerError.notOpen }
        if let code = state.errorCode { throw LessonPlayerError.playerError(code) }
        _ = try? await webView.evaluateJavaScript(script)
        try? await Task.sleep(for: .milliseconds(250))
        if let raw = try? await webView.evaluateJavaScript("JSON.stringify(st.snapshot())") as? String {
            apply(raw)
        }
    }

    // MARK: window

    private func ensureWindow(title: String) -> WKWebView {
        if let webView, let panel {
            panel.orderFrontRegardless()
            return webView
        }
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.userContentController.add(WeakScriptHandler(self), name: "player")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 560),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = title
        panel.contentView = webView
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentAspectRatio = NSSize(width: 16, height: 9)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.maxX - 980, y: frame.maxY - 600))
        }
        self.panel = panel
        self.webView = webView
        return webView
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        MainActor.assumeIsolated {
            webView?.evaluateJavaScript("st && st.pause()")
        }
    }

    private func waitUntilReady(timeout: Double) async throws {
        let timer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(timeout))
            guard !Task.isCancelled else { return }
            self?.resolveWaiters(.failure(LessonPlayerError.notReady))
        }
        defer { timer.cancel() }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            readyWaiters.append(continuation)
        }
        if let code = state.errorCode { throw LessonPlayerError.playerError(code) }
    }

    private func resolveWaiters(_ result: Result<Void, Error>) {
        let waiters = readyWaiters
        readyWaiters.removeAll()
        for waiter in waiters { waiter.resume(with: result) }
    }

    // MARK: bridge

    nonisolated func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? String else { return }
        MainActor.assumeIsolated { self.apply(body) }
    }

    private func apply(_ json: String) {
        guard
            let data = json.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        if let code = object["error"] as? Int {
            state.errorCode = code
            resolveWaiters(.failure(LessonPlayerError.playerError(code)))
            return
        }
        if let id = object["videoId"] as? String, !id.isEmpty { state.videoID = id }
        // Keep the catalog title; the player's title may be machine-translated.
        if state.title.isEmpty, let title = object["title"] as? String, !title.isEmpty { state.title = title }
        if let time = object["time"] as? Double { state.time = time }
        if let duration = object["duration"] as? Double, duration > 0 { state.duration = duration }
        if let player = object["state"] as? Int { state.playerState = player }
        if let rate = object["rate"] as? Double { state.rate = rate }
        if let loop = object["loop"] as? [String: Double], let start = loop["start"], let end = loop["end"], end > start {
            state.loop = start...end
        } else if object.keys.contains("loop") {
            state.loop = nil
        }
        if object["ready"] as? Bool == true { resolveWaiters(.success(())) }
        if let point = object["autoPause"] as? Double {
            pausePoints.removeAll { abs($0 - point) < 0.5 }
            onAutoPause?(point)
        }
    }

    // The embedded player refuses to play without an https referrer, so the page
    // is given a neutral origin. Nothing is ever loaded from it.
    static var origin = URL(string: "https://www.youtube-nocookie.com/")!

    static func html(videoID: String, start: Int) -> String {
        """
        <!doctype html><html><head><meta charset="utf-8">
        <meta name="referrer" content="strict-origin-when-cross-origin">
        <style>html,body{margin:0;height:100%;background:#000;overflow:hidden}#p{position:absolute;inset:0;width:100%;height:100%}</style>
        </head><body><div id="p"></div>
        <script>
        let player = null, loopRange = null, pauses = [], lastTime = 0;
        const post = (o) => window.webkit.messageHandlers.player.postMessage(JSON.stringify(o));
        function snapshot() {
          if (!player || !player.getCurrentTime) return {};
          const d = player.getVideoData ? player.getVideoData() : {};
          return { videoId: d.video_id || "", title: d.title || "", time: player.getCurrentTime() || 0,
                   duration: player.getDuration() || 0, state: player.getPlayerState(),
                   rate: player.getPlaybackRate(), loop: loopRange };
        }
        window.onYouTubeIframeAPIReady = function () {
          player = new YT.Player("p", {
            videoId: "\(videoID)",
            playerVars: { start: \(max(0, start)), autoplay: 1, rel: 0, playsinline: 1, origin: location.origin },
            events: {
              onReady: () => post(Object.assign(snapshot(), { ready: true })),
              onStateChange: () => post(snapshot()),
              onError: (e) => post({ error: e.data })
            }
          });
        };
        setInterval(() => {
          if (!player || !player.getCurrentTime) return;
          const now = player.getCurrentTime();
          if (loopRange && now >= loopRange.end) player.seekTo(loopRange.start, true);
          // Planned pauses fire only when playback runs across them, not when seeking past.
          if (player.getPlayerState() === 1 && now - lastTime < 2) {
            const hit = pauses.find((p) => lastTime < p && now >= p);
            if (hit !== undefined) {
              player.pauseVideo();
              pauses = pauses.filter((p) => p !== hit);
              post({ autoPause: hit });
            }
          }
          lastTime = now;
          post(snapshot());
        }, 500);
        window.st = {
          snapshot,
          play: () => player.playVideo(),
          pause: () => player.pauseVideo(),
          seek: (s) => player.seekTo(s, true),
          rate: (r) => player.setPlaybackRate(r),
          loop: (a, b) => { loopRange = { start: a, end: b }; player.seekTo(a, true); player.playVideo(); },
          unloop: () => { loopRange = null; },
          setPauses: (list) => { pauses = list; }
        };
        </script>
        <script src="https://www.youtube.com/iframe_api"></script>
        </body></html>
        """
    }
}

/// Avoids the retain cycle between WKUserContentController and its handler.
private final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?

    init(_ target: WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(controller, didReceive: message)
    }
}
