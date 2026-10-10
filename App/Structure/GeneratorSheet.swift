import BilbyKit
import SwiftUI

/// Builds a structure from the shape of the game and previews it before use.
struct GeneratorSheet: View {
    @Environment(TournamentStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("generator.stack") private var stack = 10_000
    @AppStorage("generator.players") private var players = 9
    @AppStorage("generator.hours") private var hours = 4.0
    @AppStorage("generator.levelMinutes") private var levelMinutes = 20
    @AppStorage("generator.chips") private var chipsText = "25, 100, 500, 1000, 5000"
    @AppStorage("generator.breakEvery") private var breakEvery = 120
    @AppStorage("generator.antes") private var antes = "bigBlind"
    @State private var confirming = false
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    private var compact: Bool {
        #if os(iOS)
        sizeClass == .compact
        #else
        false
        #endif
    }

    private var options: StructureGenerator.Options {
        .init(name: "\(players) players, \(TimeFormat.duration(minutes: Int(hours * 60)))",
              startingStack: max(1, stack), players: max(2, players), targetMinutes: Int(hours * 60),
              levelMinutes: levelMinutes, chips: chips, breakEveryMinutes: breakEvery,
              anteStyle: AnteStyle(rawValue: antes))
    }

    private var chips: [Int] {
        chipsText.split { !$0.isNumber }.compactMap { Int($0) }.filter { $0 > 0 }
    }

    var body: some View {
        let structure = StructureGenerator(options).makeStructure()
        NavigationStack {
            Group {
                if compact {
                    Form {
                        settingsSections
                        Section("Preview") { preview(structure) }
                    }
                } else {
                    HStack(alignment: .top, spacing: 0) {
                        Form { settingsSections }
                            .frame(width: 340)
                        List { preview(structure) }
                            .frame(minWidth: 320)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Generate a Structure")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Structure") {
                        if store.tournament.clock.hasStarted { confirming = true } else { use(structure) }
                    }
                    .disabled(chips.isEmpty)
                }
            }
            .confirmationDialog("Replace the structure in play?", isPresented: $confirming) {
                Button("Use Structure", role: .destructive) { use(structure) }
            } message: {
                Text("The clock goes back to level 1.")
            }
        }
        #if os(macOS)
        .frame(minWidth: 720, minHeight: 520)
        #endif
    }

    @ViewBuilder
    private var settingsSections: some View {
        Section("Players and chips") {
            LabeledContent("Starting stack") {
                TextField("Starting stack", value: $stack, format: .number)
                    .multilineTextAlignment(.trailing)
                    .labelsHidden()
            }
            Stepper("Players: \(players)", value: $players, in: 2...500)
            LabeledContent("Chips") {
                TextField("Chips", text: $chipsText, prompt: Text("25, 100, 500"))
                    .multilineTextAlignment(.trailing)
                    .labelsHidden()
            }
        }
        Section("Time") {
            Stepper("Ends after about \(TimeFormat.duration(minutes: Int(hours * 60)))",
                    value: $hours, in: 1...12, step: 0.5)
            Picker("Levels", selection: $levelMinutes) {
                ForEach([10, 12, 15, 20, 25, 30, 40, 45, 60], id: \.self) { Text("\($0) min").tag($0) }
            }
            Picker("Break", selection: $breakEvery) {
                Text("None").tag(0)
                ForEach([60, 90, 120, 180], id: \.self) { Text("Every \(TimeFormat.duration(minutes: $0))").tag($0) }
            }
            Picker("Antes", selection: $antes) {
                Text("Big blind ante").tag("bigBlind")
                Text("Everyone pays").tag("everyone")
                Text("None").tag("none")
            }
        }
    }

    private func preview(_ structure: Structure) -> some View {
        ForEach(Array(structure.rounds.enumerated()), id: \.element.id) { index, round in
            HStack {
                Text(structure.levelNumber(at: index).map { "Level \($0)" } ?? "Break")
                    .foregroundStyle(round.isBreak ? .secondary : .primary)
                    .frame(width: 70, alignment: .leading)
                Text(round.isBreak ? round.note : round.shortText)
                    .foregroundStyle(round.isBreak ? .secondary : .primary)
                Spacer()
                Text("\(round.minutes) min").foregroundStyle(.secondary)
            }
            .monospacedDigit()
        }
    }

    private func use(_ structure: Structure) {
        store.use(structure)
        dismiss()
    }
}
