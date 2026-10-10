#if DEBUG && os(macOS)
import AppKit

/// Debug builds only: lets scripts drive the app and capture its windows without screen recording permission.
///
///   swift scripts/debug-remote.swift snapshot /tmp/shots   # PNG of every visible window
///   swift scripts/debug-remote.swift toggle | pause | next | previous | plus | minus | restart | reset
///   swift scripts/debug-remote.swift tab:clock | tab:structure | tab:players
enum DebugRemote {
    static let name = Notification.Name("ch.kimiyu.Bilby.debug")

    static func install(store: TournamentStore, selectTab: @escaping @MainActor @Sendable (String) -> Void,
                        openSettings: @escaping @MainActor @Sendable () -> Void,
                        openWindow: @escaping @MainActor @Sendable (String) -> Void) {
        DistributedNotificationCenter.default().addObserver(forName: name, object: nil, queue: .main) { note in
            let command = note.object as? String ?? ""
            let argument = note.userInfo?["argument"] as? String
            MainActor.assumeIsolated {
                switch command {
                case "snapshot": snapshot(into: argument ?? NSTemporaryDirectory())
                case "activate":
                    NSApp.activate()
                    NSApp.windows.first { $0.isVisible && $0.canBecomeMain }?.makeKeyAndOrderFront(nil)
                case "toggle": store.toggle()
                case "pause": if store.isRunning { store.toggle() }
                case "next": store.next()
                case "previous": store.previous()
                case "plus": store.adjust(minutes: 1)
                case "minus": store.adjust(minutes: -1)
                case "restart": store.restartRound()
                case "reset": store.resetClock()
                case "entry": store.updatePrizePool { $0.addEntry() }
                case "rebuy": store.updatePrizePool { $0.addRebuy() }
                case "addon": store.updatePrizePool { $0.addAddOn() }
                case "knockout": store.updatePrizePool { $0.eliminate() }
                case "warning": store.settings.warningSeconds = Int(argument ?? "") ?? 60
                case "settings": openSettings()
                case "bigscreen": openWindow("bigscreen")
                case "fullscreen": BigScreen.shared.show(on: NSScreen.screens.first, openWindow: nil)
                case "windowed": BigScreen.shared.exitFullScreen()
                case let c where c.hasPrefix("tab:"): selectTab(String(c.dropFirst(4)))
                default: break
                }
            }
        }
    }

    private static func snapshot(into directory: String) {
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        for (i, window) in NSApp.windows.enumerated() where window.isVisible {
            guard let number = UInt32(exactly: window.windowNumber) else { continue }
            let name = window.title.isEmpty ? "window-\(i)" : window.title.replacingOccurrences(of: "/", with: "-")
            let url = URL(fileURLWithPath: directory).appending(path: "\(name).png")
            // An app may capture its own windows without screen recording permission. The function is gone
            // from the SDK headers but still in CoreGraphics.
            typealias Capture = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?
            if let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGWindowListCreateImage"),
               let image = unsafeBitCast(symbol, to: Capture.self)(.null, 1 << 3, number, 1 | 8)?
                .takeRetainedValue() {
                try? NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?.write(to: url)
                continue
            }
            guard let view = window.contentView?.superview ?? window.contentView,
                  let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
        }
    }
}
#endif
