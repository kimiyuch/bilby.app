import Foundation

/// Builds a blind structure from the shape of the game.
///
/// Blinds grow geometrically from about 1/250 of the starting stack, so that by the target duration the
/// big blind is roughly 1/25 of all chips in play (heads-up with a dozen big blinds each). A few extra
/// levels follow in case the game runs long. Every blind is a round number and a multiple of the smallest
/// chip still in play; that chip is colored up at a break once it is no longer needed.
public struct StructureGenerator: Sendable {
    public struct Options: Equatable, Sendable {
        public var name: String
        public var startingStack: Int
        public var players: Int
        public var targetMinutes: Int
        public var levelMinutes: Int
        /// Chip denominations, any order.
        public var chips: [Int]
        public var breakEveryMinutes: Int
        public var breakMinutes: Int
        /// Nil for no antes.
        public var anteStyle: AnteStyle?
        public var extraLevels: Int

        public init(name: String = "Custom", startingStack: Int = 10_000, players: Int = 9, targetMinutes: Int = 240,
                    levelMinutes: Int = 20, chips: [Int] = [25, 100, 500, 1000, 5000], breakEveryMinutes: Int = 120,
                    breakMinutes: Int = 10, anteStyle: AnteStyle? = .bigBlind, extraLevels: Int = 4) {
            self.name = name
            self.startingStack = startingStack
            self.players = players
            self.targetMinutes = targetMinutes
            self.levelMinutes = levelMinutes
            self.chips = chips
            self.breakEveryMinutes = breakEveryMinutes
            self.breakMinutes = breakMinutes
            self.anteStyle = anteStyle
            self.extraLevels = extraLevels
        }
    }

    public var options: Options

    public init(_ options: Options) {
        self.options = options
    }

    public func makeStructure() -> Structure {
        let o = options
        let chips = Array(Set(o.chips.filter { $0 > 0 })).sorted()
        let denominations = chips.isEmpty ? [25] : chips
        let levelMinutes = max(1, o.levelMinutes)
        let breakEvery = o.breakEveryMinutes > 0 && o.breakMinutes > 0 ? o.breakEveryMinutes : Int.max
        let stack = max(1, o.startingStack)
        let totalChips = Double(stack) * Double(max(2, o.players))

        // Count the levels that fit into the target, breaks included.
        var levelsInTarget = 0
        var time = 0, sinceBreak = 0
        while time < o.targetMinutes || levelsInTarget < 3 {
            levelsInTarget += 1
            time += levelMinutes
            sinceBreak += levelMinutes
            if sinceBreak >= breakEvery, time < o.targetMinutes {
                time += o.breakMinutes
                sinceBreak = 0
            }
        }

        let startTarget = Double(stack) / 250
        let finalTarget = totalChips / 25
        let ratio = min(2.0, max(1.15, pow(max(finalTarget / startTarget, 1), 1 / Double(max(1, levelsInTarget - 1)))))
        let anteFrom = levelsInTarget / 3 + 1

        var rounds: [Round] = []
        var smallestChip = 0  // index into denominations
        var previousBB = 0
        sinceBreak = 0
        for level in 1...(levelsInTarget + max(0, o.extraLevels)) {
            let target = startTarget * pow(ratio, Double(level - 1))

            if sinceBreak >= breakEvery {
                // Retire chips that are now tiny next to the blinds.
                var retired: [Int] = []
                while smallestChip + 1 < denominations.count, Double(denominations[smallestChip + 1] * 5) <= target {
                    retired.append(denominations[smallestChip])
                    smallestChip += 1
                }
                rounds.append(.pause(minutes: o.breakMinutes, note: Self.colorUpNote(retired)))
                sinceBreak = 0
            }

            let chip = denominations[smallestChip]
            let bb = Self.niceBlind(near: target, above: previousBB, unit: chip * 2)
            previousBB = bb
            var ante = 0
            if let style = o.anteStyle, level >= anteFrom {
                switch style {
                case .bigBlind: ante = bb
                case .everyone: ante = max(chip, Int((Double(bb) / 8 / Double(chip)).rounded()) * chip)
                }
            }
            rounds.append(.level(bb / 2, bb, ante: ante, style: o.anteStyle ?? .bigBlind, minutes: levelMinutes))
            sinceBreak += levelMinutes
        }
        return Structure(name: o.name, rounds: rounds)
    }

    /// Round amounts a dealer would expect: 1, 1.2, 1.5, 2, 2.5, 3, 4, 5, 6 or 8 times a power of ten.
    static let mantissas: [Double] = [1, 1.2, 1.5, 2, 2.5, 3, 4, 5, 6, 8]

    /// The round amount closest to `target` that is above `previous` and a multiple of `unit`.
    static func niceBlind(near target: Double, above previous: Int, unit: Int) -> Int {
        var candidates: [Int] = []
        var power = 1.0
        while candidates.count < 4 || Double(candidates.last!) < target * 2 {
            for m in mantissas {
                let value = m * power
                guard value == value.rounded() else { continue }
                let v = Int(value)
                if v > previous, v % unit == 0 { candidates.append(v) }
            }
            power *= 10
            if power > 1e15 { break }
        }
        if candidates.isEmpty { return max(previous + unit, unit) }
        return candidates.min { abs(log(Double($0) / target)) < abs(log(Double($1) / target)) }!
    }

    static func colorUpNote(_ chips: [Int]) -> String {
        guard !chips.isEmpty else { return "" }
        let names = chips.map { "\($0)s" }
        let list = names.count == 1 ? names[0] : names.dropLast().joined(separator: ", ") + " and " + names.last!
        return "Color up the \(list)"
    }
}
