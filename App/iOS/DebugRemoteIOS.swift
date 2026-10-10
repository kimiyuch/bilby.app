#if DEBUG && os(iOS)
import Foundation

/// Debug builds only: drive the app in the simulator from the command line, e.g.
///
///   xcrun simctl spawn booted notifyutil -p ch.kimiyu.Bilby.debug.toggle
///
/// Commands: toggle, pause, next, previous, plus, minus, entry, knockout, fullscreen, tab.clock, tab.structure,
/// tab.players, tab.settings. Screenshots come from `xcrun simctl io booted screenshot`.
enum DebugRemote {
    static let commands = ["toggle", "pause", "next", "previous", "plus", "minus", "entry", "knockout", "fullscreen",
                           "tab.clock", "tab.structure", "tab.players", "tab.settings", "reset"]

    nonisolated(unsafe) private static var handler: ((String) -> Void)?

    static func install(store: TournamentStore, selectTab: @escaping (String) -> Void, fullScreen: @escaping () -> Void) {
        handler = { command in
            switch command {
            case "toggle": store.toggle()
            case "pause": if store.isRunning { store.toggle() }
            case "next": store.next()
            case "previous": store.previous()
            case "plus": store.adjust(minutes: 1)
            case "minus": store.adjust(minutes: -1)
            case "reset": store.resetClock()
            case "entry": store.updatePrizePool { $0.addEntry() }
            case "knockout": store.updatePrizePool { $0.eliminate() }
            case "fullscreen": fullScreen()
            case let c where c.hasPrefix("tab."): selectTab(String(c.dropFirst(4)))
            default: break
            }
        }
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        for command in commands {
            CFNotificationCenterAddObserver(center, nil, { _, _, name, _, _ in
                guard let name = name?.rawValue as String? else { return }
                let command = String(name.dropFirst("ch.kimiyu.Bilby.debug.".count))
                DispatchQueue.main.async { MainActor.assumeIsolated { DebugRemote.handler?(command) } }
            }, "ch.kimiyu.Bilby.debug.\(command)" as CFString, nil, .deliverImmediately)
        }
    }
}
#endif
