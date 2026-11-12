import CoreGraphics
import Foundation

/// A tiny grayscale thumbnail used for local, on-device change detection.
/// Comparing two fingerprints returns the fraction of cells whose brightness
/// changed noticeably: new handwriting moves a few cells, a hand moves many.
struct DeskFrameFingerprint: Equatable, Sendable {
    static let width = 64
    static let height = 48

    let pixels: [UInt8]

    init(pixels: [UInt8]) {
        self.pixels = pixels
    }

    init?(image: CGImage) {
        var buffer = [UInt8](repeating: 0, count: Self.width * Self.height)
        let drawn = buffer.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: Self.width,
                height: Self.height,
                bitsPerComponent: 8,
                bytesPerRow: Self.width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: Self.width, height: Self.height))
            return true
        }
        guard drawn else { return nil }
        pixels = buffer
    }

    /// Fraction (0...1) of cells whose brightness differs by more than `threshold`.
    func changedFraction(comparedTo other: DeskFrameFingerprint, threshold: UInt8 = 14) -> Double {
        guard pixels.count == other.pixels.count, !pixels.isEmpty else { return 1 }
        var changed = 0
        for index in pixels.indices {
            let a = Int(pixels[index])
            let b = Int(other.pixels[index])
            if abs(a - b) > Int(threshold) { changed += 1 }
        }
        return Double(changed) / Double(pixels.count)
    }
}

/// Decides when the desk deserves a fresh look from the observer model.
/// Pure value logic so it can be unit tested without a camera.
struct DeskChangeGate: Sendable {
    /// Cells changed between consecutive ticks that count as motion (a hand, the page moving).
    var motionThreshold = 0.02
    /// Cells changed since the last analysis that count as new work on the page.
    var materialThreshold = 0.006
    /// How long the image must be still before analysing (the hand moved away).
    var settleSeconds: TimeInterval = 1.5
    /// Minimum spacing between observer calls.
    var minimumInterval: TimeInterval = 4
    /// Silence on the page, with an active task, before asking whether the learner is stuck.
    var stallSeconds: TimeInterval = 90

    private(set) var previous: DeskFrameFingerprint?
    private(set) var analyzed: DeskFrameFingerprint?
    private(set) var lastMotion: Date?
    private(set) var lastMaterialChange: Date?
    private(set) var lastAnalysis: Date?
    private(set) var stallReported = false

    enum Decision: Equatable, Sendable {
        case wait
        case analyze(DeskAnalysisReason)
    }

    mutating func evaluate(
        _ fingerprint: DeskFrameFingerprint,
        at now: Date,
        hasActiveTask: Bool
    ) -> Decision {
        defer { previous = fingerprint }
        if let previous, fingerprint.changedFraction(comparedTo: previous) > motionThreshold {
            lastMotion = now
        }
        if lastMaterialChange == nil { lastMaterialChange = now }

        guard let analyzed else { return .analyze(.firstLook) }
        if let lastAnalysis, now.timeIntervalSince(lastAnalysis) < minimumInterval {
            return .wait
        }
        let settled = lastMotion.map { now.timeIntervalSince($0) >= settleSeconds } ?? true
        let material = fingerprint.changedFraction(comparedTo: analyzed) > materialThreshold
        if material {
            lastMaterialChange = now
            stallReported = false
            return settled ? .analyze(.pageChanged) : .wait
        }
        if
            hasActiveTask,
            !stallReported,
            let lastMaterialChange,
            now.timeIntervalSince(lastMaterialChange) >= stallSeconds
        {
            stallReported = true
            return .analyze(.noProgress)
        }
        return .wait
    }

    mutating func recordAnalysis(of fingerprint: DeskFrameFingerprint, at now: Date) {
        analyzed = fingerprint
        lastAnalysis = now
    }

    mutating func reset() {
        self = DeskChangeGate(
            motionThreshold: motionThreshold,
            materialThreshold: materialThreshold,
            settleSeconds: settleSeconds,
            minimumInterval: minimumInterval,
            stallSeconds: stallSeconds
        )
    }

    init(
        motionThreshold: Double = 0.02,
        materialThreshold: Double = 0.006,
        settleSeconds: TimeInterval = 1.5,
        minimumInterval: TimeInterval = 4,
        stallSeconds: TimeInterval = 90
    ) {
        self.motionThreshold = motionThreshold
        self.materialThreshold = materialThreshold
        self.settleSeconds = settleSeconds
        self.minimumInterval = minimumInterval
        self.stallSeconds = stallSeconds
    }
}

enum DeskAnalysisReason: String, Sendable {
    case firstLook = "first_look"
    case pageChanged = "page_changed"
    case noProgress = "no_visible_progress"
    case requested = "requested"
}
