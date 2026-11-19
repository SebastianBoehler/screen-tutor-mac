import Foundation

extension RealtimeFunctionTool {
    static let clickInWindow = RealtimeFunctionTool(
        type: "function",
        name: "click_in_window",
        description: "Click a point in the window most recently returned by capture_window, after the learner asked you to do something on their Mac. Capture again afterwards to verify.",
        parameters: Parameters(
            type: "object",
            properties: [
                "x": Property(type: "number", description: "Horizontal target, normalized 0 to 1 in the screenshot.", minimum: 0, maximum: 1),
                "y": Property(type: "number", description: "Vertical target from the top, normalized 0 to 1 in the screenshot.", minimum: 0, maximum: 1),
                "click": .string("single, double, or right.", enumValues: ["single", "double", "right"])
            ],
            required: ["x", "y", "click"],
            additionalProperties: false
        )
    )

    static let typeText = RealtimeFunctionTool(
        type: "function",
        name: "type_text",
        description: "Type text into the currently focused field of the frontmost app (click the field first). A newline presses Return.",
        parameters: Parameters(
            type: "object",
            properties: ["text": .string("Exact text to type.")],
            required: ["text"],
            additionalProperties: false
        )
    )

    static let pressKeys = RealtimeFunctionTool(
        type: "function",
        name: "press_keys",
        description: "Press a key or shortcut in the frontmost app, e.g. return, escape, tab, cmd+t, cmd+shift+z.",
        parameters: Parameters(
            type: "object",
            properties: ["keys": .string("Key combination joined with +.")],
            required: ["keys"],
            additionalProperties: false
        )
    )

    static let scrollWindow = RealtimeFunctionTool(
        type: "function",
        name: "scroll_window",
        description: "Scroll the window most recently returned by capture_window.",
        parameters: Parameters(
            type: "object",
            properties: [
                "direction": .string("up or down.", enumValues: ["up", "down"]),
                "amount": Property(type: "number", description: "Lines to scroll, 1 to 20.", minimum: 1, maximum: 20)
            ],
            required: ["direction", "amount"],
            additionalProperties: false
        )
    )

    static let doOnComputer = RealtimeFunctionTool(
        type: "function",
        name: "do_on_computer",
        description: "Hand a multi-step goal on the Mac to the background computer agent (for example 'open the linear algebra lecture PDF in Downloads and go to the page on eigenvalues', 'start a new Word document titled Week 3 notes'). Only after the learner asked or agreed. It runs while you keep talking and reports back with a <computer_agent> note.",
        parameters: Parameters(
            type: "object",
            properties: ["goal": .string("Concrete, self-contained goal including any names, titles, or URLs.")],
            required: ["goal"],
            additionalProperties: false
        )
    )

    static let stopComputerTask = RealtimeFunctionTool(
        type: "function",
        name: "stop_computer_task",
        description: "Stop the background computer agent immediately, e.g. when the learner says stop.",
        parameters: .empty
    )
}
