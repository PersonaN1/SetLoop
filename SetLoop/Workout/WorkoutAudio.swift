import AVFoundation
import AudioToolbox
import UIKit
import SetLoopCore

/// Signals, voice and vibration of a workout, and audio interruptions such as calls (SPEC D5, D6; TECH T2, T6).
///
/// While a workout runs with sound or voice on, the engine keeps playing, which keeps the app alive
/// on the lock screen. Other apps' audio is ducked only around signals.
@MainActor
final class WorkoutAudio {
    /// A call, Siri, an alarm or another app took the audio.
    var onInterruptionBegan: (() -> Void)?

    private let settings: AppSettings
    private let session = AVAudioSession.sharedInstance()
    private let engine = AVAudioEngine()
    /// Ticks and step signals overlap: a tick must not cut the step sound's tail.
    private let tickPlayer = AVAudioPlayerNode()
    private let stepPlayer = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: SoundSynth.sampleRate, channels: 1)!
    private let speech = AVSpeechSynthesizer()
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var players: [AVAudioPlayerNode] { [tickPlayer, stepPlayer] }
    private var observers: [NSObjectProtocol] = []

    private var isActive = false
    private var isDucked = false
    private var unduckTask: Task<Void, Never>?
    private var endTask: Task<Void, Never>?

    init(settings: AppSettings) {
        self.settings = settings
        for player in players {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }
        observe()
    }

    // MARK: - Workout

    /// Without sound and voice nothing is played, not even silence (TECH T2).
    func begin() {
        endTask?.cancel()
        guard settings.soundSet != nil || settings.voicePrompts else { return end() }
        isActive = true
        configure(ducked: false)
        // Rendering takes a moment; do it before the first signal, not on it.
        if let set = settings.soundSet { SoundCue.allCases.forEach { _ = buffer($0, set) } }
    }

    func end() {
        endTask?.cancel()
        unduckTask?.cancel()
        guard isActive else { return }
        isActive = false
        isDucked = false
        speech.stopSpeaking(at: .immediate)
        players.forEach { $0.stop() }
        engine.stop()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// "3-2-1": spoken when the voice is on, otherwise a tick.
    func countdown(_ secondsLeft: Int) {
        vibrate(strong: false)
        if settings.voicePrompts {
            speak(String(secondsLeft))
        } else {
            play(.countdown)
        }
    }

    /// Signal for the step type, then the step name.
    func stepStarted(_ step: PlannedStep) {
        vibrate(strong: true)
        let signal = play(SoundCue(step.type))
        speak(step.step.name, after: signal)
    }

    /// Plays the finish signal and releases the audio once it is over.
    func finished() {
        vibrate(strong: true)
        let signal = play(.finish)
        endTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(signal + 1))
            guard !Task.isCancelled else { return }
            self?.end()
        }
    }

    /// Sample of a sound set in Settings.
    func preview(_ set: SoundSet) {
        let temporary = !isActive || endTask != nil
        if !isActive {
            isActive = true
            configure(ducked: false)
        }
        let length = play(.work, set: set)
        guard temporary else { return }
        endTask?.cancel()
        endTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(length + 1))
            guard !Task.isCancelled else { return }
            self?.end()
        }
    }

    /// The app is back in front: restart audio if an interruption ended without notice.
    func resumeIfNeeded() {
        guard isActive, !engine.isRunning || isDucked else { return }
        configure(ducked: false)
    }

    // MARK: - Playback

    /// Returns the sound's length in seconds, 0 when nothing played.
    @discardableResult
    private func play(_ cue: SoundCue, set: SoundSet? = nil) -> TimeInterval {
        guard isActive, let set = set ?? settings.soundSet else { return 0 }
        duck()
        let buffer = buffer(cue, set)
        let player = cue == .countdown ? tickPlayer : stepPlayer
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying { player.play() }
        let length = TimeInterval(buffer.frameLength) / SoundSynth.sampleRate
        scheduleUnduck(after: length)
        return length
    }

    private func speak(_ text: String, after delay: TimeInterval = 0) {
        guard isActive, settings.voicePrompts, !text.isEmpty else { return }
        duck()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.voice
        utterance.preUtteranceDelay = delay
        speech.stopSpeaking(at: .immediate)
        speech.speak(utterance)
        scheduleUnduck(after: delay + 0.5)
    }

    private func vibrate(strong: Bool) {
        guard settings.vibration else { return }
        // 1519 is the short "peek" tap; the standard vibration marks a new step.
        AudioServicesPlaySystemSound(strong ? kSystemSoundID_Vibrate : 1519)
    }

    private func buffer(_ cue: SoundCue, _ set: SoundSet) -> AVAudioPCMBuffer {
        let key = "\(set.rawValue).\(cue)"
        if let buffer = buffers[key] { return buffer }
        let samples = SoundSynth.samples(cue, in: set)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = buffer.frameCapacity
        samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
        buffers[key] = buffer
        return buffer
    }

    /// The voice speaks the interface language (SPEC D12).
    private static var voice: AVSpeechSynthesisVoice? {
        let language = Bundle.main.preferredLocalizations.first ?? "en"
        let current = AVSpeechSynthesisVoice.currentLanguageCode()
        if current.hasPrefix(language) { return AVSpeechSynthesisVoice(language: current) }
        return AVSpeechSynthesisVoice.speechVoices().first { $0.language.hasPrefix(language) }
    }

    // MARK: - Session

    /// Music is ducked for the signal, not for the whole workout (SPEC D5).
    private func duck() {
        unduckTask?.cancel()
        // The ambient category never ducks: restarting would only cut the sound just scheduled.
        guard settings.ignoreSilentMode else {
            if !engine.isRunning { configure(ducked: false) }
            return
        }
        guard !isDucked else { return }
        configure(ducked: true)
    }

    /// Countdown and step signal come close together, so the music returns only after a quiet second.
    private func scheduleUnduck(after delay: TimeInterval) {
        unduckTask?.cancel()
        unduckTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay + 1))
            while self?.speech.isSpeaking == true, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(300))
            }
            guard !Task.isCancelled, let self, self.isDucked else { return }
            // Restarting the session in the background lets iOS suspend the app mid-workout,
            // so the music stays ducked until the app is back in front or the workout ends.
            guard UIApplication.shared.applicationState == .active else { return }
            self.configure(ducked: false)
        }
    }

    /// Ducking is applied on activation, so the session is restarted to switch it.
    private func configure(ducked: Bool) {
        // "Ignore Silent Mode" off follows the switch, but iOS then also silences the app on the lock screen.
        let ignoreSilent = settings.ignoreSilentMode
        let wasRunning = engine.isRunning
        if wasRunning {
            players.forEach { $0.stop() }
            engine.stop()
            try? session.setActive(false)
        }
        do {
            if ignoreSilent {
                try session.setCategory(.playback, options: ducked ? [.mixWithOthers, .duckOthers] : [.mixWithOthers])
            } else {
                try session.setCategory(.ambient)
            }
            try session.setActive(true)
            try engine.start()
            players.forEach { $0.play() }
            isDucked = ducked && ignoreSilent
        } catch {
            isDucked = false
        }
    }

    private func observe() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: .main) { [weak self] note in
            let info = note.userInfo
            let type = (info?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap(AVAudioSession.InterruptionType.init)
            let reason = (info?[AVAudioSessionInterruptionReasonKey] as? UInt).flatMap(AVAudioSession.InterruptionReason.init)
            MainActor.assumeIsolated { self?.handleInterruption(type, reason: reason) }
        })
        // Headphones and other route changes stop the engine.
        observers.append(center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.resumeIfNeeded() }
        })
        observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.resumeIfNeeded() }
        })
    }

    private func handleInterruption(_ type: AVAudioSession.InterruptionType?, reason: AVAudioSession.InterruptionReason?) {
        guard isActive, let type else { return }
        switch type {
        case .began:
            isDucked = false
            // Delivered late after the app was frozen: nothing actually interrupted the workout.
            if reason == .appWasSuspended { return }
            onInterruptionBegan?()
        case .ended:
            // The workout stays paused (SPEC D6); only the audio comes back.
            configure(ducked: false)
        @unknown default:
            break
        }
    }
}
