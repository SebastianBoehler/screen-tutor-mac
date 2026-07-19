struct ConversationTurnTracker: Sendable {
    private(set) var current: Int

    init(initialTurn: Int = 0) {
        current = initialTurn
    }

    mutating func advance() -> Int {
        current &+= 1
        return current
    }

    func isCurrent(_ turn: Int) -> Bool {
        turn == current
    }
}
