import Foundation

@MainActor
final class ListeningIdleTimer {
    typealias Cancellation = @MainActor () -> Void
    typealias Scheduler = @MainActor (
        _ timeout: Duration,
        _ action: @escaping @MainActor () -> Void
    ) -> Cancellation

    static let defaultTimeout: Duration = .seconds(20)

    let timeout: Duration
    private(set) var isArmed = false

    private let scheduler: Scheduler
    private var cancellation: Cancellation?
    private var generation = 0

    init(
        timeout: Duration = defaultTimeout,
        scheduler: @escaping Scheduler = ListeningIdleTimer.schedule
    ) {
        self.timeout = timeout
        self.scheduler = scheduler
    }

    func arm(onTimeout: @escaping @MainActor () -> Void) {
        cancel()
        let scheduledGeneration = generation
        let cancellation = scheduler(timeout) { [weak self] in
            guard let self, generation == scheduledGeneration else { return }
            self.cancellation = nil
            isArmed = false
            generation &+= 1
            onTimeout()
        }

        guard generation == scheduledGeneration else {
            cancellation()
            return
        }
        self.cancellation = cancellation
        isArmed = true
    }

    func cancel() {
        generation &+= 1
        isArmed = false
        let cancellation = self.cancellation
        self.cancellation = nil
        cancellation?()
    }

    private static func schedule(
        timeout: Duration,
        action: @escaping @MainActor () -> Void
    ) -> Cancellation {
        let task = Task { @MainActor in
            do {
                try await Task.sleep(for: timeout)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            action()
        }
        return { task.cancel() }
    }
}
