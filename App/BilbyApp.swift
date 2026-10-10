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

/// The clock and its control strip, as one card like a media player: the structure being played on the left,
/// previous, start/pause and next in the middle, and a menu with the rest on the right. Same as the browser version.
struct ClockScreen: View {
    @Environment(TournamentStore.self) private var store
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #else
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var fullScreen = false
    #endif

    var body: some View {
        VStack(spacing: 0) {
            LiveClockView(fullScreen: showFullScreen)
                #if os(iOS)
                .onTapGesture { fullScreen = true }
                .accessibilityAction(named: "Full Screen") { fullScreen = true }
                #endif
            HStack(spacing: 16) {
                playing.frame(maxWidth: .infinity, alignment: .leading)
                ClockControls()
                ClockMenu().frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.background.secondary)
        .clipShape(.rect(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(.separator) }
        .background(ClockShortcuts())
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

extension ClockScreen {
    /// "Playing" and the structure's name. Left out on a narrow iPhone, where the controls need the room.
    @ViewBuilder
    fileprivate var playing: some View {
        #if os(iOS)
        // An empty spacer keeps the controls centred.
        if sizeClass != .compact { playingLabel } else { Color.clear.frame(height: 1) }
        #else
        playingLabel
        #endif
    }

    private var playingLabel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Playing").font(.caption).foregroundStyle(.secondary)
            Text(store.structure.name).font(.callout.weight(.medium)).lineLimit(1)
        }
    }

    /// The button in the corner of the clock: full screen on iPhone and iPad, the big screen on the Mac.
    fileprivate func showFullScreen() {
        #if os(macOS)
        BigScreen.shared.show(on: nil, openWindow: openWindow)
        #else
        fullScreen = true
        #endif
    }
}

extension Notification.Name {
    /// Debug builds use this to open and close the full screen clock.
    static let bilbyFullScreen = Notification.Name("ch.kimiyu.Bilby.fullScreen")
}
