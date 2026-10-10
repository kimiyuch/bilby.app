import BilbyKit
import SwiftUI

/// Pick a structure to play: the built-in presets and your own.
struct StructureLibrary: View {
    @Environment(TournamentStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var pending: Structure?

    var body: some View {
        NavigationStack {
            List {
                Section("Presets") {
                    ForEach(Presets.all, id: \.name) { row($0, deletable: false) }
                }
                Section("My Structures") {
                    if store.library.isEmpty {
                        Text("Structures you save or import show up here.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.library) { row($0, deletable: true) }
                }
            }
            .navigationTitle("Structures")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog("Replace the structure in play?", isPresented: Binding(
                get: { pending != nil }, set: { if !$0 { pending = nil } })
            ) {
                Button("Use \(pending?.name ?? "")", role: .destructive) { if let pending { use(pending) } }
            } message: {
                Text("The clock goes back to level 1.")
            }
        }
        .frame(minWidth: 420, minHeight: 440)
    }

    private func row(_ structure: Structure, deletable: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(structure.name)
                Text(details(structure))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Use") {
                if store.tournament.clock.hasStarted { pending = structure } else { use(structure) }
            }
        }
        .contextMenu {
            if deletable {
                Button("Delete", role: .destructive) { store.removeFromLibrary(structure) }
            }
        }
    }

    private func details(_ s: Structure) -> String {
        let first = s.rounds.first { !$0.isBreak }
        let minutes = first?.minutes ?? 0
        return "\(s.levelCount) levels of \(minutes) min · starts \(first?.blindsText ?? "–")"
    }

    private func use(_ structure: Structure) {
        // Your own structures keep their identity, so saving again updates them; presets get a fresh copy.
        store.use(structure)
        dismiss()
    }
}
