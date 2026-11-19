import XCTest
@testable import ScreenTutor

@MainActor
final class StudyHarnessFlowTests: XCTestCase {
    func testSourceToGoalToArtifactToRecallUsesRealToolDispatch() async throws {
        let transport = StudyRecordingTransport()
        let client = RealtimeClient(makeTransport: { transport })
        let model = makeTestAppModel(realtimeClient: client)
        let course = try model.courses.createCourse(title: "Optimization")
        await model.selectStudyCourse(course.id)
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("lecture-\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: file) }
        try "# Gradient descent\nThe gradient points toward steepest increase. Subtract eta times the gradient to decrease the loss locally.".write(to: file, atomically: true, encoding: .utf8)
        try await model.courses.importFiles([file], into: course.id)
        let connectionID = RealtimeConnectionID()
        try await client.connect(connectionID: connectionID, apiKey: "sk-test", model: .flagship, onEvent: { _ in }, onDisconnect: { _ in })
        model.realtimeConnectionID = connectionID
        model.phase = .listening
        let sent = await model.sendStudyMessage("Why do we subtract the gradient? My attempt: it points uphill.")
        XCTAssertTrue(sent)
        let turn = model.turnTracker.current

        func tool(_ name: String, _ arguments: String) async throws -> [String: Any] {
            let item = RealtimeItem(id: "call_\(UUID().uuidString.prefix(8))", type: "function_call", name: name,
                                    callID: "function_\(name)", arguments: arguments)
            try await model.handleFunctionCall(item, userItemID: model.currentUserItemID, turn: turn,
                                              generation: model.sessionGeneration, connectionID: connectionID)
            let result = try XCTUnwrap(transport.messages.compactMap { value -> [String: Any]? in
                guard let object = try? JSONSerialization.jsonObject(with: Data(value.utf8)) as? [String: Any],
                      let item = object["item"] as? [String: Any], item["type"] as? String == "function_call_output",
                      let output = item["output"] as? String else { return nil }
                return try? JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any]
            }.last)
            return result
        }
        let sources = try await tool("search_course_materials", #"{"query":"gradient"}"#)
        XCTAssertEqual(sources["ok"] as? Bool, true)
        XCTAssertTrue((sources["excerpts"] as? String)?.contains("screentutor-source://") == true)
        _ = try await tool("start_topic", #"{"topic":"Gradient descent","subskills":["Update direction"]}"#)
        _ = try await tool("set_learning_goal", #"{"objective":"Explain why the update goes downhill","topic":"Gradient descent","subskill":"Update direction"}"#)
        _ = try await tool("show_visual", #"{"artifact_id":"direction","title":"Why subtract?","markdown":"The gradient points uphill. Which sign takes a small step downhill?","section":"First principles"}"#)
        _ = try await tool("show_visual", #"{"artifact_id":"direction","title":"Why subtract?","markdown":"Predict the sign before revealing the next step.","section":"Your turn"}"#)
        XCTAssertEqual(model.workspace.artifacts.filter { $0.id == "direction" }.count, 1)
        _ = try await tool("present_flashcard", #"{"id":"recall","title":"Update direction","question":"Which direction decreases loss locally?","answer":"Opposite the gradient.","section":"Retrieval"}"#)
        XCTAssertFalse(try XCTUnwrap(model.workspace.artifacts.first { $0.id == "recall" }?.flashcard).revealed)
        XCTAssertTrue(model.learner.topic(named: "Gradient descent")?.subskills.first?.evidence.isEmpty == true)
        try model.workspace.setMode(.exam)
        let rejected = try await tool("show_visual", #"{"title":"A hint","markdown":"Subtract the gradient."}"#)
        XCTAssertEqual(rejected["ok"] as? Bool, false)
        XCTAssertNil(model.workspace.artifacts.first { $0.title == "A hint" })
        await model.stopSession()
    }
}

@MainActor
final class StudyRecordingTransport: RealtimeTransporting {
    var messages: [String] = []
    func connect(apiKey: String, model: RealtimeModel, onMessage: @escaping (String) async -> Void,
                 onDisconnect: @escaping (String) async -> Void) async throws {}
    func send(_ text: String) async throws { messages.append(text) }
    func setMicrophoneMuted(_ muted: Bool) async throws {}
    func disconnect() {}
}
