import SwiftUI

struct TutorCursorView: View {
    let hasArrived: Bool
    let differentiateWithoutColor: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(.blue)
                .frame(width: 18, height: 18)
                .overlay { Circle().stroke(.white, lineWidth: 3) }
                .shadow(color: .black.opacity(0.35), radius: 3)

            Circle()
                .stroke(.blue.opacity(0.75), lineWidth: 3)
                .frame(width: 36, height: 36)
                .scaleEffect(hasArrived ? 1 : 0.55)

            Image(systemName: "cursorarrow")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black, radius: 0, x: 2, y: 2)
                .shadow(color: .black.opacity(0.65), radius: 3)
                .offset(x: 14, y: 15)
                .accessibilityHidden(true)
        }
        .overlay {
            Circle()
                .stroke(
                    differentiateWithoutColor ? Color.primary : Color.blue,
                    style: StrokeStyle(lineWidth: 2, dash: [5, 4])
                )
                .frame(width: 48, height: 48)
                .scaleEffect(hasArrived ? 1 : 0.7)
                .opacity(hasArrived ? 0.28 : 0)
        }
        .frame(width: 52, height: 52)
    }
}
