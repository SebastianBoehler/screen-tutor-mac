import Foundation

struct CameraSnapshot: Sendable {
    let jpegData: Data
    let deviceName: String
}
