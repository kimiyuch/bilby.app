import BilbyKit
import SwiftUI

/// Start/pause, next/previous, ±1 minute and restart. Space and the arrow keys work while these are on screen.
struct ClockControls: View {
    @Environment(TournamentStore.self) private var store
    @State private var confirmingReset = false

    var body: some View {
        // One row where it fits; on a narrow iPhone the secondary buttons move to a second row.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                previous; restart; minus; playPause; plus; reset; next; mute.padding(.leading, 12)
            }
            VStack(spacing: 10) {
                HStack(spacing: 16) { previous; playPause; next }
                HStack(spacing: 10) { restart; minus; plus; reset; mute }
            }
        }
        .buttonStyle(.glass)
        .controlSize(.large)
        .labelStyle(.iconOnly)
        .confirmationDialog("Reset the clock?", isPresented: $confirmingReset) {
            Button("Reset", role: .destructive, action: store.resetClock)
        } message: {
            Text("The clock goes back to level 1 and stops.")
        }
    }

    private var running: Bool { store.isRunning }

    private var previous: some View {
        Button("Previous Level", systemImage: "backward.end.fill", action: store.previous)
            .keyboardShortcut(.leftArrow, modifiers: [])
            .help("Previous level (←)")
    }

    private var restart: some View {
        Button("Restart Level", systemImage: "arrow.counterclockwise", action: store.restartRound)
            .help("Start this level again")
    }

    private var minus: some View {
        Button { store.adjust(minutes: -1) } label: { Text("−1 min").fixedSize() }
            .keyboardShortcut(.downArrow, modifiers: [])
            .help("Take a minute off (↓)")
    }

    private var playPause: some View {
        Button(running ? "Pause" : "Start", systemImage: running ? "pause.fill" : "play.fill", action: store.toggle)
            .keyboardShortcut(.space, modifiers: [])
            .buttonStyle(.glassProminent)
            .controlSize(.extraLarge)
            .frame(minWidth: 96)
            .help("Start or pause (space)")
    }

    private var plus: some View {
        Button { store.adjust(minutes: 1) } label: { Text("+1 min").fixedSize() }
            .keyboardShortcut(.upArrow, modifiers: [])
            .help("Add a minute (↑)")
    }

    private var reset: some View {
        Button("Reset Clock", systemImage: "stop.fill") { confirmingReset = true }
            .help("Back to level 1, stopped")
            .disabled(!store.tournament.clock.hasStarted)
    }

    private var next: some View {
        Button("Next Level", systemImage: "forward.end.fill", action: store.next)
            .keyboardShortcut(.rightArrow, modifiers: [])
            .help("Next level (→)")
    }

    private var mute: some View {
        Button(store.settings.muted ? "Unmute" : "Mute",
               systemImage: store.settings.muted ? "speaker.slash.fill" : "speaker.wave.2.fill") {
            store.settings.muted.toggle()
        }
        .keyboardShortcut("m", modifiers: [])
        .help(store.settings.muted ? "Sounds are off (M)" : "Sounds are on (M)")
    }
}
