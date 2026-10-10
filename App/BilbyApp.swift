import BilbyKit
import SwiftUI

@main
struct BilbyApp: App {
    @State private var store: TournamentStore
    @State private var alerts: Alerts
    #if os(macOS)
    private let displayAwake = DisplayAwake()
    #endif

    init() {
        let store = TournamentStore()
        _store = State(initialValue: store)
        _alerts = State(initialValue: Alerts(store: store))
        #if os(macOS)
        let awake = displayAwake
        store.observe { awake.set($0.isRunning) }
        #endif
    }

    var body: some Scene {
        #if os(macOS)
        Window("Bilby", id: "main") {
            ContentView()
                .environment(store)
                .environment(alerts)
                .frame(minWidth: 820, minHeight: 560)
        }
        .defaultSize(width: 1080, height: 720)
        .commands { ClockCommands(store: store) }

        Window("Big Screen", id: "bigscreen") {
            BigScreenView()
                .environment(store)
                .frame(minWidth: 480, minHeight: 270)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 960, height: 540)
        .windowBackgroundDragBehavior(.enabled)

        MenuBarExtra {
            MenuBarContent()
                .environment(store)
        } label: {
            MenuBarLabel(store: store)
        }

        Settings {
            SoundSettings()
                .environment(store)
                .environment(alerts)
                .frame(width: 460)
                .fixedSize(horizontal: false, vertical: true)
        }
        #else
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(alerts)
        }
        #endif
    }
}

struct ContentView: View {
    enum Section: String { case clock, structure, players }

    @Environment(TournamentStore.self) private var store
    @State private var section = Section.clock
    #if DEBUG && os(macOS)
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    #endif

    var body: some View {
        TabView(selection: $section) {
            Tab("Clock", systemImage: "timer", value: .clock) { ClockScreen() }
            Tab("Structure", systemImage: "list.number", value: .structure) {
                NavigationStack { StructureEditor() }
            }
            Tab("Players", systemImage: "person.3", value: .players) {
                NavigationStack { PlayersView() }
            }
        }
        #if DEBUG && os(macOS)
        .task {
            let openSettings = openSettings, openWindow = openWindow
            DebugRemote.install(store: store, selectTab: { section = Section(rawValue: $0) ?? section },
                                openSettings: { openSettings() }, openWindow: { openWindow(id: $0) })
        }
        #endif
    }
}

/// The clock with its controls underneath.
struct ClockScreen: View {
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    var body: some View {
        VStack(spacing: 16) {
            LiveClockView()
                .clipShape(.rect(cornerRadius: 18))
            ClockControls()
        }
        .padding(20)
        #if os(macOS)
        .toolbar {
            ToolbarItem {
                Menu("Big Screen", systemImage: "tv") {
                    Button("Show in a Window") { openWindow(id: "bigscreen") }
                    Section("Full Screen On") {
                        ForEach(Array(BigScreen.screens.enumerated()), id: \.offset) { _, screen in
                            Button(screen.localizedName) { BigScreen.shared.show(on: screen, openWindow: openWindow) }
                        }
                    }
                } primaryAction: {
                    openWindow(id: "bigscreen")
                }
                .help("Show the clock on its own, for a TV or projector")
            }
        }
        #endif
    }
}
