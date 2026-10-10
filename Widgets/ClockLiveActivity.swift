import ActivityKit
import SwiftUI
import WidgetKit

@main
struct BilbyWidgets: WidgetBundle {
    var body: some Widget {
        ClockLiveActivity()
    }
}

private enum Palette {
    static let play = Color(red: 0.62, green: 0.71, blue: 0.79)
    static let pause = Color(red: 0.39, green: 0.80, blue: 0.72)
    static let background = Color(red: 0.063, green: 0.075, blue: 0.086)
}

/// The countdown on the Lock Screen and in the Dynamic Island.
struct ClockLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClockActivityAttributes.self) { context in
            LockScreenView(state: context.state, structureName: context.attributes.structureName,
                           isStale: context.isStale)
                .activityBackgroundTint(Palette.background)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let shown = Shown(context.state, isStale: context.isStale)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(shown.title.uppercased())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(shown.accent)
                        Text(shown.detail)
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownText(shown: shown)
                        .font(.title2.weight(.medium))
                        .frame(maxWidth: 100, alignment: .trailing)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        RoundProgress(shown: shown)
                        if let next = shown.next {
                            Text("Next: \(next)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Text(shown.compactTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(shown.accent)
            } compactTrailing: {
                CountdownText(shown: shown)
                    .font(.caption.weight(.medium))
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: shown.isBreak ? "cup.and.saucer.fill" : "timer")
                    .foregroundStyle(shown.accent)
            }
            .keylineTint(shown.accent)
        }
    }
}

/// The round to show. Once the current round has run out (the activity is stale) and the app hasn't
/// updated it yet, it shows the next round instead.
private struct Shown {
    var title: String
    var detail: String
    var ante: String?
    var isBreak: Bool
    var isRunning: Bool
    var start: Date
    var end: Date
    var remaining: TimeInterval
    var next: String?

    init(_ s: ClockActivityAttributes.ContentState, isStale: Bool) {
        if isStale, s.isRunning, let nextTitle = s.nextTitle, let nextEnd = s.nextEndsAt, nextEnd > s.endsAt {
            title = nextTitle
            detail = s.nextDetail ?? ""
            ante = nil
            isBreak = nextTitle == "Break"
            start = s.endsAt
            end = nextEnd
            next = nil
        } else {
            title = s.title
            detail = s.detail
            ante = s.ante
            isBreak = s.isBreak
            start = s.roundStart
            end = s.endsAt
            next = s.nextTitle.map { title in
                title == "Break" ? "Break" : "\(title) · \(s.nextDetail ?? "")"
            }
        }
        isRunning = s.isRunning
        remaining = s.remaining
    }

    var accent: Color { isBreak ? Palette.pause : Palette.play }

    var compactTitle: String {
        isBreak ? "Break" : title.replacingOccurrences(of: "Level ", with: "L")
    }
}

private struct CountdownText: View {
    var shown: Shown

    var body: some View {
        Group {
            if shown.isRunning {
                Text(timerInterval: shown.start...shown.end, countsDown: true)
            } else {
                Text(Duration.seconds(shown.remaining.rounded(.up)), format: .time(pattern: .minuteSecond))
            }
        }
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
    }
}

private struct RoundProgress: View {
    var shown: Shown

    var body: some View {
        if shown.isRunning {
            ProgressView(timerInterval: shown.start...shown.end, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                .tint(shown.accent)
        } else {
            let total = max(1, shown.end.timeIntervalSince(shown.start))
            ProgressView(value: max(0, min(1, 1 - shown.remaining / total)))
                .tint(shown.accent)
        }
    }
}

private struct LockScreenView: View {
    var state: ClockActivityAttributes.ContentState
    var structureName: String
    var isStale: Bool

    var body: some View {
        let shown = Shown(state, isStale: isStale)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(shown.title.uppercased())
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(shown.accent)
                        if !shown.isRunning {
                            Text("PAUSED")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(shown.detail)
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if let ante = shown.ante {
                        Text(ante).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                CountdownText(shown: shown)
                    .font(.system(size: 40, weight: .medium))
                    .frame(maxWidth: 150, alignment: .trailing)
            }
            RoundProgress(shown: shown)
            HStack {
                if let next = shown.next {
                    Text("Next: \(next)")
                }
                Spacer()
                Text(structureName)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(16)
    }
}
