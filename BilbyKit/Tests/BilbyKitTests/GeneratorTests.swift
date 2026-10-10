import Foundation
import Testing
@testable import BilbyKit

@Suite struct GeneratorTests {
    static let shapes: [StructureGenerator.Options] = [
        .init(),
        .init(startingStack: 10_000, players: 6, targetMinutes: 120, levelMinutes: 10),
        .init(startingStack: 25_000, players: 20, targetMinutes: 360, levelMinutes: 30, chips: [25, 100, 500, 1000, 5000]),
        .init(startingStack: 1500, players: 8, targetMinutes: 180, levelMinutes: 15, chips: [5, 25, 100, 500]),
        .init(startingStack: 200, players: 4, targetMinutes: 90, levelMinutes: 15, chips: [1, 5, 25], anteStyle: .everyone),
        .init(startingStack: 50_000, players: 40, targetMinutes: 480, levelMinutes: 40, chips: [100, 500, 1000, 5000, 25000]),
    ]

    @Test(arguments: shapes) func blindsAreRoundAndPlayableWithTheChipsInPlay(_ options: StructureGenerator.Options) {
        let structure = StructureGenerator(options).makeStructure()
        let chips = options.chips.sorted()
        var smallest = chips[0]
        var previousBB = 0
        for round in structure.rounds {
            if round.isBreak {
                // A color-up removes the smallest chips.
                if let range = round.note.range(of: "Color up the ") {
                    let names = round.note[range.upperBound...]
                        .replacingOccurrences(of: " and ", with: ", ").split(separator: ", ")
                    let retired = names.compactMap { Int($0.dropLast()) }
                    #expect(retired.first == smallest)
                    smallest = chips.first { $0 > retired.max()! }!
                }
                continue
            }
            #expect(round.minutes == options.levelMinutes)
            #expect(round.bigBlind > previousBB, "blinds go up")
            #expect(round.smallBlind * 2 == round.bigBlind)
            #expect(round.smallBlind % smallest == 0, "\(round.smallBlind) can be paid with \(smallest)s")
            #expect(round.ante % smallest == 0)
            #expect(StructureGenerator.mantissas.contains(mantissa(round.bigBlind)), "\(round.bigBlind) is a round number")
            previousBB = round.bigBlind
        }
    }

    @Test(arguments: shapes) func fitsTheTargetDuration(_ options: StructureGenerator.Options) {
        let structure = StructureGenerator(options).makeStructure()
        let total = structure.totalDuration / 60
        let extra = Double(options.extraLevels * options.levelMinutes)
        // The levels within the target, plus the extra levels and maybe their breaks.
        #expect(total >= Double(options.targetMinutes) + extra)
        #expect(total <= Double(options.targetMinutes) + extra + Double(options.levelMinutes + 2 * options.breakMinutes))

        let levels = structure.rounds.filter { !$0.isBreak }
        let totalChips = options.startingStack * options.players
        let levelAtTarget = levels[levels.count - options.extraLevels - 1]
        // At the target time, the big blind is a sizable part of all chips: the game is nearly over.
        #expect(Double(levelAtTarget.bigBlind) > Double(totalChips) / 50)
        #expect(Double(levelAtTarget.bigBlind) < Double(totalChips) / 12)
        // A starting stack is deep: at least 100 big blinds.
        #expect(options.startingStack / levels[0].bigBlind >= 100)
    }

    @Test func breaksAndAntes() {
        let s = StructureGenerator(.init()).makeStructure()
        let breakIndices = s.rounds.indices.filter { s.rounds[$0].isBreak }
        #expect(breakIndices.count >= 2)
        // 120 minutes of play between breaks: six 20-minute levels.
        #expect(breakIndices.first == 6)
        #expect(s.rounds.contains { $0.note.hasPrefix("Color up the 25s") })
        #expect(s.rounds[0].ante == 0)
        #expect(s.rounds.last!.ante == s.rounds.last!.bigBlind)

        let noAntes = StructureGenerator(.init(anteStyle: nil)).makeStructure()
        #expect(noAntes.rounds.allSatisfy { $0.ante == 0 })
        let noBreaks = StructureGenerator(.init(breakEveryMinutes: 0)).makeStructure()
        #expect(!noBreaks.rounds.contains { $0.isBreak })
    }

    @Test func niceBlinds() {
        #expect(StructureGenerator.niceBlind(near: 40, above: 0, unit: 50) == 50)
        #expect(StructureGenerator.niceBlind(near: 140, above: 100, unit: 50) == 150)
        #expect(StructureGenerator.niceBlind(near: 100, above: 100, unit: 50) == 150)
        #expect(StructureGenerator.niceBlind(near: 2300, above: 2000, unit: 50) == 2500)
        #expect(StructureGenerator.niceBlind(near: 2600, above: 2000, unit: 200) == 3000)
        #expect(StructureGenerator.colorUpNote([25, 100]) == "Color up the 25s and 100s")
        #expect(StructureGenerator.colorUpNote([]) == "")
    }

    private func mantissa(_ value: Int) -> Double {
        var v = Double(value)
        while v >= 10 { v /= 10 }
        return (v * 10).rounded() / 10
    }
}
