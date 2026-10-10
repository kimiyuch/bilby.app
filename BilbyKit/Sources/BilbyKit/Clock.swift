import Foundation

/// The tournament clock.
///
/// A running clock only stores the date its current round ends, never a counter that ticks down, so it is
/// correct after sleep, a relaunch or time in the background. Every read takes `now` and first catches up
/// over any rounds that ended in the meantime.
public struct Clock: Codable, Equatable, Sendable {
    public enum Mode: Codable, Equatable, Sendable {
        case paused(remaining: TimeInterval)
        case running(endsAt: Date)
    }

    public private(set) var roundIndex: Int
    public private(set) var mode: Mode
    public private(set) var hasStarted: Bool
    /// The last round ran out.
    public private(set) var isFinished: Bool
    /// Running time before the current run.
    private var elapsedBefore: TimeInterval
    private var runningSince: Date?

    public init(structure: Structure) {
        roundIndex = 0
        mode = .paused(remaining: structure.rounds.first?.duration ?? 0)
        hasStarted = false
        isFinished = false
        elapsedBefore = 0
        runningSince = nil
    }

    public var isRunning: Bool {
        if case .running = mode { return true }
        return false
    }

    // MARK: Reading

    /// The clock as of `now`, with any rounds that ended in the meantime skipped.
    public func caughtUp(in structure: Structure, at now: Date) -> Clock {
        var clock = self
        clock.catchUp(in: structure, at: now)
        return clock
    }

    public func remaining(at now: Date) -> TimeInterval {
        switch mode {
        case .paused(let remaining): remaining
        case .running(let endsAt): max(0, endsAt.timeIntervalSince(now))
        }
    }

    /// Time the clock has been running, pauses excluded.
    public func elapsed(at now: Date) -> TimeInterval {
        elapsedBefore + (runningSince.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    /// When the display next changes: the countdown's next second while the clock runs, the next second of the
    /// time of day while it's paused. Ticking then keeps every second on screen equally long.
    public func nextSecond(in structure: Structure, after now: Date) -> Date {
        let clock = caughtUp(in: structure, at: now)
        let toward = clock.isRunning ? clock.remaining(at: now) : -now.timeIntervalSince1970
        let left = toward - toward.rounded(.down)
        return now.addingTimeInterval(left == 0 ? 1 : left)
    }

    public func snapshot(in structure: Structure, at now: Date) -> ClockSnapshot {
        ClockSnapshot(clock: caughtUp(in: structure, at: now), structure: structure, now: now)
    }

    // MARK: Controls

    public mutating func start(in structure: Structure, at now: Date) {
        catchUp(in: structure, at: now)
        guard case .paused(let remaining) = mode, !isFinished, !structure.rounds.isEmpty else { return }
        mode = .running(endsAt: now.addingTimeInterval(remaining))
        runningSince = now
        hasStarted = true
        catchUp(in: structure, at: now)
    }

    public mutating func pause(in structure: Structure, at now: Date) {
        catchUp(in: structure, at: now)
        guard case .running(let endsAt) = mode else { return }
        stopRunning(at: now)
        mode = .paused(remaining: max(0, endsAt.timeIntervalSince(now)))
    }

    public mutating func toggle(in structure: Structure, at now: Date) {
        if caughtUp(in: structure, at: now).isRunning {
            pause(in: structure, at: now)
        } else {
            start(in: structure, at: now)
        }
    }

    public mutating func next(in structure: Structure, at now: Date) {
        catchUp(in: structure, at: now)
        guard roundIndex + 1 < structure.rounds.count else { return }
        jump(to: roundIndex + 1, in: structure, at: now)
    }

    public mutating func previous(in structure: Structure, at now: Date) {
        catchUp(in: structure, at: now)
        guard roundIndex > 0 else { return }
        jump(to: roundIndex - 1, in: structure, at: now)
    }

    /// Starts the round at `index` from the top, keeping the clock running or paused as it was.
    public mutating func jump(to index: Int, in structure: Structure, at now: Date) {
        catchUp(in: structure, at: now)
        guard structure.rounds.indices.contains(index) else { return }
        roundIndex = index
        isFinished = false
        setRemaining(structure.rounds[index].duration, at: now)
    }

    public mutating func restartRound(in structure: Structure, at now: Date) {
        jump(to: roundIndex, in: structure, at: now)
    }

    /// Adds or removes time from the current round. Taking it below zero ends the round.
    public mutating func adjust(by seconds: TimeInterval, in structure: Structure, at now: Date) {
        catchUp(in: structure, at: now)
        guard !structure.rounds.isEmpty else { return }
        if isFinished {
            guard seconds > 0 else { return }
            isFinished = false
        }
        setRemaining(max(0, remaining(at: now) + seconds), at: now)
        catchUp(in: structure, at: now)
    }

    /// Back to the first level, stopped.
    public mutating func reset(structure: Structure) {
        self = Clock(structure: structure)
    }

    /// Keeps the clock on the same round after the structure was edited: follows the round if it moved,
    /// and adds or removes the difference if its duration changed.
    public mutating func structureChanged(from old: Structure, to new: Structure, at now: Date) {
        catchUp(in: old, at: now)
        guard !new.rounds.isEmpty else { return }
        let current = old.rounds.indices.contains(roundIndex) ? old.rounds[roundIndex] : nil
        if let current, let index = new.rounds.firstIndex(where: { $0.id == current.id }) {
            roundIndex = index
            let change = new.rounds[index].duration - current.duration
            if change != 0 {
                if isFinished, change > 0 { isFinished = false }
                setRemaining(max(0, remaining(at: now) + change), at: now)
            }
        } else {
            // The current round was deleted: carry on with whatever is in its place.
            roundIndex = min(roundIndex, new.rounds.count - 1)
            isFinished = false
            setRemaining(new.rounds[roundIndex].duration, at: now)
        }
        if !hasStarted { setRemaining(new.rounds[roundIndex].duration, at: now) }
        catchUp(in: new, at: now)
    }

    // MARK: Events

    /// Everything that will happen while the clock keeps running, in order, starting after `now`.
    /// Used for sounds in the app and for scheduling notifications ahead of time.
    public func upcomingEvents(in structure: Structure, at now: Date, warning: TimeInterval,
                               limit: Int = 200) -> [ClockEvent] {
        let clock = caughtUp(in: structure, at: now)
        guard case .running(var endsAt) = clock.mode else { return [] }
        var events: [ClockEvent] = []
        var index = clock.roundIndex
        while events.count < limit {
            let round = structure.rounds[index]
            let warnAt = endsAt.addingTimeInterval(-warning)
            if warning > 0, warning < round.duration, warnAt > now {
                events.append(ClockEvent(date: warnAt, kind: .warning, roundIndex: index))
            }
            guard index + 1 < structure.rounds.count else {
                events.append(ClockEvent(date: endsAt, kind: .finished, roundIndex: index))
                break
            }
            index += 1
            events.append(ClockEvent(date: endsAt, kind: .roundStarted, roundIndex: index))
            endsAt = endsAt.addingTimeInterval(structure.rounds[index].duration)
        }
        return Array(events.prefix(limit))
    }

    // MARK: Internals

    private mutating func setRemaining(_ remaining: TimeInterval, at now: Date) {
        switch mode {
        case .running: mode = .running(endsAt: now.addingTimeInterval(remaining))
        case .paused: mode = .paused(remaining: remaining)
        }
    }

    private mutating func stopRunning(at date: Date) {
        if let runningSince { elapsedBefore += max(0, date.timeIntervalSince(runningSince)) }
        runningSince = nil
    }

    /// Moves past every round that has ended by `now`. After the last round the clock stops.
    private mutating func catchUp(in structure: Structure, at now: Date) {
        guard !structure.rounds.isEmpty else { return }
        if roundIndex >= structure.rounds.count { roundIndex = structure.rounds.count - 1 }
        guard case .running(var endsAt) = mode else { return }
        while endsAt <= now {
            if roundIndex + 1 < structure.rounds.count {
                roundIndex += 1
                endsAt = endsAt.addingTimeInterval(structure.rounds[roundIndex].duration)
            } else {
                stopRunning(at: endsAt)
                mode = .paused(remaining: 0)
                isFinished = true
                return
            }
        }
        mode = .running(endsAt: endsAt)
    }
}

public struct ClockEvent: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// The round at `roundIndex` is about to end.
        case warning
        /// The round at `roundIndex` just began.
        case roundStarted
        /// The last round, at `roundIndex`, ran out.
        case finished
    }

    public var date: Date
    public var kind: Kind
    public var roundIndex: Int
}

/// Everything the clock screen shows, computed for one moment.
public struct ClockSnapshot: Equatable, Sendable {
    public var roundIndex: Int
    public var round: Round
    /// Nil during a break.
    public var levelNumber: Int?
    public var remaining: TimeInterval
    public var endsAt: Date?
    /// How much of the round has passed, 0 to 1.
    public var progress: Double
    public var isRunning: Bool
    public var hasStarted: Bool
    public var isFinished: Bool
    /// The round after this one, level or break.
    public var nextRound: Round?
    /// The next round that is a level.
    public var nextLevel: Round?
    public var nextLevelNumber: Int?
    /// Time until the next break starts, if there is one.
    public var untilNextBreak: TimeInterval?
    public var elapsed: TimeInterval

    init(clock: Clock, structure: Structure, now: Date) {
        let rounds = structure.rounds
        let index = rounds.isEmpty ? 0 : min(clock.roundIndex, rounds.count - 1)
        let round = rounds.isEmpty ? Round.pause(minutes: 0) : rounds[index]
        roundIndex = index
        self.round = round
        levelNumber = structure.levelNumber(at: index)
        remaining = clock.remaining(at: now)
        if case .running(let endsAt) = clock.mode { self.endsAt = endsAt } else { endsAt = nil }
        progress = round.duration > 0 ? min(1, max(0, 1 - remaining / round.duration)) : 1
        isRunning = clock.isRunning
        hasStarted = clock.hasStarted
        isFinished = clock.isFinished
        elapsed = clock.elapsed(at: now)

        let later = rounds.indices.contains(index + 1) ? Array(rounds[(index + 1)...]) : []
        nextRound = later.first
        if let offset = later.firstIndex(where: { !$0.isBreak }) {
            nextLevel = later[offset]
            nextLevelNumber = structure.levelNumber(at: index + 1 + offset)
        }
        if let breakOffset = later.firstIndex(where: \.isBreak) {
            untilNextBreak = remaining + later[..<breakOffset].reduce(0) { $0 + $1.duration }
        }
    }

    public var isBreak: Bool { round.isBreak }
}
