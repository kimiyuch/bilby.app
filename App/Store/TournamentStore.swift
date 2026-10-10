import BilbyKit
import Foundation
import Observation

/// The app's state: the tournament in play and the saved structures. Every change is written to disk
/// straight away, so a running tournament carries on after a relaunch.
@Observable
final class TournamentStore {
    private(set) var tournament: Tournament
    private(set) var library: [Structure]
    /// Advances about once a second, for views that show the time but don't run their own TimelineView.
    private(set) var now = Date.now

    /// Called on the main actor for each clock event as it happens.
    @ObservationIgnored var onEvent: ((ClockEvent) -> Void)?

    @ObservationIgnored private let persistence: Persistence
    @ObservationIgnored private var lastTick = Date.now
    @ObservationIgnored private var ticker: Task<Void, Never>?

    init(persistence: Persistence = .standard) {
        self.persistence = persistence
        tournament = persistence.load(Tournament.self, from: "tournament.json") ?? Tournament(structure: Presets.standard)
        library = persistence.load([Structure].self, from: "structures.json") ?? []
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                self?.tick()
            }
        }
    }

    var structure: Structure { tournament.structure }

    func snapshot(at date: Date = .now) -> ClockSnapshot {
        tournament.snapshot(at: date)
    }

    // MARK: Clock controls

    func toggle() { change { $0.clock.toggle(in: $0.structure, at: $1) } }
    func next() { change { $0.clock.next(in: $0.structure, at: $1) } }
    func previous() { change { $0.clock.previous(in: $0.structure, at: $1) } }
    func restartRound() { change { $0.clock.restartRound(in: $0.structure, at: $1) } }
    func adjust(minutes: Int) { change { $0.clock.adjust(by: TimeInterval(minutes * 60), in: $0.structure, at: $1) } }
    func jump(to index: Int) { change { $0.clock.jump(to: index, in: $0.structure, at: $1) } }
    func resetClock() { change { t, _ in t.clock.reset(structure: t.structure) } }

    // MARK: Structures

    /// Edits the structure in play; the clock stays on its round.
    func setStructure(_ structure: Structure) {
        change { $0.setStructure(structure, at: $1) }
    }

    /// Plays a different structure from its first level.
    func use(_ structure: Structure) {
        change { t, _ in t.replaceStructure(with: structure) }
    }

    func saveToLibrary(_ structure: Structure) {
        if let i = library.firstIndex(where: { $0.id == structure.id }) {
            library[i] = structure
        } else {
            library.append(structure)
        }
        persistence.save(library, to: "structures.json")
    }

    func removeFromLibrary(_ structure: Structure) {
        library.removeAll { $0.id == structure.id }
        persistence.save(library, to: "structures.json")
    }

    // MARK: Internals

    private func change(_ body: (inout Tournament, Date) -> Void) {
        let date = Date.now
        tick(at: date)
        var t = tournament
        body(&t, date)
        guard t != tournament else { return }
        tournament = t
        lastTick = date
        persistence.save(tournament, to: "tournament.json")
    }

    private func tick(at date: Date = .now) {
        defer { lastTick = date }
        if Int(date.timeIntervalSinceReferenceDate) != Int(now.timeIntervalSinceReferenceDate) { now = date }
        guard date > lastTick, let onEvent else { return }
        let due = tournament.clock.upcomingEvents(in: tournament.structure, at: lastTick, warning: warningLead)
            .prefix { $0.date <= date }
        // After sleep, don't replay a pile of old alerts; only the ones that just happened.
        for event in due where date.timeIntervalSince(event.date) < 5 {
            onEvent(event)
        }
    }

    /// How long before the end of a round the warning comes. Settings will make this configurable.
    var warningLead: TimeInterval = 60
}
