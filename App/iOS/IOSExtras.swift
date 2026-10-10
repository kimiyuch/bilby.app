#if os(iOS)
import ActivityKit
import BilbyKit
import UIKit
import UserNotifications
import os

/// Keeps the phone or iPad awake, the Live Activity current and the notifications scheduled.
/// Everything follows the store: it runs again after every change to the tournament or the settings.
final class IOSExtras {
    private let liveActivity = LiveActivityController()
    private let notifications = NotificationScheduler()

    init(store: TournamentStore) {
        store.observe { [liveActivity, notifications] store in
            UIApplication.shared.isIdleTimerDisabled = store.isRunning
            liveActivity.update(from: store)
            notifications.reschedule(from: store)
        }
    }
}

// MARK: - Live Activity

final class LiveActivityController {
    private var activity: Activity<ClockActivityAttributes>?
    private var lastState: ClockActivityAttributes.ContentState?
    private static let log = Logger(subsystem: "ch.kimiyu.Bilby", category: "live-activity")

    init() {
        // Pick up the activity from before a relaunch instead of starting a second one.
        activity = Activity<ClockActivityAttributes>.activities.first
        for extra in Activity<ClockActivityAttributes>.activities.dropFirst() {
            Self.end(id: extra.id)
        }
    }

    func update(from store: TournamentStore) {
        let now = Date.now
        let s = store.snapshot(at: now)
        guard s.hasStarted, !s.isFinished else {
            end()
            return
        }
        let state = Self.state(for: s, structure: store.structure, now: now)
        guard state != lastState else { return }
        lastState = state
        // Once the round runs out the widget shows the next one by itself (see `Shown` in the extension).
        let content = ActivityContent(state: state, staleDate: s.isRunning ? state.endsAt : nil)

        if let activity, activity.activityState == .active || activity.activityState == .stale {
            let id = activity.id
            Task.detached { await Self.find(id)?.update(content) }
        } else {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            do {
                activity = try Activity.request(
                    attributes: ClockActivityAttributes(structureName: store.structure.name), content: content)
            } catch {
                Self.log.error("Couldn't start the Live Activity: \(error)")
            }
        }
    }

    private func end() {
        lastState = nil
        guard let activity else { return }
        self.activity = nil
        Self.end(id: activity.id)
    }

    // Activities aren't Sendable, so tasks look them up by ID instead of capturing them.
    nonisolated private static func find(_ id: String) -> Activity<ClockActivityAttributes>? {
        Activity<ClockActivityAttributes>.activities.first { $0.id == id }
    }

    private static func end(id: String) {
        Task.detached { await find(id)?.end(nil, dismissalPolicy: .immediate) }
    }

    static func state(for s: ClockSnapshot, structure: Structure, now: Date) -> ClockActivityAttributes.ContentState {
        let endsAt = s.endsAt ?? now.addingTimeInterval(s.remaining)
        let next = s.nextRound
        return .init(
            title: s.levelNumber.map { "Level \($0)" } ?? "Break",
            detail: s.isBreak ? (s.round.note.isEmpty ? "\(s.round.minutes) minutes" : s.round.note) : s.round.blindsText,
            ante: s.round.anteText,
            isBreak: s.isBreak,
            isRunning: s.isRunning,
            roundStart: endsAt.addingTimeInterval(-s.round.duration),
            endsAt: endsAt,
            remaining: s.remaining,
            nextTitle: next.map { $0.isBreak ? "Break" : "Level \(s.nextLevelNumber ?? 0)" },
            nextDetail: next.map { $0.isBreak ? ($0.note.isEmpty ? "\($0.minutes) minutes" : $0.note) : $0.shortText },
            nextEndsAt: next.map { endsAt.addingTimeInterval($0.duration) })
    }
}

// MARK: - Notifications

/// Schedules a local notification for every level change, break and warning ahead of time, so they
/// arrive while Bilby is in the background. They're rescheduled whenever the clock changes.
final class NotificationScheduler: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private var lastSchedule: [String] = []
    private var asked = false

    override init() {
        super.init()
        center.delegate = self
    }

    func reschedule(from store: TournamentStore) {
        let now = Date.now
        let settings = store.settings
        let events = store.tournament.clock.upcomingEvents(in: store.structure, at: now, warning: settings.warning, limit: 60)
        let sound: UNNotificationSound? = settings.muted ? nil : .default

        var requests: [UNNotificationRequest] = []
        for event in events {
            let (chime, text) = Alerts.alert(for: event, in: store.structure, settings: settings)
            let content = UNMutableNotificationContent()
            content.title = title(for: event, in: store.structure)
            content.body = text
            content.interruptionLevel = .timeSensitive
            content.sound = chime == .none ? nil : (SoundFiles.notificationSound(for: chime) ?? sound)
            if settings.muted { content.sound = nil }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, event.date.timeIntervalSince(now)), repeats: false)
            requests.append(UNNotificationRequest(identifier: "bilby-\(Int(event.date.timeIntervalSince1970))-\(event.roundIndex)-\(event.kind)",
                                                  content: content, trigger: trigger))
        }

        // Rounding the dates keeps the same schedule from being redone every second.
        let signature = requests.map { "\($0.identifier) \($0.content.body) \($0.content.sound == nil)" }
        guard signature != lastSchedule else { return }
        lastSchedule = signature
        // Removing and adding go through the center in order, so a newer schedule always replaces an older one.
        center.removeAllPendingNotificationRequests()
        for request in requests { center.add(request) { _ in } }
        if !asked, !requests.isEmpty {
            asked = true
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    private func title(for event: ClockEvent, in structure: Structure) -> String {
        switch event.kind {
        case .warning: structure.levelNumber(at: event.roundIndex).map { "Level \($0) is ending" } ?? "The break is ending"
        case .roundStarted: structure.levelNumber(at: event.roundIndex).map { "Level \($0)" } ?? "Break"
        case .finished: "Last level over"
        }
    }

    /// While Bilby is open, it plays its own sounds; the notification would only double them.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification)
        async -> UNNotificationPresentationOptions {
        []
    }
}
#endif
