import BilbyKit
import SwiftUI

@main
struct BilbyApp: App {
    @State private var store: TournamentStore
    @State private var alerts: Alerts

    init() {
        let store = TournamentStore()
        _store = State(initialValue: store)
        _alerts = State(initialValue: Alerts(store: store))
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
            let openSettings = openSettings
            DebugRemote.install(store: store, selectTab: { section = Section(rawValue: $0) ?? section },
                                openSettings: { openSettings() })
        }
        #endif
    }
}

/// The clock with its controls underneath.
struct ClockScreen: View {
    var body: some View {
        VStack(spacing: 16) {
            LiveClockView()
                .clipShape(.rect(cornerRadius: 18))
            ClockControls()
        }
        .padding(20)
    }
}
