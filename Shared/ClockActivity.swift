#if os(iOS)
import ActivityKit
import Foundation

/// What the Lock Screen and Dynamic Island show. Shared by the app and the widget extension.
nonisolated struct ClockActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// "Level 6" or "Break".
        var title: String
        /// "150 / 300", or the break's note.
        var detail: String
        var ante: String?
        var isBreak: Bool
        var isRunning: Bool
        /// When the current round began and ends, for the countdown and progress bar.
        var roundStart: Date
        var endsAt: Date
        /// Time left while paused.
        var remaining: TimeInterval
        /// The round after this one, shown once the current round has run out and the app hasn't updated yet.
        var nextTitle: String?
        var nextDetail: String?
        var nextEndsAt: Date?
    }

    var structureName: String
}
#endif
