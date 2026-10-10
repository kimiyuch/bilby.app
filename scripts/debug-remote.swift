// Sends a command to a running debug build of Bilby (see App/macOS/DebugRemote.swift).
// Usage: swift scripts/debug-remote.swift <command> [argument]
import Foundation

let args = CommandLine.arguments.dropFirst()
guard let command = args.first else { print("usage: debug-remote.swift <command> [argument]"); exit(1) }
let info: [String: String]? = args.dropFirst().first.map { ["argument": $0] }
DistributedNotificationCenter.default().postNotificationName(
    Notification.Name("ch.kimiyu.Bilby.debug"), object: command, userInfo: info, deliverImmediately: true)
