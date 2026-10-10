import Foundation

public enum TimeFormat {
    /// "9:59", "12:00" or "1:05:00". Rounds up, so a fresh 10 minute level reads 10:00 and the last second 0:01.
    public static func countdown(_ seconds: TimeInterval) -> String {
        clock(Int(max(0, seconds).rounded(.up)))
    }

    /// Elapsed time, rounded down: "0:00", "59:59", "2:14:05".
    public static func elapsed(_ seconds: TimeInterval) -> String {
        clock(Int(max(0, seconds).rounded(.down)))
    }

    /// "1 h 5 min", "45 min".
    public static func duration(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        switch (h, m) {
        case (0, _): return "\(m) min"
        case (_, 0): return "\(h) h"
        default: return "\(h) h \(m) min"
        }
    }

    static func clock(_ total: Int) -> String {
        let h = total / 3600, m = total / 60 % 60, s = total % 60
        let ss = s < 10 ? "0\(s)" : "\(s)"
        if h > 0 { return "\(h):\(m < 10 ? "0" : "")\(m):\(ss)" }
        return "\(m):\(ss)"
    }
}
