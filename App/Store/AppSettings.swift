import Foundation

/// App preferences, kept in settings.json next to the tournament.
struct AppSettings: Codable, Equatable {
    /// Seconds before the end of a level or break; 0 turns the warning off.
    var warningSeconds = 60
    var warningSound = Chime.dingDong
    var levelSound = Chime.bell
    var breakStartSound = Chime.gong
    var breakEndSound = Chime.pings
    var announce = true
    var voice: String?
    var volume = 0.8
    var muted = false

    init() {}

    init(from decoder: Decoder) throws {
        // Every field is optional, so older files keep working when settings are added.
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        warningSeconds = try c.decodeIfPresent(Int.self, forKey: .warningSeconds) ?? d.warningSeconds
        warningSound = try c.decodeIfPresent(Chime.self, forKey: .warningSound) ?? d.warningSound
        levelSound = try c.decodeIfPresent(Chime.self, forKey: .levelSound) ?? d.levelSound
        breakStartSound = try c.decodeIfPresent(Chime.self, forKey: .breakStartSound) ?? d.breakStartSound
        breakEndSound = try c.decodeIfPresent(Chime.self, forKey: .breakEndSound) ?? d.breakEndSound
        announce = try c.decodeIfPresent(Bool.self, forKey: .announce) ?? d.announce
        voice = try c.decodeIfPresent(String.self, forKey: .voice)
        volume = try c.decodeIfPresent(Double.self, forKey: .volume) ?? d.volume
        muted = try c.decodeIfPresent(Bool.self, forKey: .muted) ?? d.muted
    }

    var warning: TimeInterval { TimeInterval(warningSeconds) }
}
