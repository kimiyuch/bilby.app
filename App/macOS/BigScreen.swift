#if os(macOS)
import AppKit
import BilbyKit
import SwiftUI

/// The clock on its own, for a TV or projector. The main window keeps the controls.
struct BigScreenView: View {
    var body: some View {
        LiveClockView()
            .background(WindowReader { BigScreen.shared.attach($0) })
            .background(ClockShortcuts())
            .onContinuousHover { _ in BigScreen.shared.hideCursorSoon() }
            .navigationTitle("Bilby Big Screen")
    }
}

/// Finds the big screen window so it can be moved to another display and made full screen.
@MainActor
final class BigScreen {
    static let shared = BigScreen()
    private weak var window: NSWindow?
    private var pendingScreen: NSScreen?
    private var cursorTask: Task<Void, Never>?

    /// Opens the big screen on `screen` (or where it was) and makes it full screen there.
    func show(on screen: NSScreen?, openWindow: OpenWindowAction?) {
        pendingScreen = screen
        openWindow?(id: "bigscreen")
        if let window { place(window) }
    }

    func attach(_ window: NSWindow) {
        guard self.window !== window else { return }
        self.window = window
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.backgroundColor = .black
        place(window)
    }

    private func place(_ window: NSWindow) {
        guard let screen = pendingScreen else { return }
        pendingScreen = nil
        window.makeKeyAndOrderFront(nil)
        let isFullScreen = window.styleMask.contains(.fullScreen)
        if isFullScreen, window.screen == screen { return }
        if isFullScreen { window.toggleFullScreen(nil) }
        // Leaving full screen animates; move and re-enter once it's done.
        Task {
            if isFullScreen { try? await Task.sleep(for: .seconds(1)) }
            let frame = screen.visibleFrame
            window.setFrame(NSRect(x: frame.midX - 480, y: frame.midY - 270, width: 960, height: 540), display: true)
            window.toggleFullScreen(nil)
        }
    }

    /// The pointer disappears over the clock until it moves again.
    func hideCursorSoon() {
        cursorTask?.cancel()
        cursorTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            NSCursor.setHiddenUntilMouseMoves(true)
        }
    }

    static var screens: [NSScreen] { NSScreen.screens }

    var isFullScreen: Bool { window?.styleMask.contains(.fullScreen) ?? false }

    func exitFullScreen() {
        if isFullScreen { window?.toggleFullScreen(nil) }
    }
}

/// Hands the hosting NSWindow to a closure once the view is in a window.
struct WindowReader: NSViewRepresentable {
    var found: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            if let window = view?.window { found(window) }
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        if let window = view.window { found(window) }
    }
}

/// Space, arrows and M on windows that don't show the control buttons.
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
#endif
