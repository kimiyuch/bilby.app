import Foundation

/// The structures Bilby ships with. All assume 25, 100, 500 and 1000 chips (plus 5000 for the deep stack).
public enum Presets {
    public static var all: [Structure] { [standard, turbo, deepStack] }

    /// 10,000 chips, 20 minute levels.
    public static var standard: Structure {
        Structure(name: "Standard home game", rounds: [
            .level(25, 50, minutes: 20),
            .level(50, 100, minutes: 20),
            .level(75, 150, minutes: 20),
            .level(100, 200, minutes: 20),
            .pause(minutes: 10),
            .level(100, 200, ante: 200, minutes: 20),
            .level(150, 300, ante: 300, minutes: 20),
            .level(200, 400, ante: 400, minutes: 20),
            .level(250, 500, ante: 500, minutes: 20),
            .pause(minutes: 15, note: "Color up the 25s"),
            .level(300, 600, ante: 600, minutes: 20),
            .level(400, 800, ante: 800, minutes: 20),
            .level(500, 1000, ante: 1000, minutes: 20),
            .level(600, 1200, ante: 1200, minutes: 20),
            .pause(minutes: 10, note: "Color up the 100s"),
            .level(1000, 2000, ante: 2000, minutes: 20),
            .level(1500, 3000, ante: 3000, minutes: 20),
            .level(2000, 4000, ante: 4000, minutes: 20),
            .level(3000, 6000, ante: 6000, minutes: 20),
            .level(4000, 8000, ante: 8000, minutes: 20),
            .level(5000, 10000, ante: 10000, minutes: 20),
        ])
    }

    /// 10,000 chips, 10 minute levels.
    public static var turbo: Structure {
        Structure(name: "Turbo", rounds: [
            .level(25, 50, minutes: 10),
            .level(50, 100, minutes: 10),
            .level(75, 150, minutes: 10),
            .level(100, 200, minutes: 10),
            .level(150, 300, ante: 300, minutes: 10),
            .pause(minutes: 10, note: "Color up the 25s"),
            .level(200, 400, ante: 400, minutes: 10),
            .level(300, 600, ante: 600, minutes: 10),
            .level(400, 800, ante: 800, minutes: 10),
            .level(500, 1000, ante: 1000, minutes: 10),
            .level(600, 1200, ante: 1200, minutes: 10),
            .level(800, 1600, ante: 1600, minutes: 10),
            .pause(minutes: 10, note: "Color up the 100s"),
            .level(1000, 2000, ante: 2000, minutes: 10),
            .level(1500, 3000, ante: 3000, minutes: 10),
            .level(2000, 4000, ante: 4000, minutes: 10),
            .level(3000, 6000, ante: 6000, minutes: 10),
            .level(4000, 8000, ante: 8000, minutes: 10),
            .level(5000, 10000, ante: 10000, minutes: 10),
        ])
    }

    /// 25,000 chips, 30 minute levels.
    public static var deepStack: Structure {
        Structure(name: "Deep stack", rounds: [
            .level(25, 50, minutes: 30),
            .level(50, 100, minutes: 30),
            .level(75, 150, minutes: 30),
            .level(100, 200, minutes: 30),
            .pause(minutes: 10),
            .level(150, 300, ante: 300, minutes: 30),
            .level(200, 400, ante: 400, minutes: 30),
            .level(250, 500, ante: 500, minutes: 30),
            .level(300, 600, ante: 600, minutes: 30),
            .pause(minutes: 15, note: "Color up the 25s"),
            .level(400, 800, ante: 800, minutes: 30),
            .level(500, 1000, ante: 1000, minutes: 30),
            .level(600, 1200, ante: 1200, minutes: 30),
            .level(800, 1600, ante: 1600, minutes: 30),
            .pause(minutes: 10, note: "Color up the 100s"),
            .level(1000, 2000, ante: 2000, minutes: 30),
            .level(1500, 3000, ante: 3000, minutes: 30),
            .level(2000, 4000, ante: 4000, minutes: 30),
            .level(2500, 5000, ante: 5000, minutes: 30),
            .level(3000, 6000, ante: 6000, minutes: 30),
            .level(4000, 8000, ante: 8000, minutes: 30),
            .level(5000, 10000, ante: 10000, minutes: 30),
            .level(6000, 12000, ante: 12000, minutes: 30),
            .level(8000, 16000, ante: 16000, minutes: 30),
            .level(10000, 20000, ante: 20000, minutes: 30),
        ])
    }
}
