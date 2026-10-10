import Foundation
import Testing
@testable import BilbyKit

@Suite struct PrizePoolTests {
    private func pool(entries: Int, rebuys: Int = 0, addOns: Int = 0) -> PrizePool {
        var p = PrizePool(currency: "CHF", buyIn: 20, rebuy: 20, addOn: 10, fee: 2,
                          startingStack: 10_000, rebuyStack: 10_000, addOnStack: 5_000)
        for _ in 0..<entries { p.addEntry() }
        for _ in 0..<rebuys { p.addRebuy() }
        for _ in 0..<addOns { p.addAddOn() }
        return p
    }

    @Test func totals() {
        var p = pool(entries: 9, rebuys: 3, addOns: 5)
        #expect(p.total == Decimal(290))
        #expect(p.fees == 18)
        #expect(p.chipsInPlay == 9 * 10_000 + 3 * 10_000 + 5 * 5_000)
        #expect(p.playersLeft == 9)
        p.eliminate()
        p.eliminate()
        #expect(p.playersLeft == 7)
        #expect(p.averageStack == 145_000 / 7)
    }

    @Test func counterLimits() {
        var p = pool(entries: 2)
        p.reinstate()
        #expect(p.playersLeft == 2)
        for _ in 0..<5 { p.eliminate() }
        #expect(p.playersLeft == 0)
        #expect(p.averageStack == nil)
        p.reinstate()
        p.removeEntry()
        p.removeEntry()
        p.removeEntry()
        #expect(p.entries == 0 && p.playersLeft == 0)
        p.removeRebuy()
        #expect(p.rebuys == 0)
    }

    @Test func tableRowsAddUpToAHundred() {
        for row in PayoutTable.rows {
            #expect(row.percentages.reduce(0, +) == 100)
            #expect(row.percentages == row.percentages.sorted(by: >))
        }
        #expect(PayoutTable.percentages(forEntries: 0) == [100])
        #expect(PayoutTable.percentages(forEntries: 10).count == 2)
        #expect(PayoutTable.percentages(forEntries: 11).count == 3)
        #expect(PayoutTable.percentages(forEntries: 500).count == 10)
    }

    @Test func payoutsAddUpToThePool() {
        for entries in [1, 6, 9, 13, 20, 33, 47, 80, 150] {
            let p = pool(entries: entries, rebuys: entries / 3)
            let payouts = p.payouts()
            #expect(payouts.reduce(0, +) == p.total, "\(entries) entries")
            #expect(payouts == payouts.sorted(by: >), "\(entries) entries")
        }
    }

    @Test func payoutsRoundToTheUnit() {
        // 13 entries × 20 = 260: 50/30/20 → 130/78/52.
        let p = pool(entries: 13)
        #expect(p.payouts() == [130, 78, 52])
        #expect(p.payouts(roundingTo: 5) == [135, 75, 50])
        // 47 entries × 20 = 940, rounded to 5 below first place.
        let big = pool(entries: 47).payouts()
        #expect(big.dropFirst().allSatisfy { NSDecimalNumber(decimal: $0).intValue % 5 == 0 })
    }

    @Test func customPayouts() {
        var p = pool(entries: 10)
        p.customPayouts = [60, 30, 10]
        #expect(p.payouts() == [120, 60, 20])
        // Percentages that don't add up to 100 are scaled.
        p.customPayouts = [2, 1, 1]
        #expect(p.payouts() == [100, 50, 50])
        #expect(pool(entries: 0).payouts() == [0])
    }

    @Test func currencyFromLocaleOrTimeZone() {
        let zurich = TimeZone(identifier: "Europe/Zurich")!
        #expect(PrizePool.currency(locale: Locale(identifier: "de_CH"), timeZone: zurich) == "CHF")
        #expect(PrizePool.currency(locale: Locale(identifier: "en_US"), timeZone: zurich) == "USD")
        #expect(PrizePool.currency(locale: Locale(identifier: "en_001"), timeZone: zurich) == "CHF")
        #expect(PrizePool.currency(locale: Locale(identifier: "en_001"), timeZone: TimeZone(identifier: "Europe/Paris")!) == "EUR")
    }

    @Test func decodesOlderFiles() throws {
        let p = try JSONDecoder().decode(PrizePool.self, from: Data(#"{"currency":"EUR","entries":4}"#.utf8))
        #expect(p.currency == "EUR" && p.entries == 4 && p.buyIn == 20)
    }
}
