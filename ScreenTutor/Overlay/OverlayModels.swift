import CoreGraphics
import Foundation

/// One teaching mark drawn over the learner's screen.
enum OverlayMarkKind: String, Sendable, CaseIterable {
    case box, circle, underline, arrow, spotlight, note
}

enum OverlayColor: String, Sendable, CaseIterable {
    case yellow, blue, green, red, purple
}

struct OverlayMark: Identifiable, Sendable, Equatable {
    let id: UUID
    var kind: OverlayMarkKind
    /// Target in CoreGraphics global coordinates (points, top-left origin).
    var rect: CGRect
    var label: String?
    var color: OverlayColor
    /// Seconds after the scene starts, so marks appear in speaking order.
    var delay: Double
    /// A real native target, resolved locally while this scene remains visible.
    var anchor: NativeOverlayAnchor?

    init(
        id: UUID = UUID(),
        kind: OverlayMarkKind,
        rect: CGRect,
        label: String? = nil,
        color: OverlayColor = .yellow,
        delay: Double = 0,
        anchor: NativeOverlayAnchor? = nil
    ) {
        self.id = id
        self.kind = kind
        self.rect = rect
        self.label = label
        self.color = color
        self.delay = delay
        self.anchor = anchor
    }
}

struct OverlayScene: Sendable, Equatable {
    var marks: [OverlayMark]
    /// How long the scene stays before fading out.
    var duration: Double
}

/// Placement math shared by the overlay views and their tests. All rects use a
/// top-left origin in the display's local coordinates.
enum OverlayLayout {
    static let labelFontSize: CGFloat = 16
    static let maximumLabelWidth: CGFloat = 320

    /// Estimated bubble size for a label (rounded semibold, 16 pt, 12/7 padding).
    static func labelSize(for text: String) -> CGSize {
        let textWidth = CGFloat(text.count) * 8.4
        let lines = max(1, Int(ceil(textWidth / (maximumLabelWidth - 24))))
        return CGSize(width: min(maximumLabelWidth, textWidth + 26), height: CGFloat(lines) * 21 + 14)
    }

    /// Places every label so it does not cover any mark's target or another
    /// label: above, below, right, left; arrows put their label further away.
    static func placeLabels(for marks: [OverlayMark], in bounds: CGRect) -> [UUID: CGRect] {
        let usable = bounds.insetBy(dx: 6, dy: 6)
        var obstacles = marks.filter { $0.kind != .spotlight }.map { $0.rect.insetBy(dx: -8, dy: -6) }
        var placed: [UUID: CGRect] = [:]
        for mark in marks where mark.kind != .spotlight {
            guard let text = mark.label, !text.isEmpty else { continue }
            let size = labelSize(for: text)
            let gap: CGFloat = mark.kind == .arrow ? 70 : 12
            let target = mark.kind == .circle ? mark.rect.insetBy(dx: -14, dy: -12) : mark.rect
            // Rings of candidate spots, moving further out until one is free.
            let candidates = [1.0, 2.5, 4.5].flatMap { ring -> [CGPoint] in
                let g = gap * ring + (ring > 1 ? size.height : 0)
                return [
                    CGPoint(x: target.midX - size.width / 2, y: target.minY - g - size.height),
                    CGPoint(x: target.midX - size.width / 2, y: target.maxY + g),
                    CGPoint(x: target.maxX + g, y: target.midY - size.height / 2),
                    CGPoint(x: target.minX - g - size.width, y: target.midY - size.height / 2),
                    CGPoint(x: target.maxX + g * 0.7, y: target.minY - g * 0.7 - size.height),
                    CGPoint(x: target.minX - g * 0.7 - size.width, y: target.maxY + g * 0.7)
                ]
            }.map { origin in
                // Keep inside the display.
                CGRect(
                    x: min(max(origin.x, usable.minX), usable.maxX - size.width),
                    y: min(max(origin.y, usable.minY), usable.maxY - size.height),
                    width: size.width,
                    height: size.height
                )
            }
            func overlap(_ rect: CGRect) -> CGFloat {
                obstacles.reduce(0) { total, other in
                    let common = rect.intersection(other)
                    return total + (common.isNull ? 0 : common.width * common.height)
                }
            }
            let best = candidates.first { overlap($0) == 0 } ?? candidates.min { overlap($0) < overlap($1) }!
            placed[mark.id] = best
            obstacles.append(best.insetBy(dx: -4, dy: -4))
        }
        return placed
    }

    /// Arrow from the label (or open space) to the nearest edge of the target.
    static func arrow(from label: CGRect?, to target: CGRect, in bounds: CGRect) -> (tail: CGPoint, head: CGPoint) {
        let padded = target.insetBy(dx: -6, dy: -6)
        let origin = label.map { CGPoint(x: $0.midX, y: $0.midY) }
            ?? CGPoint(x: target.minX - 100, y: target.minY - 70)
        let head = nearestPoint(on: padded, to: origin)
        let tail = label.map { nearestPoint(on: $0.insetBy(dx: -4, dy: -4), to: head) } ?? CGPoint(
            x: min(max(origin.x, bounds.minX + 8), bounds.maxX - 8),
            y: min(max(origin.y, bounds.minY + 8), bounds.maxY - 8)
        )
        return (tail, head)
    }

    static func nearestPoint(on rect: CGRect, to point: CGPoint) -> CGPoint {
        let x = min(max(point.x, rect.minX), rect.maxX)
        let y = min(max(point.y, rect.minY), rect.maxY)
        guard rect.contains(point) else { return CGPoint(x: x, y: y) }
        // Inside: project to the closest edge.
        let distances = [point.x - rect.minX, rect.maxX - point.x, point.y - rect.minY, rect.maxY - point.y]
        switch distances.firstIndex(of: distances.min()!)! {
        case 0: return CGPoint(x: rect.minX, y: point.y)
        case 1: return CGPoint(x: rect.maxX, y: point.y)
        case 2: return CGPoint(x: point.x, y: rect.minY)
        default: return CGPoint(x: point.x, y: rect.maxY)
        }
    }
}
