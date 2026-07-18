import Foundation

struct ActiveWindowSnapshot: Sendable {
    let jpegData: Data
    let applicationName: String
    let windowTitle: String?
    let windowFrame: CGRect
}
