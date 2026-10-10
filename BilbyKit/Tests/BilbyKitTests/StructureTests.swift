import Foundation
import Testing
@testable import BilbyKit

@Suite struct StructureTests {
    @Test func levelNumbersSkipBreaks() {
        let s = Presets.standard
        #expect(s.levelNumber(at: 0) == 1)
        #expect(s.levelNumber(at: 4) == nil)
        #expect(s.levelNumber(at: 5) == 5)
        #expect(s.levelCount == 18)
    }

    @Test func exportAndImportRoundTrip() throws {
        let original = Presets.turbo
        let data = try original.exportData()
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"format\" : \"bilby.structure\""))
        #expect(text.contains("Color up the 25s"))

        let imported = try Structure.importing(data)
        #expect(imported.name == original.name)
        #expect(imported.id != original.id)
        #expect(imported.rounds.count == original.rounds.count)
        for (a, b) in zip(imported.rounds, original.rounds) {
            #expect(a.id != b.id)
            #expect(a.kind == b.kind && a.minutes == b.minutes && a.bigBlind == b.bigBlind && a.ante == b.ante)
            #expect(a.note == b.note)
        }
    }

    @Test func importsHandWrittenFiles() throws {
        let json = """
        {"format": "bilby.structure", "version": 1, "name": "Quick",
         "rounds": [{"type": "level", "minutes": 15, "smallBlind": 50, "bigBlind": 100},
                    {"type": "break", "minutes": 5},
                    {"type": "level", "minutes": 15, "smallBlind": 100, "bigBlind": 200, "ante": 25, "anteStyle": "everyone"}]}
        """
        let s = try Structure.importing(Data(json.utf8))
        #expect(s.rounds.count == 3)
        #expect(s.rounds[1].isBreak)
        #expect(s.rounds[2].anteStyle == .everyone)
        #expect(s.rounds[2].ante == 25)
    }

    @Test func rejectsBadFiles() {
        #expect(throws: Structure.FileError.notAStructure) { try Structure.importing(Data("{}".utf8)) }
        #expect(throws: Structure.FileError.notAStructure) {
            try Structure.importing(Data(#"{"format":"other","version":1,"name":"x","rounds":[]}"#.utf8))
        }
        #expect(throws: Structure.FileError.unsupportedVersion(9)) {
            try Structure.importing(Data(#"{"format":"bilby.structure","version":9,"name":"x","rounds":[]}"#.utf8))
        }
        #expect(throws: Structure.FileError.empty) {
            try Structure.importing(Data(#"{"format":"bilby.structure","version":1,"name":"x","rounds":[]}"#.utf8))
        }
        #expect(throws: Structure.FileError.invalidLevel(1)) {
            try Structure.importing(Data(#"{"format":"bilby.structure","version":1,"name":"x","rounds":[{"type":"level","minutes":10,"smallBlind":200,"bigBlind":100}]}"#.utf8))
        }
    }

    @Test(arguments: Presets.all) func presetsAreSensible(_ preset: Structure) {
        let levels = preset.rounds.filter { !$0.isBreak }
        #expect(levels.first?.smallBlind == 25)
        for (a, b) in zip(levels, levels.dropFirst()) {
            #expect(b.bigBlind >= a.bigBlind)
        }
        for level in levels {
            #expect(level.smallBlind * 2 == level.bigBlind)
            #expect(level.ante == 0 || level.ante == level.bigBlind)
        }
    }

    @Test func announcements() {
        let s = Presets.standard
        #expect(Announcement.roundStarted(0, in: s) == "Level 1. Blinds 25, 50.")
        #expect(Announcement.roundStarted(7, in: s) == "Level 7. Blinds 200, 400, ante 400.")
        #expect(Announcement.roundStarted(9, in: s) == "Break. 15 minutes. Color up the 25s.")
        #expect(Announcement.roundStarted(4, in: s) == "Break. 10 minutes.")
        #expect(Announcement.warning(s.rounds[0], remaining: 60) == "One minute left in this level.")
        #expect(Announcement.warning(s.rounds[4], remaining: 120) == "2 minutes left in the break.")
    }
}
