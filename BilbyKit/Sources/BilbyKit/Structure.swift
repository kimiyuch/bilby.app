import Foundation

/// How the ante of a level is paid.
public enum AnteStyle: String, Codable, Sendable, CaseIterable {
    /// Every player pays the ante.
    case everyone
    /// The big blind pays the ante for the whole table.
    case bigBlind
}

/// One step of a blind structure: a level with blinds, or a break.
public struct Round: Identifiable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case level
        case `break`
    }

    public var id: UUID
    public var kind: Kind
    public var minutes: Int
    public var smallBlind: Int
    public var bigBlind: Int
    public var ante: Int
    public var anteStyle: AnteStyle
    /// Shown during a break, e.g. "Color up the 25s".
    public var note: String

    public init(id: UUID = UUID(), kind: Kind, minutes: Int, smallBlind: Int = 0, bigBlind: Int = 0,
                ante: Int = 0, anteStyle: AnteStyle = .bigBlind, note: String = "") {
        self.id = id
        self.kind = kind
        self.minutes = minutes
        self.smallBlind = smallBlind
        self.bigBlind = bigBlind
        self.ante = ante
        self.anteStyle = anteStyle
        self.note = note
    }

    public static func level(_ smallBlind: Int, _ bigBlind: Int, ante: Int = 0, style: AnteStyle = .bigBlind,
                             minutes: Int) -> Round {
        Round(kind: .level, minutes: minutes, smallBlind: smallBlind, bigBlind: bigBlind, ante: ante, anteStyle: style)
    }

    public static func pause(minutes: Int, note: String = "") -> Round {
        Round(kind: .break, minutes: minutes, note: note)
    }

    public var isBreak: Bool { kind == .break }
    public var duration: TimeInterval { TimeInterval(max(minutes, 0) * 60) }
}

extension Round: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, type, minutes, smallBlind, bigBlind, ante, anteStyle, note
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try c.decode(Kind.self, forKey: .type)
        minutes = try c.decode(Int.self, forKey: .minutes)
        smallBlind = try c.decodeIfPresent(Int.self, forKey: .smallBlind) ?? 0
        bigBlind = try c.decodeIfPresent(Int.self, forKey: .bigBlind) ?? 0
        ante = try c.decodeIfPresent(Int.self, forKey: .ante) ?? 0
        anteStyle = try c.decodeIfPresent(AnteStyle.self, forKey: .anteStyle) ?? .bigBlind
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
    }

    /// Only writes the fields that matter for the kind, so exported files stay readable.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(kind, forKey: .type)
        try c.encode(minutes, forKey: .minutes)
        switch kind {
        case .level:
            try c.encode(smallBlind, forKey: .smallBlind)
            try c.encode(bigBlind, forKey: .bigBlind)
            if ante > 0 {
                try c.encode(ante, forKey: .ante)
                try c.encode(anteStyle, forKey: .anteStyle)
            }
        case .break:
            if !note.isEmpty { try c.encode(note, forKey: .note) }
        }
    }
}

/// A named list of levels and breaks.
public struct Structure: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var rounds: [Round]

    public init(id: UUID = UUID(), name: String, rounds: [Round]) {
        self.id = id
        self.name = name
        self.rounds = rounds
    }

    /// The level number of the round at `index` (breaks don't count), or nil for a break.
    public func levelNumber(at index: Int) -> Int? {
        guard rounds.indices.contains(index), !rounds[index].isBreak else { return nil }
        return rounds[...index].filter { !$0.isBreak }.count
    }

    public var levelCount: Int { rounds.filter { !$0.isBreak }.count }

    public var totalDuration: TimeInterval { rounds.reduce(0) { $0 + $1.duration } }
}

// MARK: - Import and export

extension Structure {
    public enum FileError: Error, Equatable {
        case notAStructure
        case unsupportedVersion(Int)
        case empty
        case invalidLevel(Int)
    }

    static let fileFormat = "bilby.structure"
    static let fileVersion = 1

    private struct File: Codable {
        var format: String
        var version: Int
        var name: String
        var rounds: [Round]
    }

    /// Pretty-printed JSON, suitable for sharing.
    public func exportData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(File(format: Self.fileFormat, version: Self.fileVersion, name: name, rounds: rounds))
    }

    /// Reads an exported structure. The result gets new IDs, so importing the same file twice gives two structures.
    public static func importing(_ data: Data) throws -> Structure {
        let file: File
        do {
            file = try JSONDecoder().decode(File.self, from: data)
        } catch {
            throw FileError.notAStructure
        }
        guard file.format == fileFormat else { throw FileError.notAStructure }
        guard file.version <= fileVersion else { throw FileError.unsupportedVersion(file.version) }
        guard !file.rounds.isEmpty else { throw FileError.empty }
        var rounds = file.rounds
        for i in rounds.indices {
            rounds[i].id = UUID()
            let r = rounds[i]
            guard r.minutes > 0 else { throw FileError.invalidLevel(i + 1) }
            if !r.isBreak, r.bigBlind <= 0 || r.smallBlind < 0 || r.smallBlind > r.bigBlind || r.ante < 0 {
                throw FileError.invalidLevel(i + 1)
            }
        }
        return Structure(name: file.name, rounds: rounds)
    }
}

extension Structure {
    /// A sensible level to follow `previous`: blinds up by about half, same length and ante style.
    public func suggestedLevel(after previous: Round?) -> Round {
        guard let previous, previous.bigBlind > 0 else { return .level(25, 50, minutes: 20) }
        let smallest = rounds.first { !$0.isBreak && $0.smallBlind > 0 }?.smallBlind ?? 1
        let bb = StructureGenerator.niceBlind(near: Double(previous.bigBlind) * 1.5, above: previous.bigBlind,
                                              unit: smallest * 2)
        var ante = 0
        if previous.ante > 0 {
            let scaled = Double(previous.ante * bb) / Double(previous.bigBlind) / Double(smallest)
            ante = previous.anteStyle == .bigBlind ? bb : max(smallest, Int(scaled.rounded()) * smallest)
        }
        return .level(bb / 2, bb, ante: ante, style: previous.anteStyle, minutes: previous.minutes)
    }
}
