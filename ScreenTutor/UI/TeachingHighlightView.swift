import SwiftUI

struct TeachingHighlightView: View {
    let frame: CGRect
    let label: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.accentColor.opacity(0.09))
                    )
                    .shadow(color: Color.accentColor.opacity(0.55), radius: 10)
                    .frame(width: max(frame.width, 28), height: max(frame.height, 24))
                    .position(x: frame.midX, y: frame.midY)

                Label(label, systemImage: "cursorarrow.rays")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .overlay { Capsule().strokeBorder(Color.accentColor.opacity(0.45)) }
                    .position(
                        x: min(max(frame.midX, 90), proxy.size.width - 90),
                        y: max(frame.minY - 20, 18)
                    )
            }
        }
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible || reduceMotion ? 1 : 0.96)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82)) {
                isVisible = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Highlighted: \(label)")
    }
}
