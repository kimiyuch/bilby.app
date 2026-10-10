import Foundation

/// The tournament being played: its structure and the clock running through it.
public struct Tournament: Codable, Equatable, Sendable {
    public private(set) var structure: Structure
    public var clock: Clock

    public init(structure: Structure) {
        self.structure = structure
        clock = Clock(structure: structure)
    }

    /// Edits the structure while keeping the clock on the same round.
    public mutating func setStructure(_ new: Structure, at now: Date) {
        guard new != structure, !new.rounds.isEmpty else { return }
        clock.structureChanged(from: structure, to: new, at: now)
        structure = new
    }

    /// Switches to a different structure and puts the clock back to its first level.
    public mutating func replaceStructure(with new: Structure) {
        guard !new.rounds.isEmpty else { return }
        structure = new
        clock = Clock(structure: new)
    }

    public func snapshot(at now: Date) -> ClockSnapshot {
        clock.snapshot(in: structure, at: now)
    }
}
