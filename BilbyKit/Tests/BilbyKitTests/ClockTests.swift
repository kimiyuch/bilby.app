import Foundation
import Testing
@testable import BilbyKit

private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

/// Level 1 (10 min), level 2 (10 min), break (5 min), level 3 (10 min).
private let structure = Structure(name: "Test", rounds: [
    .level(25, 50, minutes: 10),
    .level(50, 100, minutes: 10),
    .pause(minutes: 5, note: "Color up the 25s"),
    .level(100, 200, ante: 200, minutes: 10),
])

private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

@Suite struct ClockTests {
    @Test func startsPausedOnFirstLevel() {
        let s = Clock(structure: structure).snapshot(in: structure, at: t0)
        #expect(s.roundIndex == 0)
        #expect(s.levelNumber == 1)
        #expect(s.remaining == 600)
        #expect(!s.isRunning && !s.hasStarted)
        #expect(s.nextLevel?.bigBlind == 100)
        #expect(s.untilNextBreak == 1200)
    }

    @Test func countsDownFromTheEndDate() {
        var clock = Clock(structure: structure)
        clock.start(in: structure, at: t0)
        let s = clock.snapshot(in: structure, at: at(90))
        #expect(s.remaining == 510)
        #expect(s.endsAt == at(600))
        #expect(abs(s.progress - 0.15) < 1e-9)
        #expect(s.elapsed == 90)
    }

    @Test func nextSecondFollowsTheCountdown() {
        var clock = Clock(structure: structure)
        clock.start(in: structure, at: at(0.4))
        #expect(abs(clock.nextSecond(in: structure, after: at(1)).timeIntervalSince(at(1.4))) < 1e-6)
        #expect(abs(clock.nextSecond(in: structure, after: at(1.4)).timeIntervalSince(at(2.4))) < 1e-6)
    }

    @Test func nextSecondFollowsTheTimeOfDayWhilePaused() {
        let clock = Clock(structure: structure)
        #expect(abs(clock.nextSecond(in: structure, after: at(0.25)).timeIntervalSince(at(1))) < 1e-6)
        #expect(abs(clock.nextSecond(in: structure, after: t0).timeIntervalSince(at(1))) < 1e-6)
    }

    @Test func pauseFreezesTimeAndResumeContinues() {
        var clock = Clock(structure: structure)
        clock.start(in: structure, at: t0)
        clock.pause(in: structure, at: at(100))
        #expect(clock.snapshot(in: structure, at: at(5000)).remaining == 500)
        #expect(clock.elapsed(at: at(5000)) == 100)
        clock.start(in: structure, at: at(5000))
        let s = clock.snapshot(in: structure, at: at(5100))
        #expect(s.remaining == 400)
        #expect(s.elapsed == 200)
    }

    @Test func catchesUpAfterSleepOrRelaunch() throws {
        var clock = Clock(structure: structure)
        clock.start(in: structure, at: t0)
        // Saved and restored, then read 23 minutes later: into the break.
        let restored = try JSONDecoder().decode(Clock.self, from: JSONEncoder().encode(clock))
        let s = restored.snapshot(in: structure, at: at(23 * 60))
        #expect(s.roundIndex == 2)
        #expect(s.isBreak)
        #expect(s.levelNumber == nil)
        #expect(s.remaining == 120)
        #expect(s.nextLevelNumber == 3)
        #expect(s.isRunning)
    }

    @Test func stopsAfterTheLastRound() {
        var clock = Clock(structure: structure)
        clock.start(in: structure, at: t0)
        let s = clock.snapshot(in: structure, at: at(10_000))
        #expect(s.roundIndex == 3)
        #expect(s.isFinished)
        #expect(!s.isRunning)
        #expect(s.remaining == 0)
        #expect(s.elapsed == 35 * 60)
        // Starting again does nothing until time is added.
        var c = clock.caughtUp(in: structure, at: at(10_000))
        c.start(in: structure, at: at(10_000))
        #expect(!c.isRunning)
        c.adjust(by: 60, in: structure, at: at(10_000))
        c.start(in: structure, at: at(10_000))
        #expect(c.snapshot(in: structure, at: at(10_030)).remaining == 30)
    }

    @Test func nextAndPreviousStartRoundsFresh() {
        var clock = Clock(structure: structure)
        clock.start(in: structure, at: t0)
        clock.next(in: structure, at: at(200))
        var s = clock.snapshot(in: structure, at: at(200))
        #expect(s.roundIndex == 1 && s.remaining == 600 && s.isRunning)
        clock.previous(in: structure, at: at(260))
        s = clock.snapshot(in: structure, at: at(260))
        #expect(s.roundIndex == 0 && s.remaining == 600)
        clock.previous(in: structure, at: at(260))
        #expect(clock.roundIndex == 0)

        var paused = Clock(structure: structure)
        paused.next(in: structure, at: t0)
        #expect(paused.snapshot(in: structure, at: at(999)).remaining == 600)
        #expect(!paused.isRunning)
        for _ in 0..<10 { paused.next(in: structure, at: t0) }
        #expect(paused.roundIndex == 3)
    }

    @Test func adjustAddsAndRemovesTime() {
        var clock = Clock(structure: structure)
        clock.start(in: structure, at: t0)
        clock.adjust(by: 60, in: structure, at: at(30))
        #expect(clock.snapshot(in: structure, at: at(30)).remaining == 630)
        clock.adjust(by: -60, in: structure, at: at(30))
        clock.adjust(by: -60, in: structure, at: at(30))
        #expect(clock.snapshot(in: structure, at: at(30)).remaining == 510)
        // Removing more than is left ends the level.
        clock.adjust(by: -600, in: structure, at: at(30))
        let s = clock.snapshot(in: structure, at: at(30))
        #expect(s.roundIndex == 1 && s.remaining == 600)

        var paused = Clock(structure: structure)
        paused.adjust(by: -900, in: structure, at: t0)
        #expect(paused.remaining(at: t0) == 0)
        #expect(paused.roundIndex == 0)
    }

    @Test func restartRound() {
        var clock = Clock(structure: structure)
        clock.start(in: structure, at: t0)
        clock.restartRound(in: structure, at: at(400))
        #expect(clock.snapshot(in: structure, at: at(400)).remaining == 600)
    }

    @Test func toggle() {
        var clock = Clock(structure: structure)
        clock.toggle(in: structure, at: t0)
        #expect(clock.isRunning)
        clock.toggle(in: structure, at: at(10))
        #expect(!clock.isRunning)
        #expect(clock.remaining(at: at(99)) == 590)
    }

    @Test func untilNextBreak() {
        var clock = Clock(structure: structure)
        clock.start(in: structure, at: t0)
        #expect(clock.snapshot(in: structure, at: at(60)).untilNextBreak == 1140)
        // In the break and after it there is no further break.
        #expect(clock.snapshot(in: structure, at: at(1300)).untilNextBreak == nil)
    }

    @Test func followsTheRoundWhenTheStructureIsEdited() {
        var clock = Clock(structure: structure)
        clock.start(in: structure, at: t0)
        clock.next(in: structure, at: at(60))  // level 2, ends at 660
        var edited = structure
        edited.rounds.insert(.level(10, 20, minutes: 10), at: 0)
        edited.rounds[2].minutes = 12  // level 2 is now two minutes longer
        clock.structureChanged(from: structure, to: edited, at: at(120))
        let s = clock.snapshot(in: edited, at: at(120))
        #expect(s.roundIndex == 2)
        #expect(s.round.bigBlind == 100)
        #expect(s.remaining == 540 + 120)

        // Deleting the current round carries on with the next one, from the top.
        var shorter = edited
        shorter.rounds.remove(at: 2)
        clock.structureChanged(from: edited, to: shorter, at: at(120))
        let t = clock.snapshot(in: shorter, at: at(120))
        #expect(t.isBreak && t.remaining == 300)
    }

    @Test func editsBeforeStartUseTheNewDuration() {
        var clock = Clock(structure: structure)
        var edited = structure
        edited.rounds[0].minutes = 15
        clock.structureChanged(from: structure, to: edited, at: t0)
        #expect(clock.remaining(at: t0) == 900)
    }

    @Test func upcomingEvents() {
        var clock = Clock(structure: structure)
        #expect(clock.upcomingEvents(in: structure, at: t0, warning: 60).isEmpty)
        clock.start(in: structure, at: t0)
        let events = clock.upcomingEvents(in: structure, at: at(30), warning: 60)
        #expect(events == [
            ClockEvent(date: at(540), kind: .warning, roundIndex: 0),
            ClockEvent(date: at(600), kind: .roundStarted, roundIndex: 1),
            ClockEvent(date: at(1140), kind: .warning, roundIndex: 1),
            ClockEvent(date: at(1200), kind: .roundStarted, roundIndex: 2),
            ClockEvent(date: at(1440), kind: .warning, roundIndex: 2),
            ClockEvent(date: at(1500), kind: .roundStarted, roundIndex: 3),
            ClockEvent(date: at(2040), kind: .warning, roundIndex: 3),
            ClockEvent(date: at(2100), kind: .finished, roundIndex: 3),
        ])
        // Past the first warning, it is no longer listed.
        #expect(clock.upcomingEvents(in: structure, at: at(550), warning: 60).first?.kind == .roundStarted)
        #expect(clock.upcomingEvents(in: structure, at: t0, warning: 60, limit: 3).count == 3)
    }
}
