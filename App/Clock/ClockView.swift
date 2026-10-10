import BilbyKit
import SwiftUI

/// The clock face: level, blinds, countdown, progress and what comes next. It scales with its container,
/// from a pane in the main window up to a projector.
struct ClockView: View {
    var snapshot: ClockSnapshot
    var structureName: String
    var warning: TimeInterval
    /// Shown in a second footer row once players have entered.
    var pool: PrizePool?

    var body: some View {
        GeometryReader { geo in
            let theme = ClockTheme.of(snapshot, warning: warning)
            let size = geo.size
            // Everything is sized from one unit, so the layout keeps its proportions at any size.
            let unit = min(size.width / 100, size.height / 62)
            let compact = size.height > size.width * 1.1

            VStack(spacing: unit * (compact ? 3 : 1.6)) {
                header(theme, unit: unit)
                Spacer(minLength: 0)
                countdown(theme, unit: compact ? size.width / 62 : unit)
                blinds(theme, unit: compact ? size.width / 80 : unit)
                progress(theme, unit: unit)
                Spacer(minLength: 0)
                footer(theme, unit: compact ? size.width / 90 : unit, stacked: compact)
            }
            .padding(.horizontal, unit * 5)
            .padding(.vertical, unit * 4)
            .frame(width: size.width, height: size.height)
            .background(theme.background)
            .animation(.easeInOut(duration: 0.6), value: theme)
        }
        .environment(\.colorScheme, .dark)
    }

    private func header(_ theme: ClockTheme, unit: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: unit * 4.4, weight: .semibold))
                .tracking(unit * 0.3)
                .foregroundStyle(theme.accent)
            Spacer()
            if snapshot.isFinished {
                pill("FINISHED", theme, unit: unit)
            } else if !snapshot.isRunning {
                pill(snapshot.hasStarted ? "PAUSED" : "READY", theme, unit: unit)
            }
            Text(structureName)
                .font(.system(size: unit * 2.4, weight: .medium))
                .foregroundStyle(theme.secondary)
                .lineLimit(1)
        }
    }

    private var title: String {
        if let level = snapshot.levelNumber { return "LEVEL \(level)" }
        return "BREAK"
    }

    private func pill(_ text: String, _ theme: ClockTheme, unit: CGFloat) -> some View {
        Text(text)
            .font(.system(size: unit * 2, weight: .bold))
            .tracking(unit * 0.2)
            .foregroundStyle(theme.background)
            .padding(.horizontal, unit * 1.4)
            .padding(.vertical, unit * 0.5)
            .background(theme.accent, in: Capsule())
            .padding(.trailing, unit)
    }

    private func countdown(_ theme: ClockTheme, unit: CGFloat) -> some View {
        let text = TimeFormat.countdown(snapshot.remaining)
        // h:mm:ss is two characters wider than mm:ss.
        let scale: CGFloat = text.count > 5 ? 0.74 : 1
        return Text(text)
            .font(.system(size: unit * 30 * scale, weight: .medium))
            .monospacedDigit()
            .tracking(-unit * 0.4)
            .foregroundStyle(theme.primary)
            .opacity(snapshot.isRunning || !snapshot.hasStarted ? 1 : 0.55)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .contentTransition(.numericText(countsDown: true))
    }

    @ViewBuilder
    private func blinds(_ theme: ClockTheme, unit: CGFloat) -> some View {
        if snapshot.isBreak {
            Text(snapshot.round.note.isEmpty ? "Break" : snapshot.round.note)
                .font(.system(size: unit * 6.5, weight: .semibold))
                .foregroundStyle(theme.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
        } else {
            VStack(spacing: unit * 0.6) {
                Text(snapshot.round.blindsText)
                    .font(.system(size: unit * 10, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(theme.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(snapshot.round.anteText ?? " ")
                    .font(.system(size: unit * 4.2, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(theme.secondary)
            }
        }
    }

    private func progress(_ theme: ClockTheme, unit: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.track)
                Capsule().fill(theme.accent)
                    .frame(width: max(geo.size.height, geo.size.width * snapshot.progress))
            }
        }
        .frame(height: max(4, unit * 1.1))
        .padding(.top, unit)
    }

    private func footer(_ theme: ClockTheme, unit: CGFloat, stacked: Bool) -> some View {
        var items = [
            ("NEXT", nextText),
            ("NEXT BREAK", snapshot.untilNextBreak.map(TimeFormat.countdown) ?? "–"),
            ("ELAPSED", TimeFormat.elapsed(snapshot.elapsed)),
        ]
        if let pool, pool.entries > 0 {
            items += [
                ("PLAYERS", "\(pool.playersLeft) / \(pool.entries)"),
                ("AVERAGE STACK", pool.averageStack?.chips ?? "–"),
                ("PRIZE POOL", Money.format(pool.total, pool.currency)),
            ]
        }
        let columns = stacked ? 2 : 3
        let rows = stride(from: 0, to: items.count, by: columns).map { Array(items[$0..<min($0 + columns, items.count)]) }
        return Grid(alignment: .leading, horizontalSpacing: unit * 3, verticalSpacing: unit * 2.2) {
            ForEach(rows.indices, id: \.self) { r in
                GridRow {
                    ForEach(rows[r], id: \.0) { label, value in
                        VStack(alignment: .leading, spacing: unit * 0.5) {
                            Text(label)
                                .font(.system(size: unit * 1.9, weight: .semibold))
                                .tracking(unit * 0.2)
                                .foregroundStyle(theme.secondary)
                            Text(value)
                                .font(.system(size: unit * 3.8, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(theme.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nextText: String {
        guard let next = snapshot.nextRound else { return "Last level" }
        if next.isBreak { return "Break · \(next.minutes) min" }
        return next.shortText
    }
}

/// The clock face, redrawn several times a second from the store.
struct LiveClockView: View {
    @Environment(TournamentStore.self) private var store
    var warning: TimeInterval = 60

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { context in
            ClockView(snapshot: store.snapshot(at: context.date), structureName: store.structure.name, warning: warning,
                      pool: store.tournament.prizePool)
        }
    }
}
