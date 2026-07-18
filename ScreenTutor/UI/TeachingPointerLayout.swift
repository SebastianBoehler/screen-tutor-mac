import CoreGraphics

struct TeachingPointerLayout: Equatable, Sendable {
    let localHighlightFrame: CGRect
    let startPoint: CGPoint
    let targetPoint: CGPoint

    init(
        globalHighlightFrame: CGRect,
        screenFrame: CGRect,
        mouseLocation: CGPoint,
        previousTarget: CGPoint?
    ) {
        localHighlightFrame = Self.localFrame(
            for: globalHighlightFrame,
            in: screenFrame
        )
        targetPoint = CGPoint(
            x: localHighlightFrame.midX,
            y: localHighlightFrame.midY
        )

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

    private static func localFrame(for frame: CGRect, in screenFrame: CGRect) -> CGRect {
        CGRect(
            x: frame.minX - screenFrame.minX,
            y: screenFrame.maxY - frame.maxY,
            width: frame.width,
            height: frame.height
        )
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
