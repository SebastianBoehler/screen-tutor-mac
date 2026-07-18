import SwiftUI

struct TeachingTargetView: View {
    let frame: CGRect
    let label: String
    let containerSize: CGSize
    let reduceTransparency: Bool
    let hasArrived: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.black.opacity(0.85), lineWidth: 8)
                .frame(width: max(frame.width, 36), height: max(frame.height, 30))
                .position(x: frame.midX, y: frame.midY)

            RoundedRectangle(cornerRadius: 12)
                .fill(.yellow.opacity(reduceTransparency ? 0.2 : 0.12))
                .stroke(.yellow, lineWidth: 4)
                .shadow(color: .yellow.opacity(0.8), radius: 14)
                .frame(width: max(frame.width, 36), height: max(frame.height, 30))
                .position(x: frame.midX, y: frame.midY)

            Label(label, systemImage: "scope")
                .font(.callout.bold())
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.regularMaterial, in: Capsule())
                .background {
                    Capsule()
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .opacity(reduceTransparency ? 1 : 0)
                }
                .overlay {
                    Capsule().stroke(.black.opacity(0.9), lineWidth: 4)
                }
                .overlay {
                    Capsule().stroke(.yellow, lineWidth: 2)
                }
                .position(
                    x: min(max(frame.midX, 110), max(containerSize.width - 110, 110)),
                    y: frame.minY >= 52
                        ? frame.minY - 26
                        : min(frame.maxY + 26, containerSize.height - 22)
                )
        }
        .scaleEffect(hasArrived ? 1 : 0.97)
    }
}
