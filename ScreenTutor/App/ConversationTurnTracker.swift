struct ConversationTurnTracker: Sendable {
    private(set) var current = 0

    mutating func advance() -> Int {
        current &+= 1
        return current
    }

    func isCurrent(_ turn: Int) -> Bool {
        turn == current
    }
}
