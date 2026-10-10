import Foundation
import os

/// Small JSON files in Application Support/Bilby. Debug builds use Application Support/Bilby Debug, so testing
/// never touches the tournament of the installed app.
struct Persistence {
    let directory: URL

    #if DEBUG
    static let standard = Persistence(directory: URL.applicationSupportDirectory.appending(path: "Bilby Debug", directoryHint: .isDirectory))
    #else
    static let standard = Persistence(directory: URL.applicationSupportDirectory.appending(path: "Bilby", directoryHint: .isDirectory))
    #endif

    private static let log = Logger(subsystem: "ch.kimiyu.Bilby", category: "persistence")

    func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        let url = directory.appending(path: name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            Self.log.error("Couldn't read \(name): \(error)")
            // Keep the unreadable file around instead of overwriting it on the next save.
            try? FileManager.default.moveItem(at: url, to: directory.appending(path: name + ".broken"))
            return nil
        }
    }

    func save(_ value: some Encodable, to name: String) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(value).write(to: directory.appending(path: name), options: .atomic)
        } catch {
            Self.log.error("Couldn't save \(name): \(error)")
        }
    }
}
