import BilbyKit
import SwiftUI

/// Previous, start/pause and next, like a media player. The rest is in `ClockMenu`.
struct ClockControls: View {
    @Environment(TournamentStore.self) private var store

    var body: some View {
        HStack(spacing: 12) {
            button("Previous Level", "backward.fill", size: 26, action: store.previous)
                .help("Previous level (←)")
            button(store.isRunning ? "Pause" : "Start", store.isRunning ? "pause.fill" : "play.fill", size: 40,
                   action: store.toggle)
                .buttonStyle(.glassProminent)
                .tint(ClockTheme.chip)
                .help("Start or pause (space)")
            button("Next Level", "forward.fill", size: 26, action: store.next)
                .help("Next level (→)")
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
    }

    /// A round button as big as the browser version's: the icon's frame sets the size of the glass around it.
    private func button(_ title: String, _ icon: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.42, weight: .semibold))
                .frame(width: size, height: size)
        }
        .accessibilityLabel(title)
    }
}

/// The clock's less common controls: a minute more or less, restart the level, mute and reset.
struct ClockMenu: View {
    @Environment(TournamentStore.self) private var store
    @State private var confirmingReset = false

    var body: some View {
        Menu {
            Button("Add a Minute (↑)", systemImage: "plus") { store.adjust(minutes: 1) }
            Button("Take a Minute Off (↓)", systemImage: "minus") { store.adjust(minutes: -1) }
            Button("Restart This Level", systemImage: "arrow.counterclockwise", action: store.restartRound)
            Button(store.settings.muted ? "Turn Sounds On (M)" : "Mute (M)",
                   systemImage: store.settings.muted ? "speaker.wave.2" : "speaker.slash") {
                store.settings.muted.toggle()
            }
            Divider()
            Button("Reset Clock…", systemImage: "stop", role: .destructive) { confirmingReset = true }
                .disabled(!store.tournament.clock.hasStarted)
        } label: {
            // Muted shows here, so it isn't forgotten.
            Image(systemName: store.settings.muted ? "speaker.slash.fill" : "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 26, height: 26)
                .accessibilityLabel("More")
        }
        .menuIndicator(.hidden)
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .help(store.settings.muted ? "More (sounds are off)" : "More")
        .confirmationDialog("Reset the clock?", isPresented: $confirmingReset) {
            Button("Reset", role: .destructive, action: store.resetClock)
        } message: {
            Text("The clock goes back to level 1 and stops.")
        }
    }
}

/// Space, the arrow keys and M, wherever the clock is on screen. Invisible buttons, so they work without a menu
/// item and on an iPad keyboard too.
struct ClockShortcuts: View {
    @Environment(TournamentStore.self) private var store

    var body: some View {
        ZStack {
            Button("", action: store.toggle).keyboardShortcut(.space, modifiers: [])
            Button("", action: store.next).keyboardShortcut(.rightArrow, modifiers: [])
            Button("", action: store.previous).keyboardShortcut(.leftArrow, modifiers: [])
            Button("") { store.adjust(minutes: 1) }.keyboardShortcut(.upArrow, modifiers: [])
            Button("") { store.adjust(minutes: -1) }.keyboardShortcut(.downArrow, modifiers: [])
            Button("") { store.settings.muted.toggle() }.keyboardShortcut("m", modifiers: [])
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }
}
