import BilbyKit
import Foundation
import os

/// Turns clock events into sounds and announcements, following the settings.
@Observable
final class Alerts {
    @ObservationIgnored private let sounds = SoundPlayer()
    @ObservationIgnored private weak var store: TournamentStore?
    private static let log = Logger(subsystem: "ch.kimiyu.Bilby", category: "alerts")

    init(store: TournamentStore) {
        self.store = store
        store.onEvent = { [weak self] event in self?.handle(event) }
    }

    func handle(_ event: ClockEvent) {
        guard let store, !store.settings.muted else { return }
        let settings = store.settings
        let structure = store.structure
        let (chime, text) = Self.alert(for: event, in: structure, settings: settings)
        Self.log.info("Alert \(chime.rawValue, privacy: .public): \(text, privacy: .public)")
        sounds.play(chime, then: settings.announce ? text : nil, volume: settings.volume, voice: settings.voice)
    }

    /// Plays a sound regardless of mute, for trying them out in settings.
    func preview(_ chime: Chime) {
        guard let store else { return }
        sounds.play(chime, volume: store.settings.volume, voice: nil)
    }

    func previewVoice() {
        guard let store else { return }
        let structure = store.structure
        let index = structure.rounds.firstIndex { $0.ante > 0 } ?? 0
        sounds.speak(Announcement.roundStarted(index, in: structure), volume: store.settings.volume, voice: store.settings.voice)
    }

    static func alert(for event: ClockEvent, in structure: Structure, settings: AppSettings) -> (Chime, String) {
        let rounds = structure.rounds
        guard rounds.indices.contains(event.roundIndex) else { return (.none, "") }
        let round = rounds[event.roundIndex]
        switch event.kind {
        case .warning:
            return (settings.warningSound, Announcement.warning(round, remaining: settings.warning))
        case .roundStarted:
            let previous = event.roundIndex > 0 ? rounds[event.roundIndex - 1] : nil
            let chime = round.isBreak ? settings.breakStartSound
                : previous?.isBreak == true ? settings.breakEndSound : settings.levelSound
            return (chime, Announcement.roundStarted(event.roundIndex, in: structure))
        case .finished:
            return (settings.levelSound, Announcement.finished)
        }
    }
}
