import SwiftUI

struct TutorCursorView: View {
    let hasArrived: Bool
    let differentiateWithoutColor: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(.black.opacity(0.82), lineWidth: 7)
                .frame(width: 46, height: 46)

            Circle()
                .stroke(.yellow, lineWidth: 4)
                .frame(width: 46, height: 46)

            Circle()
                .fill(.white)
                .frame(width: 10, height: 10)
                .overlay {
                    Circle().stroke(.black, lineWidth: 2)
                }

            Image(systemName: "cursorarrow")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black, radius: 0, x: 3, y: 3)
                .shadow(color: .black.opacity(0.8), radius: 4)
                .offset(x: 18, y: 20)
                .accessibilityHidden(true)
        }
        .overlay {
            Circle()
                .stroke(
                    differentiateWithoutColor ? Color.white : Color.yellow,
                    style: StrokeStyle(lineWidth: 3, dash: [7, 5])
                )
                .frame(width: 72, height: 72)
                .scaleEffect(hasArrived ? 1 : 0.62)
                .opacity(hasArrived ? 0.3 : 0)
        }
        .shadow(color: .black.opacity(0.4), radius: 5)
    }
}
