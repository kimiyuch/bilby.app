import BilbyKit
import SwiftUI
import UniformTypeIdentifiers

/// Edits the structure in play. Changes apply immediately; the clock stays on its round.
struct StructureEditor: View {
    @Environment(TournamentStore.self) private var store
    @State private var showGenerator = false
    @State private var showLibrary = false
    @State private var importing = false
    @State private var exporting = false
    @State private var importError: String?
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var compact: Bool { sizeClass == .compact }
    #else
    private let compact = false
    #endif

    private var structure: Binding<Structure> {
        Binding(get: { store.structure }, set: { store.setStructure($0) })
    }

    var body: some View {
        let current = store.snapshot(at: store.now).roundIndex
        List {
            Section {
                ForEach(Array(store.structure.rounds.enumerated()), id: \.element.id) { index, round in
                    row(binding(for: round.id), levelNumber: store.structure.levelNumber(at: index),
                        isCurrent: index == current && store.tournament.clock.hasStarted)
                        .contextMenu {
                            Button("Play From Here") { store.jump(to: index) }
                            Divider()
                            Button("Insert Level Above") { insert(.level, at: index) }
                            Button("Insert Break Above") { insert(.break, at: index) }
                            Divider()
                            Button("Delete", role: .destructive) { delete(at: IndexSet(integer: index)) }
                                .disabled(store.structure.rounds.count == 1)
                        }
                }
                .onMove { from, to in structure.wrappedValue.rounds.move(fromOffsets: from, toOffset: to) }
                .onDelete(perform: delete)
            } header: {
                header
            } footer: {
                HStack {
                    Button("Add Level", systemImage: "plus") { insert(.level, at: store.structure.rounds.count) }
                    Button("Add Break", systemImage: "cup.and.saucer") { insert(.break, at: store.structure.rounds.count) }
                    Spacer()
                    Text(summary).foregroundStyle(.secondary)
                }
                .padding(.top, 6)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button("Structures", systemImage: "books.vertical") { showLibrary = true }
                Button("Generate", systemImage: "wand.and.stars") { showGenerator = true }
                Menu("More", systemImage: "ellipsis") {
                    Button("Save to My Structures", systemImage: "square.and.arrow.down") { store.saveToLibrary(store.structure) }
                    Divider()
                    Button("Import…", systemImage: "square.and.arrow.down.on.square") { importing = true }
                    Button("Export…", systemImage: "square.and.arrow.up") { exporting = true }
                }
            }
        }
        .sheet(isPresented: $showGenerator) { GeneratorSheet() }
        .sheet(isPresented: $showLibrary) { StructureLibrary() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let imported = try Structure.importing(Data(contentsOf: url))
                store.saveToLibrary(imported)
                showLibrary = true
            } catch {
                importError = "This file isn't a Bilby structure."
            }
        }
        .fileExporter(isPresented: $exporting, document: StructureFile(structure: store.structure),
                      contentType: .json, defaultFilename: store.structure.name) { _ in }
        .alert("Couldn't Import", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
        } message: {
            Text(importError ?? "")
        }
    }

    /// Follows the round by ID, so rows keep their state when the list is reordered.
    private func binding(for id: UUID) -> Binding<Round> {
        Binding(
            get: { store.structure.rounds.first { $0.id == id } ?? .pause(minutes: 0) },
            set: { new in
                var s = store.structure
                guard let i = s.rounds.firstIndex(where: { $0.id == id }) else { return }
                s.rounds[i] = new
                store.setStructure(s)
            })
    }

    @ViewBuilder
    private func row(_ round: Binding<Round>, levelNumber: Int?, isCurrent: Bool) -> some View {
        if compact {
            NavigationLink {
                RoundForm(round: round, levelNumber: levelNumber)
            } label: {
                CompactRoundRow(round: round.wrappedValue, levelNumber: levelNumber, isCurrent: isCurrent)
            }
        } else {
            RoundRow(round: round, levelNumber: levelNumber, isCurrent: isCurrent)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Name", text: structure.name)
                .font(.title2.weight(.semibold))
                .textFieldStyle(.plain)
                .textCase(nil)
                .foregroundStyle(.primary)
            if !compact { RoundRow.columnTitles }
        }
        .padding(.bottom, 4)
    }

    private var summary: String {
        let s = store.structure
        return "\(s.levelCount) levels · \(TimeFormat.duration(minutes: Int(s.totalDuration / 60)))"
    }

    private func insert(_ kind: Round.Kind, at index: Int) {
        var s = store.structure
        let previous = s.rounds[..<index].last { !$0.isBreak }
        switch kind {
        case .break:
            s.rounds.insert(.pause(minutes: 10), at: index)
        case .level:
            s.rounds.insert(s.suggestedLevel(after: previous), at: index)
        }
        store.setStructure(s)
    }

    private func delete(at offsets: IndexSet) {
        var s = store.structure
        guard s.rounds.count > offsets.count else { return }
        s.rounds.remove(atOffsets: offsets)
        store.setStructure(s)
    }
}

/// One level or break, edited in place.
struct RoundRow: View {
    @Binding var round: Round
    var levelNumber: Int?
    var isCurrent: Bool

    static let numberWidth: CGFloat = 80
    static let amountWidth: CGFloat = 84

    static var columnTitles: some View {
        HStack(spacing: 12) {
            Text("").frame(width: numberWidth, alignment: .leading)
            Text("Small blind").frame(width: amountWidth, alignment: .trailing)
            Text("Big blind").frame(width: amountWidth, alignment: .trailing)
            Text("Ante").frame(width: amountWidth, alignment: .trailing)
            Text("").frame(width: 120)
            Text("Minutes").frame(width: 60, alignment: .trailing)
            Spacer()
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
    }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "play.fill")
                    .font(.caption2)
                    .foregroundStyle(.tint)
                    .opacity(isCurrent ? 1 : 0)
                Text(levelNumber.map { "Level \($0)" } ?? "Break")
                    .foregroundStyle(round.isBreak ? .secondary : .primary)
            }
            .frame(width: Self.numberWidth, alignment: .leading)

            if round.isBreak {
                TextField("Note, e.g. color up the 25s", text: $round.note)
                    .frame(width: Self.amountWidth * 3 + 24 + 12 + 120)
            } else {
                amount($round.smallBlind)
                amount($round.bigBlind)
                amount($round.ante)
                Picker("Ante style", selection: $round.anteStyle) {
                    Text("BB ante").tag(AnteStyle.bigBlind)
                    Text("Everyone").tag(AnteStyle.everyone)
                }
                .labelsHidden()
                .frame(width: 120)
                .disabled(round.ante == 0)
            }
            TextField("Minutes", value: $round.minutes, format: .number)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
            Spacer()
        }
        .monospacedDigit()
        .padding(.vertical, 2)
    }

    private func amount(_ value: Binding<Int>) -> some View {
        TextField("", value: value, format: .number)
            .multilineTextAlignment(.trailing)
            .frame(width: Self.amountWidth)
    }
}

/// One line per round on a narrow screen; tapping it opens `RoundForm`.
struct CompactRoundRow: View {
    var round: Round
    var levelNumber: Int?
    var isCurrent: Bool

    var body: some View {
        HStack {
            Image(systemName: "play.fill")
                .font(.caption2)
                .foregroundStyle(.tint)
                .opacity(isCurrent ? 1 : 0)
            VStack(alignment: .leading, spacing: 2) {
                Text(levelNumber.map { "Level \($0)" } ?? "Break")
                    .foregroundStyle(round.isBreak ? .secondary : .primary)
                if round.isBreak, !round.note.isEmpty {
                    Text(round.note).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !round.isBreak {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(round.blindsText)
                    if let ante = round.anteText {
                        Text(ante).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Text("\(round.minutes) min")
                .foregroundStyle(.secondary)
                .frame(minWidth: 56, alignment: .trailing)
        }
        .monospacedDigit()
    }
}

/// Edits one round on a narrow screen.
struct RoundForm: View {
    @Binding var round: Round
    var levelNumber: Int?

    var body: some View {
        Form {
            if round.isBreak {
                Section {
                    Stepper("\(round.minutes) minutes", value: $round.minutes, in: 1...240)
                    TextField("Note, e.g. color up the 25s", text: $round.note)
                }
            } else {
                Section("Blinds") {
                    LabeledContent("Small blind") { amount($round.smallBlind) }
                    LabeledContent("Big blind") { amount($round.bigBlind) }
                }
                Section("Ante") {
                    LabeledContent("Ante") { amount($round.ante) }
                    Picker("Paid by", selection: $round.anteStyle) {
                        Text("Big blind").tag(AnteStyle.bigBlind)
                        Text("Everyone").tag(AnteStyle.everyone)
                    }
                    .disabled(round.ante == 0)
                }
                Section {
                    Stepper("\(round.minutes) minutes", value: $round.minutes, in: 1...240)
                }
            }
        }
        .navigationTitle(levelNumber.map { "Level \($0)" } ?? "Break")
    }

    private func amount(_ value: Binding<Int>) -> some View {
        TextField("0", value: value, format: .number)
            .multilineTextAlignment(.trailing)
            #if os(iOS)
            .keyboardType(.numberPad)
            #endif
    }
}

/// A structure as a JSON file, for the exporter.
struct StructureFile: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    var structure: Structure

    init(structure: Structure) { self.structure = structure }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        structure = try Structure.importing(data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try structure.exportData())
    }
}
