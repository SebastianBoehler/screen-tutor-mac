import AppKit
import Foundation

/// Mouse and keyboard control: direct single-step tools for the voice tutor
/// (relative to the last captured window) and the background computer agent.
extension AppModel {
    static let computerToolNames: Set<String> = [
        "click_in_window", "type_text", "press_keys", "scroll_window",
        "do_on_computer", "stop_computer_task"
    ]

    func handleComputerToolCall(
        _ item: RealtimeItem,
        userItemID: String?,
        turn: Int,
        generation: Int,
        connectionID: RealtimeConnectionID
    ) async throws -> Bool {
        guard let name = item.name, Self.computerToolNames.contains(name) else { return false }
        let arguments = ToolArguments(json: item.arguments)
        let result: ToolResult

        do {
            if name != "stop_computer_task" {
                guard settings.computerControlEnabled else { throw InputControlError.disabled }
            }
            switch name {
            case "click_in_window":
                let point = try await windowPoint(arguments)
                let click = arguments.optionalString("click") ?? "single"
                if let showTeachingPointer {
                    try? showTeachingPointer(TeachingPointer(globalPoint: point.appKit, label: "click"))
                }
                try await Task.sleep(for: .milliseconds(300))
                try inputController.click(
                    at: point.coreGraphics,
                    button: click == "right" ? .right : .left,
                    clickCount: click == "double" ? 2 : 1
                )
                lastSnapshotWindowContext = nil
                result = .ok(["clicked": click, "next": "capture_window again to verify"])
            case "type_text":
                let text = try arguments.string("text")
                try await inputController.type(text)
                result = .ok(["typed_characters": String(text.count)])
            case "press_keys":
                let keys = try arguments.string("keys")
                try inputController.press(try KeyCombo(parsing: keys))
                result = .ok(["pressed": keys])
            case "scroll_window":
                guard let context = lastSnapshotWindowContext else {
                    throw TeachingPointerError.noWindowContext
                }
                let frame = try await screenTools.resolveWindowFrame(for: context)
                let center = InputController.coreGraphicsPoint(
                    fromAppKit: CGPoint(x: frame.midX, y: frame.midY)
                )
                let amount = Int(arguments.number("amount") ?? 5)
                let direction = arguments.optionalString("direction") ?? "down"
                try inputController.scroll(at: center, lines: direction == "up" ? amount : -amount)
                result = .ok(["scrolled": "\(direction) \(amount)"])
            case "do_on_computer":
                let goal = try arguments.string("goal")
                try computerAgent.start(goal: goal)
                result = .ok([
                    "status": "started",
                    "note": "The agent works in the background and reports back with a <computer_agent> note. The learner can stop it by moving the mouse."
                ])
            case "stop_computer_task":
                let wasRunning = computerAgent.isRunning
                computerAgent.stop()
                result = .ok(["status": wasRunning ? "stopped" : "no task was running"])
            default:
                return false
            }
        } catch {
            result = .failure(code: "\(name)_failed", message: error.localizedDescription)
        }

        try await completeDeskToolCall(
            item,
            result: result,
            image: nil,
            userItemID: userItemID,
            turn: turn,
            generation: generation,
            connectionID: connectionID
        )
        return true
    }

    /// Hands the agent's final report to the voice tutor once the conversation is idle.
    func deliverComputerAgentReport(_ report: ComputerAgentReport) async {
        for _ in 0..<60 {
            guard realtimeConnectionID != nil else { return }
            if await deliverAutomatedNote(text: report.tutorNote, jpeg: report.finalScreenshot) {
                return
            }
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private func windowPoint(
        _ arguments: ToolArguments
    ) async throws -> (appKit: CGPoint, coreGraphics: CGPoint) {
        guard let context = lastSnapshotWindowContext else { throw TeachingPointerError.noWindowContext }
        guard
            let x = arguments.number("x"), let y = arguments.number("y"),
            (0...1).contains(x), (0...1).contains(y)
        else { throw TeachingPointerError.outOfBounds }
        let frame = try await screenTools.resolveWindowFrame(for: context)
        let appKit = CGPoint(x: frame.minX + x * frame.width, y: frame.maxY - y * frame.height)
        return (appKit, InputController.coreGraphicsPoint(fromAppKit: appKit))
    }
}
