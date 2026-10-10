import BilbyKit
import SwiftUI

/// Buy-ins, the counters kept during the game, the prize pool and payouts.
struct PlayersView: View {
    @Environment(TournamentStore.self) private var store
    @State private var editingPayouts = false
    @State private var confirmingNew = false

    private var pool: Binding<PrizePool> {
        Binding(get: { store.tournament.prizePool }, set: { store.setPrizePool($0) })
    }

    var body: some View {
        GeometryReader { geo in
            if geo.size.width > 760 {
                HStack(alignment: .top, spacing: 0) {
                    Form { counters; buyIns }.formStyle(.grouped)
                    Form { summary; payouts }.formStyle(.grouped)
                }
            } else {
                Form { counters; summary; payouts; buyIns }.formStyle(.grouped)
            }
        }
        .toolbar {
            ToolbarItem {
                Button("New Tournament", systemImage: "arrow.counterclockwise.circle") { confirmingNew = true }
                    .help("Reset the clock and the counters")
            }
        }
        .confirmationDialog("Start a new tournament?", isPresented: $confirmingNew) {
            Button("New Tournament", role: .destructive, action: store.newTournament)
        } message: {
            Text("The clock goes back to level 1 and all counters to zero. The structure and buy-ins stay.")
        }
    }

    // MARK: Sections

    private var counters: some View {
        let p = store.tournament.prizePool
        return Section("In the game") {
            CounterRow(title: "Entries", value: p.entries,
                       add: { store.updatePrizePool { $0.addEntry() } },
                       remove: { store.updatePrizePool { $0.removeEntry() } })
            CounterRow(title: "Rebuys", value: p.rebuys,
                       add: { store.updatePrizePool { $0.addRebuy() } },
                       remove: { store.updatePrizePool { $0.removeRebuy() } })
            CounterRow(title: "Add-ons", value: p.addOns,
                       add: { store.updatePrizePool { $0.addAddOn() } },
                       remove: { store.updatePrizePool { $0.removeAddOn() } })
            CounterRow(title: "Players left", value: p.playersLeft, total: p.entries,
                       add: { store.updatePrizePool { $0.reinstate() } },
                       remove: { store.updatePrizePool { $0.eliminate() } },
                       removeLabel: "Knock Out")
        }
    }

    private var buyIns: some View {
        Section("Buy-ins") {
            Picker("Currency", selection: pool.currency) {
                ForEach(currencies, id: \.self) { Text($0).tag($0) }
            }
            AmountRow(title: "Buy-in", amount: pool.buyIn, chips: pool.startingStack, currency: store.tournament.prizePool.currency)
            AmountRow(title: "Rebuy", amount: pool.rebuy, chips: pool.rebuyStack, currency: store.tournament.prizePool.currency)
            AmountRow(title: "Add-on", amount: pool.addOn, chips: pool.addOnStack, currency: store.tournament.prizePool.currency)
            AmountRow(title: "Fee per entry", amount: pool.fee, chips: nil, currency: store.tournament.prizePool.currency)
        }
    }

    private var summary: some View {
        let p = store.tournament.prizePool
        return Section("Prize pool") {
            LabeledContent("Prize pool") {
                Text(Money.format(p.total, p.currency))
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
            }
            LabeledContent("Chips in play", value: p.chipsInPlay.chips)
            LabeledContent("Average stack", value: p.averageStack?.chips ?? "–")
            if p.fee > 0 {
                LabeledContent("Fees collected", value: Money.format(p.fees, p.currency))
            }
        }
        .monospacedDigit()
    }

    private var payouts: some View {
        let p = store.tournament.prizePool
        let amounts = p.payouts()
        let percentages = p.payoutPercentages
        return Section {
            ForEach(percentages.indices, id: \.self) { i in
                HStack {
                    Text(Money.place(i + 1)).frame(width: 44, alignment: .leading)
                    if editingPayouts {
                        TextField("Percent", value: percentBinding(i), format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("%").foregroundStyle(.secondary)
                    } else {
                        Text("\(percentages[i].formatted()) %").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(Money.format(amounts[i], p.currency))
                    if editingPayouts {
                        Button("Remove Place", systemImage: "minus.circle") { removePlace(i) }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .disabled(percentages.count == 1)
                    }
                }
                .monospacedDigit()
            }
            if editingPayouts {
                HStack {
                    Button("Add Place", systemImage: "plus") { addPlace() }
                    Spacer()
                    Button("Use the Table") { store.updatePrizePool { $0.customPayouts = nil } }
                        .disabled(p.customPayouts == nil)
                }
                .buttonStyle(.borderless)
                let sum = percentages.reduce(0, +)
                if abs(sum - 100) > 0.001 {
                    Text("These add up to \(sum.formatted()) %, so Bilby scales them to the whole pool.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            HStack {
                Text("Payouts")
                Spacer()
                Button(editingPayouts ? "Done" : "Edit") { editingPayouts.toggle() }
                    .buttonStyle(.borderless)
                    .font(.callout)
            }
        } footer: {
            if !editingPayouts {
                Text(p.customPayouts == nil
                     ? "From the payout table for \(p.entries) \(p.entries == 1 ? "entry" : "entries")."
                     : "Custom payouts for this tournament.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Payout editing

    private func percentBinding(_ i: Int) -> Binding<Double> {
        Binding(
            get: { store.tournament.prizePool.payoutPercentages[safe: i] ?? 0 },
            set: { value in
                store.updatePrizePool { p in
                    var custom = p.payoutPercentages
                    guard custom.indices.contains(i) else { return }
                    custom[i] = max(0, value)
                    p.customPayouts = custom
                }
            })
    }

    private func addPlace() {
        store.updatePrizePool { p in
            var custom = p.payoutPercentages
            custom.append(custom.last.map { max(1, ($0 / 2).rounded()) } ?? 10)
            p.customPayouts = custom
        }
    }

    private func removePlace(_ i: Int) {
        store.updatePrizePool { p in
            var custom = p.payoutPercentages
            guard custom.count > 1 else { return }
            custom.remove(at: i)
            p.customPayouts = custom
        }
    }

    private var currencies: [String] {
        let common = ["CHF", "EUR", "USD", "GBP", "AUD", "CAD", "JPY", "SEK", "NOK", "DKK"]
        let current = store.tournament.prizePool.currency
        return common.contains(current) ? common : [current] + common
    }
}

private struct CounterRow: View {
    var title: String
    var value: Int
    var total: Int?
    var add: () -> Void
    var remove: () -> Void
    var removeLabel = "Remove"

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Button(removeLabel, systemImage: "minus", action: remove)
                .disabled(value == 0)
            Group {
                if let total {
                    Text("\(value)") + Text(" / \(total)").foregroundStyle(.secondary)
                } else {
                    Text("\(value)")
                }
            }
            .font(.title3.weight(.semibold))
            .monospacedDigit()
            .frame(minWidth: 72)
            Button("Add", systemImage: "plus", action: add)
                .disabled(total.map { value >= $0 } ?? false)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
    }
}

private struct AmountRow: View {
    var title: String
    @Binding var amount: Decimal
    var chips: Binding<Int>?
    var currency: String

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                TextField(title, value: $amount, format: .currency(code: currency).precision(.fractionLength(0...2)))
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 110)
                if let chips {
                    TextField("Chips", value: chips, format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 90)
                    Text("chips").foregroundStyle(.secondary)
                }
            }
            .labelsHidden()
            .monospacedDigit()
        }
    }
}

enum Money {
    /// "CHF 260" or "CHF 12.50".
    static func format(_ amount: Decimal, _ currency: String) -> String {
        amount.formatted(.currency(code: currency).precision(.fractionLength(0...2)))
    }

    /// The currency and the number apart, so the clock can put the currency first and set it smaller,
    /// whatever order the locale uses: ("CHF", "1’250").
    static func parts(_ amount: Decimal, _ currency: String) -> (currency: String, number: String) {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        let symbol = formatter.currencySymbol ?? currency
        let number = format(amount, currency)
            .replacingOccurrences(of: symbol, with: "")
            .trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: "\u{00A0}\u{202F}")))
        return (symbol, number)
    }

    /// "1st", "2nd", "3rd", in English like the rest of the app.
    static func place(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        formatter.locale = Locale(identifier: "en")
        return formatter.string(from: n as NSNumber) ?? "\(n)."
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
