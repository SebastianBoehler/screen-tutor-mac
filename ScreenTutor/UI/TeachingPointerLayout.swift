import CoreGraphics

struct TeachingPointerLayout: Equatable, Sendable {
    let startPoint: CGPoint
    let targetPoint: CGPoint

    init(
        globalTarget: CGPoint,
        screenFrame: CGRect,
        mouseLocation: CGPoint,
        previousTarget: CGPoint?
    ) {
        targetPoint = Self.localPoint(for: globalTarget, in: screenFrame)

        let globalStart: CGPoint
        if let previousTarget, screenFrame.contains(previousTarget) {
            globalStart = previousTarget
        } else if screenFrame.contains(mouseLocation) {
            globalStart = mouseLocation
        } else {
            globalStart = Self.clamped(mouseLocation, to: screenFrame)
        }
        startPoint = Self.localPoint(for: globalStart, in: screenFrame)
    }

    private static func localPoint(for point: CGPoint, in screenFrame: CGRect) -> CGPoint {
        CGPoint(
            x: point.x - screenFrame.minX,
            y: screenFrame.maxY - point.y
        )
    }

    private static func clamped(_ point: CGPoint, to frame: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, frame.minX), frame.maxX),
            y: min(max(point.y, frame.minY), frame.maxY)
        )
    }
}
