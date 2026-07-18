import Foundation

struct PlaybackCutoff: Equatable, Sendable {
    let itemID: String
    let audioEndMilliseconds: Int
}
