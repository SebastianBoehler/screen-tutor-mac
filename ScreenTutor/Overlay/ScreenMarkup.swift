import CoreGraphics
import CoreText
import Foundation

/// Draws reference marks on the model's copy of a screenshot (never on the
/// learner's screen): a faint 0–1000 grid with labelled lines, and small id
/// tags on recognized elements ("set-of-marks"). They give the model anchors
/// to read coordinates from instead of estimating raw pixels.
enum ScreenMarkup {
    struct Options: Sendable {
        var grid = true
        var tags = true
        var gridStep = 100
        var maximumTags = 70
    }

    nonisolated static func render(
        _ source: CGImage,
        elements: [ScreenElement],
        displayFrame: CGRect,
        maximumDimension: Int,
        options: Options = Options()
    ) -> CGImage? {
        let scale = min(1, CGFloat(maximumDimension) / CGFloat(max(source.width, source.height)))
        let width = max(1, Int(CGFloat(source.width) * scale))
        let height = max(1, Int(CGFloat(source.height) * scale))
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        let size = CGSize(width: width, height: height)

        if options.grid { drawGrid(in: context, size: size, step: options.gridStep) }
        if options.tags { drawTags(in: context, size: size, elements: elements, displayFrame: displayFrame, limit: options.maximumTags) }
        return context.makeImage()
    }

    /// 0–1000 units → image pixels; the context has a bottom-left origin.
    private static func point(_ x: CGFloat, _ y: CGFloat, _ size: CGSize) -> CGPoint {
        CGPoint(x: x / 1000 * size.width, y: size.height - y / 1000 * size.height)
    }

    private static func drawGrid(in context: CGContext, size: CGSize, step: Int) {
        let color = CGColor(red: 1, green: 0.15, blue: 0.75, alpha: 0.45)
        context.setLineWidth(1)
        for value in stride(from: step, to: 1000, by: step) {
            let v = CGFloat(value)
            let major = value % (step * 5) == 0
            context.setStrokeColor(major ? color : color.copy(alpha: 0.28)!)
            context.setLineDash(phase: 0, lengths: major ? [] : [4, 4])
            context.move(to: point(v, 0, size)); context.addLine(to: point(v, 1000, size))
            context.move(to: point(0, v, size)); context.addLine(to: point(1000, v, size))
            context.strokePath()
        }
        context.setLineDash(phase: 0, lengths: [])
        for value in stride(from: step, to: 1000, by: step) {
            let v = CGFloat(value)
            label("\(value)", at: point(v, 0, size), in: context, anchor: .top)
            label("\(value)", at: point(0, v, size), in: context, anchor: .left)
        }
    }

    private static func drawTags(
        in context: CGContext,
        size: CGSize,
        elements: [ScreenElement],
        displayFrame: CGRect,
        limit: Int
    ) {
        var taken: [CGRect] = []
        for element in elements.prefix(limit * 2) where taken.count < limit {
            let x = (element.rect.minX - displayFrame.minX) / displayFrame.width * 1000
            let y = (element.rect.minY - displayFrame.minY) / displayFrame.height * 1000
            let anchor = point(x, y, size)
            let box = CGRect(x: anchor.x - 1, y: anchor.y, width: CGFloat(element.id.count) * 6.5 + 4, height: 11)
            if taken.contains(where: { $0.intersects(box) }) { continue }
            taken.append(box)
            label(element.id, at: anchor, in: context, anchor: .tag)
        }
    }

    private enum Anchor { case top, left, tag }

    private static func label(_ text: String, at point: CGPoint, in context: CGContext, anchor: Anchor) {
        let fontSize: CGFloat = anchor == .tag ? 9 : 10
        let font = CTFontCreateWithName("Menlo-Bold" as CFString, fontSize, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        let width = CTLineGetTypographicBounds(line, nil, nil, nil)
        let box: CGRect
        switch anchor {
        case .top: box = CGRect(x: point.x - width / 2 - 2, y: point.y - fontSize - 3, width: width + 4, height: fontSize + 3)
        case .left: box = CGRect(x: point.x + 1, y: point.y - (fontSize + 3) / 2, width: width + 4, height: fontSize + 3)
        case .tag: box = CGRect(x: point.x - 1, y: point.y, width: width + 4, height: fontSize + 2)
        }
        let fill = anchor == .tag
            ? CGColor(red: 0.1, green: 0.35, blue: 0.95, alpha: 0.85)
            : CGColor(red: 0.85, green: 0.1, blue: 0.6, alpha: 0.85)
        context.setFillColor(fill)
        context.fill(box)
        context.textPosition = CGPoint(x: box.minX + 2, y: box.minY + 2.5)
        CTLineDraw(line, context)
    }
}
