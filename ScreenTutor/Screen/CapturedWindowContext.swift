import CoreGraphics

struct CapturedWindowContext: Equatable, Sendable {
    let windowID: CGWindowID
    let processID: pid_t
    let capturedFrame: CGRect

    func revalidatedFrame(currentFrame: CGRect) throws -> CGRect {
        let sizeTolerance = 0.5
        guard
            abs(currentFrame.width - capturedFrame.width) <= sizeTolerance,
            abs(currentFrame.height - capturedFrame.height) <= sizeTolerance
        else {
            throw ScreenCaptureError.windowGeometryChanged
        }
        return currentFrame
    }
}
