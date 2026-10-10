import AVFoundation

/// The alert sounds, synthesized on the fly: soft bell tones rather than casino buzzers.
enum Chime: String, Codable, CaseIterable, Identifiable {
    case none, dingDong, bell, gong, pings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "None"
        case .dingDong: "Ding-dong"
        case .bell: "Bell"
        case .gong: "Gong"
        case .pings: "Three pings"
        }
    }

    /// Notes as (frequency, start time); the timbre is the same for all notes of a chime.
    fileprivate var notes: [(Double, Double)] {
        switch self {
        case .none: []
        case .dingDong: [(880, 0), (698.46, 0.42)]
        case .bell: [(523.25, 0), (659.25, 0.14), (783.99, 0.28), (1046.5, 0.42)]
        case .gong: [(196, 0), (196.9, 0)]
        case .pings: [(1318.5, 0), (1318.5, 0.28), (1318.5, 0.56)]
        }
    }

    /// (frequency ratio, amplitude) for each partial, and how fast the note fades.
    fileprivate var timbre: (partials: [(Double, Double)], decay: Double) {
        switch self {
        case .none: ([], 1)
        case .dingDong: ([(1, 1), (2, 0.25), (3, 0.08)], 0.9)
        case .bell: ([(1, 1), (2, 0.45), (3, 0.2), (4.2, 0.08)], 1.2)
        case .gong: ([(1, 1), (2, 0.5), (2.76, 0.25), (5.4, 0.06)], 2.6)
        case .pings: ([(1, 1), (2.76, 0.12)], 0.35)
        }
    }
}

/// Plays chimes and speaks announcements.
final class SoundPlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let synthesizer = AVSpeechSynthesizer()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var buffers: [Chime: AVAudioPCMBuffer] = [:]
    private var pendingSpeech: Task<Void, Never>?

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    /// Plays `chime`, then speaks `text` once the chime has mostly faded.
    func play(_ chime: Chime, then text: String? = nil, volume: Double, voice: String?) {
        pendingSpeech?.cancel()
        var delay = 0.0
        if chime != .none, let buffer = buffer(for: chime) {
            startEngine()
            engine.mainMixerNode.outputVolume = Float(volume)
            player.scheduleBuffer(buffer, at: nil, options: .interrupts)
            player.play()
            delay = (chime.notes.last?.1 ?? 0) + 0.7
        }
        guard let text, !text.isEmpty else { return }
        pendingSpeech = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.speak(text, volume: volume, voice: voice)
        }
    }

    func speak(_ text: String, volume: Double, voice: String?) {
        synthesizer.stopSpeaking(at: .word)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice.flatMap(AVSpeechSynthesisVoice.init(identifier:)) ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.volume = Float(volume)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        synthesizer.speak(utterance)
    }

    /// English voices, best quality first.
    static var voices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") && !$0.voiceTraits.contains(.isNoveltyVoice) }
            .sorted { ($0.quality.rawValue, $1.name) > ($1.quality.rawValue, $0.name) }
    }

    private func startEngine() {
        guard !engine.isRunning else { return }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        try? engine.start()
    }

    private func buffer(for chime: Chime) -> AVAudioPCMBuffer? {
        if let cached = buffers[chime] { return cached }
        let rate = format.sampleRate
        let (partials, decay) = chime.timbre
        let length = (chime.notes.map(\.1).max() ?? 0) + decay * 5
        let frames = AVAudioFrameCount(length * rate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        var peak: Float = 0
        for i in 0..<Int(frames) {
            let t = Double(i) / rate
            var value = 0.0
            for (frequency, start) in chime.notes where t >= start {
                let local = t - start
                let attack = min(1, local / 0.006)
                for (ratio, amplitude) in partials {
                    // Higher partials fade faster, as they do on a real bell.
                    let envelope = exp(-local / (decay / ratio.squareRoot()))
                    value += amplitude * envelope * sin(2 * .pi * frequency * ratio * local)
                }
                value *= attack
            }
            samples[i] = Float(value)
            peak = max(peak, abs(samples[i]))
        }
        if peak > 0 {
            for i in 0..<Int(frames) { samples[i] *= 0.6 / peak }
        }
        buffers[chime] = buffer
        return buffer
    }
}
