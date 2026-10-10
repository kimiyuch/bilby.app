import BilbyKit
import SwiftUI

/// Start/pause, next/previous, ±1 minute and restart. Space and the arrow keys work while these are on screen.
struct ClockControls: View {
    @Environment(TournamentStore.self) private var store
    @State private var confirmingReset = false

    var body: some View {
        let running = store.tournament.clock.caughtUp(in: store.structure, at: store.now).isRunning
        HStack(spacing: 12) {
            Button("Previous Level", systemImage: "backward.end.fill", action: store.previous)
                .keyboardShortcut(.leftArrow, modifiers: [])
                .help("Previous level (←)")
            Button("Restart Level", systemImage: "arrow.counterclockwise", action: store.restartRound)
                .help("Start this level again")
            Button("−1 min") { store.adjust(minutes: -1) }
                .keyboardShortcut(.downArrow, modifiers: [])
                .help("Take a minute off (↓)")

            Button(running ? "Pause" : "Start", systemImage: running ? "pause.fill" : "play.fill", action: store.toggle)
                .keyboardShortcut(.space, modifiers: [])
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)
                .frame(minWidth: 110)
                .help("Start or pause (space)")

            Button("+1 min") { store.adjust(minutes: 1) }
                .keyboardShortcut(.upArrow, modifiers: [])
                .help("Add a minute (↑)")
            Button("Reset Clock", systemImage: "stop.fill") { confirmingReset = true }
                .help("Back to level 1, stopped")
                .disabled(!store.tournament.clock.hasStarted)
            Button("Next Level", systemImage: "forward.end.fill", action: store.next)
                .keyboardShortcut(.rightArrow, modifiers: [])
                .help("Next level (→)")
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
}
