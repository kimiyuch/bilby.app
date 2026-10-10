import Foundation

/// What the clock says out loud. Numbers stay plain digits, which speech synthesizers read well.
public enum Announcement {
    public static func roundStarted(_ index: Int, in structure: Structure) -> String {
        guard structure.rounds.indices.contains(index) else { return "" }
        let round = structure.rounds[index]
        if round.isBreak {
            var text = "Break. \(minutes(round.minutes))."
            if !round.note.isEmpty { text += " " + sentence(round.note) }
            return text
        }
        return "Level \(structure.levelNumber(at: index) ?? 0). \(blinds(round))."
    }

    public static func blinds(_ round: Round) -> String {
        var text = "Blinds \(round.smallBlind), \(round.bigBlind)"
        if round.ante > 0 { text += ", ante \(round.ante)" }
        return text
    }

    public static func warning(_ round: Round, remaining: TimeInterval) -> String {
        let seconds = Int(remaining.rounded())
        let left = seconds < 60 ? "\(seconds) seconds" : minutes(Int((remaining / 60).rounded()))
        return round.isBreak ? "\(left) left in the break." : "\(left) left in this level."
    }

    public static let finished = "That was the last level."

    static func minutes(_ n: Int) -> String {
        switch n {
        case 1: "One minute"
        default: "\(n) minutes"
        }
    }

    static func sentence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else { return "" }
        return ".!?".contains(last) ? trimmed : trimmed + "."
    }
}
