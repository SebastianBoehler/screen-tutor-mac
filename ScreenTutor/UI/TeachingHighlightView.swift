import SwiftUI

struct TeachingHighlightView: View {
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
                TeachingTargetView(
                    frame: layout.localHighlightFrame,
                    label: label,
                    containerSize: proxy.size,
                    reduceTransparency: reduceTransparency,
                    hasArrived: hasArrived
                )

                TutorCursorView(
                    hasArrived: hasArrived,
                    differentiateWithoutColor: differentiateWithoutColor
                )
                .position(pointerPosition)
            }
        }
        .opacity(isVisible ? 1 : 0)
        .onAppear(perform: present)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tutor pointing to \(label)")
    }

    private func present() {
        if reduceMotion {
            pointerPosition = layout.targetPoint
            hasArrived = true
            withAnimation(.easeOut(duration: 0.18)) {
                isVisible = true
            }
            return
        }

        isVisible = true
        withAnimation(.easeInOut(duration: 0.58)) {
            pointerPosition = layout.targetPoint
        } completion: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) {
                hasArrived = true
            }
        }
    }
}
