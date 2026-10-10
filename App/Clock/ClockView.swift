import BilbyKit
import SwiftUI

/// The clock face: level, countdown, blinds, progress and what comes next. It scales with its container,
/// from a card in the main window up to a projector. Same layout as the browser version (ClockFace.vue).
struct ClockView: View {
    var snapshot: ClockSnapshot
    var levelCount: Int
    var warning: TimeInterval
    /// Its numbers take turns in the middle of the footer once players have entered.
    var pool: PrizePool?
    /// Drives the turns.
    var now: Date = .now
    /// Shows a full screen button in the top right corner.
    var fullScreen: (() -> Void)?

    var body: some View {
        GeometryReader { geo in
            let theme = ClockTheme.of(snapshot, warning: warning)
            let size = geo.size
            // Everything is sized from one unit, so the layout keeps its proportions at any size. The face is
            // 100 units wide and its contents add up to about 62 high.
            let unit = min(size.width / 100, size.height / 62)
            // Portrait, e.g. a phone held upright: size things from the width.
            let compact = size.height > size.width * 1.1

            VStack(spacing: unit * (compact ? 3 : 1.6)) {
                header(theme, unit: compact ? size.width / 80 : unit)
                VStack(spacing: unit) {
                    Spacer(minLength: 0)
                    countdown(theme, unit: compact ? size.width / 62 : unit)
                    blinds(theme, unit: compact ? size.width / 80 : unit, base: unit)
                    progress(theme, unit: unit)
                    Spacer(minLength: 0)
                }
                footer(theme, unit: compact ? size.width / 66 : unit, compact: compact)
            }
            // A phone's rounded corners need more room than a card in a window.
            .padding(unit * (compact ? 6 : 3))
            .frame(width: size.width, height: size.height)
            .background { theme.background.ignoresSafeArea() }
            .animation(.easeInOut(duration: 0.6), value: theme)
        }
        .environment(\.colorScheme, .dark)
    }

    /// The level on the left, the paused pill in the middle, the full screen button on the right.
    private func header(_ theme: ClockTheme, unit: CGFloat) -> some View {
        ZStack {
            HStack {
                Text(title)
                    .font(.system(size: unit * 4.4, weight: .semibold))
                    .tracking(unit * 0.3)
                    .foregroundStyle(theme.accent)
                    .lineLimit(1)
                Spacer()
                if let fullScreen {
                    Button("Full Screen", systemImage: "arrow.up.left.and.arrow.down.right", action: fullScreen)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .font(.system(size: unit * 2.6, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: unit * 5.3, height: unit * 5.3)
                        .contentShape(.rect)
                        .help("Full screen")
                }
            }
            if let pill {
                Text(pill)
                    .font(.system(size: unit * 2, weight: .bold))
                    .tracking(unit * 0.2)
                    .foregroundStyle(theme.background)
                    .padding(.horizontal, unit * 1.4)
                    .padding(.vertical, unit * 0.5)
                    .background(theme.accent, in: Capsule())
            }
        }
    }

    private var title: String {
        if let level = snapshot.levelNumber { return "LEVEL \(level)" }
        return "BREAK"
    }

    private var pill: String? {
        if snapshot.isFinished { return "FINISHED" }
        if !snapshot.isRunning { return snapshot.hasStarted ? "PAUSED" : "READY" }
        return nil
    }

    private func countdown(_ theme: ClockTheme, unit: CGFloat) -> some View {
        let text = TimeFormat.countdown(snapshot.remaining)
        // h:mm:ss is two characters wider than mm:ss.
        let scale: CGFloat = text.count > 5 ? 0.74 : 1
        return Text(text)
            .font(.system(size: unit * 19 * scale, weight: .medium))
            .monospacedDigit()
            .tracking(-unit * 0.38 * scale)
            .foregroundStyle(theme.primary)
            .opacity(snapshot.isRunning || !snapshot.hasStarted ? 1 : 0.55)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .contentTransition(.numericText(countsDown: true))
            .padding(.bottom, unit * 2)
    }

    @ViewBuilder
    private func blinds(_ theme: ClockTheme, unit: CGFloat, base: CGFloat) -> some View {
        if snapshot.isBreak {
            Text(snapshot.round.note.isEmpty ? "Break" : snapshot.round.note)
                .font(.system(size: unit * 6, weight: .semibold))
                .foregroundStyle(theme.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
        } else {
            VStack(spacing: base * 0.5) {
                Text(snapshot.round.blindsText)
                    .font(.system(size: unit * 8, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(theme.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(snapshot.round.anteText ?? " ")
                    .font(.system(size: unit * 3.4, weight: .medium))
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

    // MARK: Footer

    /// The next level on the left, a stat in the middle that changes every few seconds, the next break on the right.
    private func footer(_ theme: ClockTheme, unit: CGFloat, compact: Bool) -> some View {
        HStack(alignment: .top, spacing: unit * 3) {
            item("NEXT", nextText, theme, unit: unit, alignment: .leading)
                .frame(maxWidth: compact ? nil : .infinity, alignment: .leading)
                .fixedSize(horizontal: compact, vertical: false)
            Group {
                if let stat {
                    item(stat.label, stat.value, currency: stat.currency, theme, unit: unit, alignment: .center)
                        .id(stat.label)
                        .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: unit)),
                                                removal: .opacity.combined(with: .offset(y: -unit))))
                } else {
                    Color.clear.frame(height: 0)
                }
            }
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 0.4), value: stat?.label)
            item("NEXT BREAK", snapshot.untilNextBreak.map(TimeFormat.countdown) ?? "–", theme, unit: unit,
                 alignment: .trailing)
                .frame(maxWidth: compact ? nil : .infinity, alignment: .trailing)
                .fixedSize(horizontal: compact, vertical: false)
        }
    }

    /// A label and its value; money shows its currency first and smaller: "CHF 1’250".
    private func item(_ label: String, _ value: String, currency: String? = nil, _ theme: ClockTheme, unit: CGFloat,
                      alignment: HorizontalAlignment) -> some View {
        let size = unit * 4.2
        return VStack(alignment: alignment, spacing: unit * 0.5) {
            Text(label)
                .font(.system(size: unit * 1.9, weight: .semibold))
                .tracking(unit * 0.19)
                .foregroundStyle(theme.secondary)
                .lineLimit(1)
            Group {
                if let currency {
                    Text("\(Text(currency).font(.system(size: size * 0.6, weight: .medium))) \(value)")
                } else {
                    Text(value)
                }
            }
            .font(.system(size: size, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(theme.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
    }

    private var nextText: String {
        guard let next = snapshot.nextRound else { return "Last level" }
        if next.isBreak { return "Break · \(next.minutes) min" }
        return next.compactText
    }

    /// What takes turns in the middle of the footer: where we are, the players and the money, and what time
    /// things happen.
    private var stats: [Stat] {
        let s = snapshot
        var list: [Stat] = []
        if let level = s.levelNumber { list.append(Stat("LEVELS", "\(level) / \(levelCount)")) }
        if let pool, pool.entries > 0 {
            list.append(Stat("PLAYERS", "\(pool.playersLeft) / \(pool.entries)"))
            if let average = pool.averageStack {
                list.append(Stat("AVERAGE STACK", average.compactChips))
                if !s.isBreak, s.round.bigBlind > 0 {
                    list.append(Stat("AVERAGE IN BB", "\(Int((Double(average) / Double(s.round.bigBlind)).rounded())) BB"))
                }
            }
            if pool.total > 0 {
                list.append(.money("PRIZE POOL", pool.total, pool.currency))
                list.append(.money("FIRST PLACE", pool.payouts().first ?? 0, pool.currency))
            }
            list.append(Stat("CHIPS IN PLAY", pool.chipsInPlay.compactChips))
        }
        if s.isRunning, let endsAt = s.endsAt {
            list.append(Stat(s.isBreak ? "BREAK ENDS AT" : "LEVEL ENDS AT", endsAt.formatted(date: .omitted, time: .shortened)))
            if let untilBreak = s.untilNextBreak {
                list.append(Stat("BREAK AT", now.addingTimeInterval(untilBreak).formatted(date: .omitted, time: .shortened)))
            }
        }
        return list
    }

    /// Each stat stays for a few seconds. Counted from the clock, so every window shows the same one.
    private static let statSeconds = 12.0

    private var stat: Stat? {
        let list = stats
        guard !list.isEmpty else { return nil }
        let turn = Int((now.timeIntervalSince1970 / Self.statSeconds).rounded(.down))
        return list[turn % list.count]
    }

    private struct Stat {
        var label: String
        var value: String
        /// Set for money, which shows its currency first and smaller.
        var currency: String?

        init(_ label: String, _ value: String, currency: String? = nil) {
            self.label = label
            self.value = value
            self.currency = currency
        }

        static func money(_ label: String, _ amount: Decimal, _ currency: String) -> Stat {
            let parts = Money.parts(amount, currency)
            return Stat(label, parts.number, currency: parts.currency.isEmpty ? nil : parts.currency)
        }
    }
}

/// The clock face, redrawn several times a second from the store.
struct LiveClockView: View {
    @Environment(TournamentStore.self) private var store
    /// Shows a full screen button in the corner of the clock.
    var fullScreen: (() -> Void)?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { context in
            ClockView(snapshot: store.snapshot(at: context.date), levelCount: store.structure.levelCount,
                      warning: store.settings.warning,
                      pool: store.tournament.prizePool, now: context.date, fullScreen: fullScreen)
        }
    }
}
