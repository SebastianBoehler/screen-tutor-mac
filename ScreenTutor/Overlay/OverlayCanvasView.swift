import SwiftUI

/// Draws one display's share of an overlay scene. Rects are local to the
/// display (top-left origin). Each mark draws itself in after its delay.
struct OverlayCanvasView: View {
    let marks: [OverlayMark]
    let bounds: CGRect
    /// False renders the final state at once (snapshots and tests).
    var animated = true

    var body: some View {
        let labels = OverlayLayout.placeLabels(for: marks, in: bounds)
        ZStack(alignment: .topLeading) {
            if let spotlight = marks.first(where: { $0.kind == .spotlight }) {
                SpotlightView(mark: spotlight, bounds: bounds, animated: animated)
            }
            ForEach(marks) { mark in
                OverlayMarkView(mark: mark, label: labels[mark.id], bounds: bounds, animated: animated)
            }
        }
        .frame(width: bounds.width, height: bounds.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}

extension OverlayColor {
    var swiftUIColor: Color {
        switch self {
        case .yellow: Color(red: 1.0, green: 0.78, blue: 0.12)
        case .blue: Color(red: 0.25, green: 0.55, blue: 1.0)
        case .green: Color(red: 0.2, green: 0.8, blue: 0.4)
        case .red: Color(red: 1.0, green: 0.3, blue: 0.3)
        case .purple: Color(red: 0.7, green: 0.4, blue: 1.0)
        }
    }
}

private struct OverlayMarkView: View {
    let mark: OverlayMark
    let label: CGRect?
    let bounds: CGRect
    @State private var progress: CGFloat

    init(mark: OverlayMark, label: CGRect?, bounds: CGRect, animated: Bool) {
        self.mark = mark
        self.label = label
        self.bounds = bounds
        _progress = State(initialValue: animated ? 0 : 1)
    }

    private var color: Color { mark.color.swiftUIColor }

    var body: some View {
        ZStack(alignment: .topLeading) {
            shape
            if let text = mark.label, let label {
                LabelBubble(text: text, color: color, rect: label)
                    .opacity(progress)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(mark.delay)) { progress = 1 }
        }
    }

    private var arrow: (tail: CGPoint, head: CGPoint) {
        OverlayLayout.arrow(from: label, to: mark.rect, in: bounds)
    }

    @ViewBuilder
    private var shape: some View {
        switch mark.kind {
        case .box:
            let rect = mark.rect.insetBy(dx: -6, dy: -5)
            RoundedRectangle(cornerRadius: 7)
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .background(RoundedRectangle(cornerRadius: 7).fill(color.opacity(0.12 * progress)))
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
                .shadow(color: .black.opacity(0.35), radius: 3)
        case .circle:
            let rect = mark.rect.insetBy(dx: -max(14, mark.rect.width * 0.12), dy: -max(12, mark.rect.height * 0.3))
            Ellipse()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: rect.width, height: rect.height)
                .rotationEffect(.degrees(-90))
                .offset(x: rect.minX, y: rect.minY)
                .shadow(color: .black.opacity(0.35), radius: 3)
        case .underline:
            Path { path in
                let y = mark.rect.maxY + 4
                path.move(to: CGPoint(x: mark.rect.minX - 2, y: y + 1))
                path.addQuadCurve(
                    to: CGPoint(x: mark.rect.maxX + 2, y: y),
                    control: CGPoint(x: mark.rect.midX, y: y + 5)
                )
            }
            .trim(from: 0, to: progress)
            .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .shadow(color: .black.opacity(0.35), radius: 2)
        case .arrow:
            let (tail, head) = arrow
            ArrowShape(tail: tail, head: head)
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
                .shadow(color: .black.opacity(0.35), radius: 3)
        case .spotlight:
            EmptyView()
        case .note:
            EmptyView()
        }
    }
}

private struct ArrowShape: Shape {
    let tail: CGPoint
    let head: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let mid = CGPoint(x: (tail.x + head.x) / 2, y: (tail.y + head.y) / 2)
        let length = max(hypot(head.x - tail.x, head.y - tail.y), 1)
        // Bow the line a little to one side, like a hand-drawn arrow.
        let control = CGPoint(
            x: mid.x - (head.y - tail.y) / length * length * 0.18,
            y: mid.y + (head.x - tail.x) / length * length * 0.18
        )
        path.move(to: tail)
        path.addQuadCurve(to: head, control: control)
        let angle = atan2(head.y - control.y, head.x - control.x)
        for side in [-1.0, 1.0] {
            let wing = angle + .pi + side * .pi / 7
            path.move(to: head)
            path.addLine(to: CGPoint(x: head.x + cos(wing) * 18, y: head.y + sin(wing) * 18))
        }
        return path
    }
}

private struct LabelBubble: View {
    let text: String
    let color: Color
    let rect: CGRect

    var body: some View {
        Text(text)
            .font(.system(size: OverlayLayout.labelFontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(.black)
            .lineLimit(3)
            .minimumScaleFactor(0.75)
            .multilineTextAlignment(.center)
            .frame(width: rect.width, height: rect.height)
            .background(RoundedRectangle(cornerRadius: 10).fill(color))
            .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
            .offset(x: rect.minX, y: rect.minY)
    }
}

private struct SpotlightView: View {
    let mark: OverlayMark
    let bounds: CGRect
    @State private var opacity: Double

    init(mark: OverlayMark, bounds: CGRect, animated: Bool) {
        self.mark = mark
        self.bounds = bounds
        _opacity = State(initialValue: animated ? 0 : 1)
    }

    var body: some View {
        Canvas { context, size in
            var path = Path(CGRect(origin: .zero, size: size))
            path.addRoundedRect(in: mark.rect.insetBy(dx: -14, dy: -12), cornerSize: CGSize(width: 14, height: 14))
            context.fill(path, with: .color(.black.opacity(0.55)), style: FillStyle(eoFill: true))
        }
        .frame(width: bounds.width, height: bounds.height)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(mark.delay)) { opacity = 1 }
        }
    }
}
