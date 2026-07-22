import SwiftUI

struct TeachingPointerView: View {
    let layout: TeachingPointerLayout
    let label: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityDifferentiateWithoutColor)
    private var differentiateWithoutColor
    @State private var pointerPosition: CGPoint
    @State private var isVisible = false
    @State private var hasArrived = false

    init(layout: TeachingPointerLayout, label: String) {
        self.layout = layout
        self.label = label
        _pointerPosition = State(initialValue: layout.startPoint)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                TutorCursorView(
                    hasArrived: hasArrived,
                    differentiateWithoutColor: differentiateWithoutColor
                )
                .position(pointerPosition)

                Text(label)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        reduceTransparency ? AnyShapeStyle(.background) : AnyShapeStyle(.regularMaterial),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule().stroke(Color(nsColor: .separatorColor).opacity(0.55))
                    }
                    .position(labelPosition(in: proxy.size))
                    .opacity(hasArrived ? 1 : 0)
            }
        }
        .opacity(isVisible ? 1 : 0)
        .onAppear(perform: present)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tutor pointing to \(label)")
    }

    private func labelPosition(in size: CGSize) -> CGPoint {
        let halfWidth: CGFloat = 78
        let x = layout.targetPoint.x + halfWidth + 28 <= size.width
            ? layout.targetPoint.x + halfWidth + 24
            : layout.targetPoint.x - halfWidth - 24
        let y = layout.targetPoint.y >= 38
            ? layout.targetPoint.y - 25
            : layout.targetPoint.y + 38
        return CGPoint(
            x: min(max(x, halfWidth + 8), size.width - halfWidth - 8),
            y: min(max(y, 18), size.height - 18)
        )
    }

    private func present() {
        if reduceMotion {
            pointerPosition = layout.targetPoint
            hasArrived = true
            isVisible = true
            return
        }
        isVisible = true
        withAnimation(.easeInOut(duration: 0.46)) {
            pointerPosition = layout.targetPoint
        } completion: {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.68)) {
                hasArrived = true
            }
        }
    }
}
