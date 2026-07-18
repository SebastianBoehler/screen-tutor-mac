import SwiftUI

struct HUDView: View {
    let model: AppModel

    private var statusTitle: String {
        model.errorMessage == nil ? model.phase.title : "Needs attention"
    }

    private var statusSymbolName: String {
        model.errorMessage == nil ? model.phase.symbolName : "exclamationmark.triangle.fill"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusSymbolName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(model.errorMessage == nil ? Color.accentColor : Color.red)
                .frame(width: 34, height: 34)
                .background(.primary.opacity(0.08), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(statusTitle)
                    .font(.headline)
                    .lineLimit(1)
                Text(model.statusDetail)
                    .font(.caption)
                    .foregroundStyle(model.errorMessage == nil ? Color.secondary : Color.red)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 360, height: 76)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.12))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("ScreenTutor \(statusTitle). \(model.statusDetail)")
    }
}
