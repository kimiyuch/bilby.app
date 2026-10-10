#if os(macOS)
import AppKit
import BilbyKit
import IOKit.pwr_mgt
import SwiftUI

/// The countdown in the menu bar.
struct MenuBarLabel: View {
    let store: TournamentStore

    var body: some View {
        let s = store.snapshot(at: store.now)
        if s.hasStarted, !s.isFinished {
            HStack(spacing: 4) {
                Image(systemName: s.isBreak ? "cup.and.saucer.fill" : s.isRunning ? "timer" : "pause.fill")
                Text(TimeFormat.countdown(s.remaining)).monospacedDigit()
            }
        } else {
            Image(systemName: "timer")
        }
    }
}

struct MenuBarContent: View {
    let updaterModel: UpdaterModel
    @Environment(TournamentStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let s = store.snapshot(at: store.now)
        Text(s.levelNumber.map { "Level \($0) · \(s.round.shortText)" } ?? "Break")
        if let next = s.nextRound {
            Text("Next: " + (next.isBreak ? "Break" : next.shortText))
        }
        Divider()
        Button(s.isRunning ? "Pause" : "Start", action: store.toggle)
            .disabled(s.isFinished)
        Button("Next Level", action: store.next)
        Button("Previous Level", action: store.previous)
        Divider()
        Button("Show Bilby") {
            openWindow(id: "main")
            NSApp.activate()
        }
        Button("Show Big Screen") {
            openWindow(id: "bigscreen")
            NSApp.activate()
        }
        Divider()
        CheckForUpdatesButton(model: updaterModel)
        Button("Quit Bilby") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

/// Menu bar commands for the clock and the big screen.
struct ClockCommands: Commands {
    let store: TournamentStore
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Tournament") { store.newTournament() }
                .keyboardShortcut("n")
        }
        CommandMenu("Clock") {
            Button(store.isRunning ? "Pause" : "Start", action: store.toggle)
            Button("Next Level", action: store.next)
            Button("Previous Level", action: store.previous)
            Button("Restart Level", action: store.restartRound)
            Divider()
            Button("Add a Minute") { store.adjust(minutes: 1) }
            Button("Take Off a Minute") { store.adjust(minutes: -1) }
            Divider()
            Button(store.settings.muted ? "Unmute" : "Mute") { store.settings.muted.toggle() }
        }
        CommandGroup(before: .windowList) {
            Button("Show Big Screen") { openWindow(id: "bigscreen") }
                .keyboardShortcut("b")
            Menu("Show Big Screen Full Screen On") {
                ForEach(Array(BigScreen.screens.enumerated()), id: \.offset) { _, screen in
                    Button(screen.localizedName) { BigScreen.shared.show(on: screen, openWindow: openWindow) }
                }
            }
            Divider()
        }
    }
}

/// Keeps the display from dimming or sleeping while the clock runs.
final class DisplayAwake {
    private var assertion: IOPMAssertionID?

    func set(_ awake: Bool) {
        if awake, assertion == nil {
            var id = IOPMAssertionID(0)
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "The tournament clock is running" as CFString,
                &id
            )
            if result == kIOReturnSuccess { assertion = id }
        } else if !awake, let id = assertion {
            IOPMAssertionRelease(id)
            assertion = nil
        }
    }
}
#endif
