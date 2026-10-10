import BilbyKit
import SwiftUI

/// The clock's colors. Always dark, calm during play, warm amber when a level is about to end, teal on a break.
struct ClockTheme: Equatable {
    var background: Color
    var accent: Color
    var primary: Color = Color(white: 0.96)
    var secondary: Color = Color(white: 0.62)
    var track: Color = Color(white: 1, opacity: 0.1)

    static let play = ClockTheme(background: Color(red: 0.063, green: 0.075, blue: 0.086),
                                 accent: Color(red: 0.62, green: 0.71, blue: 0.79))
    static let ending = ClockTheme(background: Color(red: 0.16, green: 0.105, blue: 0.035),
                                   accent: Color(red: 0.96, green: 0.68, blue: 0.27))
    static let pause = ClockTheme(background: Color(red: 0.035, green: 0.13, blue: 0.125),
                                  accent: Color(red: 0.39, green: 0.80, blue: 0.72))

    /// The poker chip petrol from the app icon, as on the website: the start/pause button.
    static let chip = Color(red: 0.184, green: 0.435, blue: 0.525)

    static func of(_ s: ClockSnapshot, warning: TimeInterval) -> ClockTheme {
        if s.isBreak { return .pause }
        if s.hasStarted, !s.isFinished, warning > 0, s.remaining <= warning { return .ending }
        return .play
    }
}

extension Int {
    /// Chip amounts with the locale's grouping, e.g. 1’500.
    var chips: String { formatted(.number) }

    /// Short chip amounts for tight spaces: 800, 1k, 1.5k, 11.1k, 100k, 1.2M. Rounds down, so 1,999 reads 1.9k.
    var compactChips: String {
        func short(_ value: Double, _ suffix: String) -> String {
            ((value * 10).rounded(.down) / 10).formatted(.number.precision(.fractionLength(0...1))) + suffix
        }
        if abs(self) >= 1_000_000 { return short(Double(self) / 1_000_000, "M") }
        if abs(self) >= 1_000 { return short(Double(self) / 1_000, "k") }
        return formatted(.number)
    }
}

extension Round {
    var blindsText: String { "\(smallBlind.chips) / \(bigBlind.chips)" }

    var anteText: String? {
        guard ante > 0 else { return nil }
        return anteStyle == .bigBlind ? "Big blind ante \(ante.chips)" : "Ante \(ante.chips)"
    }

    /// "200 / 400 · 400", for one-line summaries.
    var shortText: String {
        ante > 0 ? "\(blindsText) · \(ante.chips)" : blindsText
    }

    /// "200 / 400 · 400" with short amounts: "1k / 2k · 2k".
    var compactText: String {
        let blinds = "\(smallBlind.compactChips) / \(bigBlind.compactChips)"
        return ante > 0 ? "\(blinds) · \(ante.compactChips)" : blinds
    }
}
