import BilbyKit
import SwiftUI

@main
struct BilbyApp: App {
    @State private var store = TournamentStore()

    var body: some Scene {
        #if os(macOS)
        Window("Bilby", id: "main") {
            ContentView()
                .environment(store)
                .frame(minWidth: 820, minHeight: 560)
        }
        .defaultSize(width: 1080, height: 720)
        #else
        WindowGroup {
            ContentView()
                .environment(store)
        }
        #endif
    }
}

struct ContentView: View {
    enum Section: String { case clock, structure, players }

    @Environment(TournamentStore.self) private var store
    @State private var section = Section.clock

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
        .task { DebugRemote.install(store: store) { section = Section(rawValue: $0) ?? section } }
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
