import Foundation

/// Built-in sound sets (SPEC D5, TECH T6).
public enum SoundSet: String, CaseIterable, Codable, Sendable {
    case classic, soft, sharp, whistle
}

/// What a signal announces. The step sound depends on the step type, not on the step.
public enum SoundCue: CaseIterable, Sendable {
    case countdown, work, rest, other, finish

    public init(_ type: StepType) {
        switch type.category {
        case .work: self = .work
        case .rest: self = .rest
        case .other: self = .other
        }
    }
}

/// Synthesizes the signals in code: no audio files, no licenses, equal loudness across sets (TECH T6).
public enum SoundSynth {
    public static let sampleRate = 44_100.0
    /// Peak level of every sound, leaving headroom for the mixer.
    public static let peak: Float = 0.8

    /// Mono samples at `sampleRate`, normalized to `peak`.
    public static func samples(_ cue: SoundCue, in set: SoundSet) -> [Float] {
        let notes = notes(cue, base: set.baseFrequency)
        let length = notes.map { $0.start + $0.duration }.max() ?? 0
        var output = [Float](repeating: 0, count: Int(length * sampleRate) + 1)
        for note in notes {
            let first = Int(note.start * sampleRate)
            let count = Int(note.duration * sampleRate)
            for i in 0..<count where first + i < output.count {
                let t = Double(i) / sampleRate
                output[first + i] += Float(set.wave(note.frequency, t) * set.envelope(t, note.duration))
            }
        }
        let maxLevel = output.map(abs).max() ?? 0
        guard maxLevel > 0 else { return output }
        let gain = peak / maxLevel
        return output.map { $0 * gain }
    }

    struct Note {
        var frequency: Double
        var start: TimeInterval
        var duration: TimeInterval
    }

    /// Work goes up, rest goes down, prepare/cooldown in between, finish is a rising run.
    static func notes(_ cue: SoundCue, base: Double) -> [Note] {
        switch cue {
        case .countdown:
            [Note(frequency: base, start: 0, duration: 0.12)]
        case .work:
            [Note(frequency: base * 1.5, start: 0, duration: 0.6)]
        case .rest:
            [Note(frequency: base * 0.75, start: 0, duration: 0.6)]
        case .other:
            [Note(frequency: base, start: 0, duration: 0.15), Note(frequency: base * 1.25, start: 0.18, duration: 0.4)]
        case .finish:
            [1, 1.25, 1.5].enumerated().map { Note(frequency: base * $1, start: Double($0) * 0.16, duration: 0.15) }
                + [Note(frequency: base * 2, start: 0.48, duration: 0.7)]
        }
    }
}

extension SoundSet {
    var baseFrequency: Double {
        switch self {
        case .classic: 880
        case .soft: 660
        case .sharp: 1000
        case .whistle: 1800
        }
    }

    func wave(_ frequency: Double, _ t: TimeInterval) -> Double {
        let phase = 2 * .pi * frequency * t
        switch self {
        case .classic:
            return sin(phase)
        case .soft:
            // A touch of octave gives a mallet-like tone.
            return sin(phase) + 0.25 * sin(2 * phase)
        case .sharp:
            // Odd harmonics up to the 9th: square-ish, without aliasing.
            return stride(from: 1, through: 9, by: 2).reduce(0) { $0 + sin(Double($1) * phase) / Double($1) }
        case .whistle:
            // 7 Hz vibrato of ±2 %.
            let vibrato = 0.02 * frequency / 7 * sin(2 * .pi * 7 * t)
            return sin(phase + 2 * .pi * vibrato)
        }
    }

    /// Short fades on both ends avoid clicks; the soft set decays like a struck bar.
    func envelope(_ t: TimeInterval, _ duration: TimeInterval) -> Double {
        let attack = self == .whistle ? 0.02 : 0.004
        let release = 0.03
        let edges = min(1, t / attack, max(0, duration - t) / release)
        return self == .soft ? edges * exp(-t / (duration * 0.35)) : edges
    }
}
