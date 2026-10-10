import Foundation

/// Buy-ins, the counters kept during the game, and what they add up to.
public struct PrizePool: Codable, Equatable, Sendable {
    /// ISO currency code, e.g. "CHF".
    public var currency: String
    public var buyIn: Decimal
    public var rebuy: Decimal
    public var addOn: Decimal
    /// Charged with each entry on top of the buy-in; it doesn't go into the prize pool.
    public var fee: Decimal

    public var startingStack: Int
    public var rebuyStack: Int
    public var addOnStack: Int

    public private(set) var entries: Int
    public private(set) var rebuys: Int
    public private(set) var addOns: Int
    public private(set) var playersLeft: Int

    /// Percentages per place for this tournament; nil follows `PayoutTable` for the number of entries.
    public var customPayouts: [Double]?

    public init(currency: String = PrizePool.localCurrency, buyIn: Decimal = 20, rebuy: Decimal = 20,
                addOn: Decimal = 20, fee: Decimal = 0, startingStack: Int = 10_000, rebuyStack: Int = 10_000,
                addOnStack: Int = 10_000) {
        self.currency = currency
        self.buyIn = buyIn
        self.rebuy = rebuy
        self.addOn = addOn
        self.fee = fee
        self.startingStack = startingStack
        self.rebuyStack = rebuyStack
        self.addOnStack = addOnStack
        entries = 0
        rebuys = 0
        addOns = 0
        playersLeft = 0
    }

    /// The locale's currency. With the region set to World there is none, so guess from the time zone.
    public static var localCurrency: String {
        currency(locale: .current, timeZone: .current)
    }

    static func currency(locale: Locale, timeZone: TimeZone) -> String {
        if let code = locale.currency?.identifier { return code }
        let zone = timeZone.identifier
        let byZone = ["Europe/Zurich": "CHF", "Europe/Vaduz": "CHF", "Europe/London": "GBP", "Europe/Stockholm": "SEK",
                      "Europe/Oslo": "NOK", "Europe/Copenhagen": "DKK", "Asia/Tokyo": "JPY", "America/Toronto": "CAD",
                      "America/Vancouver": "CAD", "Pacific/Auckland": "NZD"]
        if let code = byZone[zone] { return code }
        if zone.hasPrefix("Europe/") { return "EUR" }
        if zone.hasPrefix("Australia/") { return "AUD" }
        return "USD"
    }

    // MARK: Counters

    /// A new player sits down.
    public mutating func addEntry() {
        entries += 1
        playersLeft += 1
    }

    public mutating func removeEntry() {
        guard entries > 0 else { return }
        entries -= 1
        playersLeft = min(playersLeft, entries)
    }

    public mutating func addRebuy() { rebuys += 1 }
    public mutating func removeRebuy() { rebuys = max(0, rebuys - 1) }
    public mutating func addAddOn() { addOns += 1 }
    public mutating func removeAddOn() { addOns = max(0, addOns - 1) }

    /// A player is knocked out.
    public mutating func eliminate() { playersLeft = max(0, playersLeft - 1) }
    /// Undo a knockout.
    public mutating func reinstate() { playersLeft = min(entries, playersLeft + 1) }

    public mutating func resetCounters() {
        entries = 0
        rebuys = 0
        addOns = 0
        playersLeft = 0
    }

    // MARK: Totals

    public var total: Decimal {
        Decimal(entries) * buyIn + Decimal(rebuys) * rebuy + Decimal(addOns) * addOn
    }

    public var fees: Decimal { Decimal(entries) * fee }

    public var chipsInPlay: Int {
        entries * startingStack + rebuys * rebuyStack + addOns * addOnStack
    }

    public var averageStack: Int? {
        playersLeft > 0 ? chipsInPlay / playersLeft : nil
    }

    // MARK: Payouts

    public var payoutPercentages: [Double] {
        customPayouts ?? PayoutTable.percentages(forEntries: entries)
    }

    /// Prize money per place. Every place but first is rounded down to `unit`; first place gets the rest,
    /// so the payouts always add up to the whole pool.
    public func payouts(roundingTo unit: Decimal? = nil) -> [Decimal] {
        let percentages = payoutPercentages.map { max(0, $0) }
        let sum = percentages.reduce(0, +)
        guard sum > 0, total > 0 else { return percentages.map { _ in 0 } }
        let unit = unit ?? Self.roundingUnit(for: total)
        var amounts = percentages.map { pct in
            Self.roundDown(total * Decimal(pct / sum), to: unit)
        }
        amounts[0] = total - amounts.dropFirst().reduce(0, +)
        return amounts
    }

    /// Small pools pay whole amounts, bigger ones round to 5 or 10.
    public static func roundingUnit(for total: Decimal) -> Decimal {
        switch total {
        case ..<500: 1
        case ..<5000: 5
        default: 10
        }
    }

    static func roundDown(_ value: Decimal, to unit: Decimal) -> Decimal {
        guard unit > 0 else { return value }
        var quotient = value / unit
        var rounded = Decimal()
        NSDecimalRound(&rounded, &quotient, 0, .down)
        return rounded * unit
    }
}

extension PrizePool {
    private enum CodingKeys: String, CodingKey {
        case currency, buyIn, rebuy, addOn, fee, startingStack, rebuyStack, addOnStack
        case entries, rebuys, addOns, playersLeft, customPayouts
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PrizePool()
        currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? d.currency
        buyIn = try c.decodeIfPresent(Decimal.self, forKey: .buyIn) ?? d.buyIn
        rebuy = try c.decodeIfPresent(Decimal.self, forKey: .rebuy) ?? d.rebuy
        addOn = try c.decodeIfPresent(Decimal.self, forKey: .addOn) ?? d.addOn
        fee = try c.decodeIfPresent(Decimal.self, forKey: .fee) ?? d.fee
        startingStack = try c.decodeIfPresent(Int.self, forKey: .startingStack) ?? d.startingStack
        rebuyStack = try c.decodeIfPresent(Int.self, forKey: .rebuyStack) ?? d.rebuyStack
        addOnStack = try c.decodeIfPresent(Int.self, forKey: .addOnStack) ?? d.addOnStack
        entries = try c.decodeIfPresent(Int.self, forKey: .entries) ?? 0
        rebuys = try c.decodeIfPresent(Int.self, forKey: .rebuys) ?? 0
        addOns = try c.decodeIfPresent(Int.self, forKey: .addOns) ?? 0
        playersLeft = try c.decodeIfPresent(Int.self, forKey: .playersLeft) ?? 0
        customPayouts = try c.decodeIfPresent([Double].self, forKey: .customPayouts)
    }
}

/// How the prize pool is split, by number of entries. Each row adds up to 100.
public enum PayoutTable {
    public static let rows: [(upTo: Int, percentages: [Double])] = [
        (5, [100]),
        (10, [65, 35]),
        (17, [50, 30, 20]),
        (27, [45, 27, 17, 11]),
        (36, [40, 25, 15, 11, 9]),
        (50, [37, 23, 15, 10, 8, 7]),
        (75, [34, 21, 14, 10, 8, 7, 6]),
        (100, [31, 19, 13, 10, 8, 7, 6, 6]),
        (.max, [28, 17, 12, 9, 8, 7, 6, 5, 4, 4]),
    ]

    public static func percentages(forEntries entries: Int) -> [Double] {
        rows.first { entries <= $0.upTo }!.percentages
    }
}
