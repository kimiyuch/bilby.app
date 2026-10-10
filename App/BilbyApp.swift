import BilbyKit
import SwiftUI

@main
struct BilbyApp: App {
    @State private var store: TournamentStore
    @State private var alerts: Alerts
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    private let displayAwake = DisplayAwake()
    #else
    private let extras: IOSExtras
    #endif

    init() {
        let store = TournamentStore()
        _store = State(initialValue: store)
        _alerts = State(initialValue: Alerts(store: store))
        #if os(macOS)
        let awake = displayAwake
        store.observe { awake.set($0.isRunning) }
        #else
        extras = IOSExtras(store: store)
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
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesButton(model: delegate.updaterModel)
            }
            ClockCommands(store: store)
        }

        Window("Big Screen", id: "bigscreen") {
            BigScreenView()
                .environment(store)
                .frame(minWidth: 480, minHeight: 270)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 960, height: 540)
        .windowBackgroundDragBehavior(.enabled)

        MenuBarExtra {
            MenuBarContent(updaterModel: delegate.updaterModel)
                .environment(store)
        } label: {
            MenuBarLabel(store: store)
        }

        Settings {
            SoundSettings { UpdateSettingsSection(model: delegate.updaterModel) }
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
    enum Section: String { case clock, structure, players, settings }

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
            #if os(iOS)
            Tab("Settings", systemImage: "gearshape", value: .settings) {
                NavigationStack { SoundSettings().navigationTitle("Settings") }
            }
            #endif
        }
        #if DEBUG && os(macOS)
        .task {
            let openSettings = openSettings, openWindow = openWindow
            DebugRemote.install(store: store, selectTab: { section = Section(rawValue: $0) ?? section },
                                openSettings: { openSettings() }, openWindow: { openWindow(id: $0) })
        }
        #elseif DEBUG
        .task {
            DebugRemote.install(store: store, selectTab: { section = Section(rawValue: $0) ?? section },
                                fullScreen: { NotificationCenter.default.post(name: .bilbyFullScreen, object: nil) })
        }
        #endif
    }
}

/// The clock with its controls underneath.
struct ClockScreen: View {
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #else
    @State private var fullScreen = false
    #endif

    var body: some View {
        VStack(spacing: 16) {
            LiveClockView()
                .clipShape(.rect(cornerRadius: 18))
                #if os(iOS)
                .onTapGesture { fullScreen = true }
                .accessibilityAction(named: "Full Screen") { fullScreen = true }
                #endif
            ClockControls()
        }
        #if os(macOS)
        .padding(20)
        #else
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .fullScreenCover(isPresented: $fullScreen) { FullScreenClock() }
        .onReceive(NotificationCenter.default.publisher(for: .bilbyFullScreen)) { _ in fullScreen.toggle() }
        #endif
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

extension Notification.Name {
    /// Debug builds use this to open and close the full screen clock.
    static let bilbyFullScreen = Notification.Name("ch.kimiyu.Bilby.fullScreen")
}
