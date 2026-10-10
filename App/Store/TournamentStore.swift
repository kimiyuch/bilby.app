import BilbyKit
import Foundation
import Observation

/// The app's state: the tournament in play and the saved structures. Every change is written to disk
/// straight away, so a running tournament carries on after a relaunch.
@Observable
final class TournamentStore {
    private(set) var tournament: Tournament
    private(set) var library: [Structure]
    var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            persistence.save(settings, to: "settings.json")
            for observer in observers { observer(self) }
        }
    }
    /// Advances about once a second, for views that show the time but don't run their own TimelineView.
    private(set) var now = Date.now

    /// Whether the clock is running right now (it stops by itself after the last level).
    private(set) var isRunning = false

    /// Called on the main actor for each clock event as it happens.
    @ObservationIgnored var onEvent: ((ClockEvent) -> Void)?
    /// Called after anything about the tournament changed, including the clock moving to the next round.
    @ObservationIgnored private var observers: [(TournamentStore) -> Void] = []
    @ObservationIgnored private var lastRoundIndex = -1

    @ObservationIgnored private let persistence: Persistence
    @ObservationIgnored private var lastTick = Date.now
    @ObservationIgnored private var ticker: Task<Void, Never>?

    init(persistence: Persistence = .standard) {
        self.persistence = persistence
        tournament = persistence.load(Tournament.self, from: "tournament.json") ?? Tournament(structure: Presets.standard)
        library = persistence.load([Structure].self, from: "structures.json") ?? []
        settings = persistence.load(AppSettings.self, from: "settings.json") ?? AppSettings()
        isRunning = tournament.clock.caughtUp(in: tournament.structure, at: .now).isRunning
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                self?.tick()
            }
        }
    }

    var structure: Structure { tournament.structure }

    /// Runs `body` now and after every change to the tournament.
    func observe(_ body: @escaping (TournamentStore) -> Void) {
        observers.append(body)
        body(self)
    }

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

    /// Back to level 1 with all counters at zero; the structure and buy-ins stay.
    func newTournament() {
        change { t, _ in
            t.clock.reset(structure: t.structure)
            t.prizePool.resetCounters()
        }
    }

    // MARK: Players and prize pool

    func setPrizePool(_ pool: PrizePool) {
        change { t, _ in t.prizePool = pool }
    }

    func updatePrizePool(_ body: (inout PrizePool) -> Void) {
        change { t, _ in body(&t.prizePool) }
    }

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
        changed(at: date)
    }

    private func changed(at date: Date) {
        let clock = tournament.clock.caughtUp(in: tournament.structure, at: date)
        isRunning = clock.isRunning
        lastRoundIndex = clock.roundIndex
        for observer in observers { observer(self) }
    }

    private func tick(at date: Date = .now) {
        defer { lastTick = date }
        if Int(date.timeIntervalSinceReferenceDate) != Int(now.timeIntervalSinceReferenceDate) { now = date }
        let clock = tournament.clock.caughtUp(in: tournament.structure, at: date)
        if clock.roundIndex != lastRoundIndex || clock.isRunning != isRunning { changed(at: date) }
        guard date > lastTick, let onEvent else { return }
        let due = tournament.clock.upcomingEvents(in: tournament.structure, at: lastTick, warning: settings.warning)
            .prefix { $0.date <= date }
        // After sleep, don't replay a pile of old alerts; only the ones that just happened.
        for event in due where date.timeIntervalSince(event.date) < 5 {
            onEvent(event)
        }
    }
}
