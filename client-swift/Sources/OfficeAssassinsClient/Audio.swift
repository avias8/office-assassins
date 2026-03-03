import Observation
@preconcurrency import AVFoundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Music player (two tracks, crossfade)

@MainActor
@Observable
final class MusicPlayer {
    private enum MusicMode {
        case title
        case game
    }

    private struct FadeState {
        let startTime: TimeInterval
        let duration: TimeInterval
        let fromTitleLevel: Float
        let toTitleLevel: Float
        let fromGameLevel: Float
        let toGameLevel: Float
    }

    var isMuted: Bool = false {
        didSet {
            applyEffectiveVolumes()
        }
    }

    private let titleNominalVolume: Float = 0.55
    private let gameNominalVolume: Float = 0.65
    private let fadeTickInterval: TimeInterval = 1.0 / 60.0

    private var titlePlayer: AVAudioPlayer?
    private var gamePlayer: AVAudioPlayer?
    private var mode: MusicMode = .title

    // Logical (unmuted) levels.
    private var titleLevel: Float = 0
    private var gameLevel: Float = 0
    private var fadeState: FadeState?
    private var fadeTimer: Timer?
    private var isInterrupted = false

#if canImport(UIKit)
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var mediaResetObserver: NSObjectProtocol?
#endif

    init() {
        titlePlayer = makePlayer(resource: "SpaceTimeDB Survivors", exts: ["m4a", "wav"])
        gamePlayer = makePlayer(resource: "SpaceTimeDB Survivors - Alternate Music", exts: ["m4a", "wav"])
        applyEffectiveVolumes()
        installInterruptionObserversIfSupported()
    }

    func playTitle() {
        transition(to: .title, duration: 2.5, force: true)
    }

    func crossfadeToGame() {
        transition(to: .game, duration: 1.5)
    }

    func switchToTitleMusic() {
        transition(to: .title, duration: 1.0)
    }

    func toggleMute() {
        isMuted.toggle()
    }

    private func transition(to newMode: MusicMode, duration: TimeInterval, force: Bool = false) {
        if !force && mode == newMode && fadeState == nil {
            resumePlayersForCurrentLevels()
            return
        }
        mode = newMode
        if isInterrupted {
            // Defer playback while interrupted; keep logical targets consistent.
            titleLevel = (newMode == .title) ? titleNominalVolume : 0
            gameLevel  = (newMode == .game) ? gameNominalVolume  : 0
            fadeState = nil
            fadeTimer?.invalidate()
            fadeTimer = nil
            applyEffectiveVolumes()
            return
        }
        // During a crossfade both tracks must be playing before we adjust volumes.
        // Ensure the incoming track starts (at its current level) before fading.
        ensurePlayerLoaded(for: .title)
        ensurePlayerLoaded(for: .game)
        startPlaybackIfNeeded(titlePlayer)
        startPlaybackIfNeeded(gamePlayer)
        let targetTitle = (newMode == .title) ? titleNominalVolume : 0
        let targetGame  = (newMode == .game)  ? gameNominalVolume  : 0
        startFade(toTitleLevel: targetTitle, toGameLevel: targetGame, duration: duration)
    }

    private func ensurePlayerLoaded(for mode: MusicMode) {
        switch mode {
        case .title:
            if titlePlayer == nil {
                titlePlayer = makePlayer(resource: "SpaceTimeDB Survivors", exts: ["m4a", "wav"])
                applyEffectiveVolumes()
            }
        case .game:
            if gamePlayer == nil {
                gamePlayer = makePlayer(resource: "SpaceTimeDB Survivors - Alternate Music", exts: ["m4a", "wav"])
                applyEffectiveVolumes()
            }
        }
    }

    private func startPlaybackIfNeeded(_ player: AVAudioPlayer?) {
        guard let player else { return }
        guard !isInterrupted else { return }
        if !player.isPlaying {
            player.prepareToPlay()
            if !player.play() {
                print("[MusicPlayer] Failed to start playback for \(player.url?.lastPathComponent ?? "unknown")")
            }
        }
    }

    private func resumePlayersForCurrentLevels() {
        ensurePlayerLoaded(for: .title)
        ensurePlayerLoaded(for: .game)
        if titleLevel > 0.001 {
            startPlaybackIfNeeded(titlePlayer)
        } else {
            titlePlayer?.pause()
        }
        if gameLevel > 0.001 {
            startPlaybackIfNeeded(gamePlayer)
        } else {
            gamePlayer?.pause()
        }
        applyEffectiveVolumes()
    }

    private func startFade(toTitleLevel: Float, toGameLevel: Float, duration: TimeInterval) {
        fadeTimer?.invalidate()
        fadeTimer = nil

        let clampedDuration = max(0, duration)
        if clampedDuration == 0 {
            titleLevel = toTitleLevel
            gameLevel = toGameLevel
            applyEffectiveVolumes()
            pauseSilentPlayers(titleTarget: toTitleLevel, gameTarget: toGameLevel)
            return
        }

        fadeState = FadeState(
            startTime: Date.timeIntervalSinceReferenceDate,
            duration: clampedDuration,
            fromTitleLevel: titleLevel,
            toTitleLevel: toTitleLevel,
            fromGameLevel: gameLevel,
            toGameLevel: toGameLevel
        )

        let timer = Timer(timeInterval: fadeTickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tickFade()
            }
        }
        fadeTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func tickFade() {
        guard let fade = fadeState else { return }
        let now = Date.timeIntervalSinceReferenceDate
        let t = Float(max(0, min(1, (now - fade.startTime) / fade.duration)))
        titleLevel = fade.fromTitleLevel + (fade.toTitleLevel - fade.fromTitleLevel) * t
        gameLevel = fade.fromGameLevel + (fade.toGameLevel - fade.fromGameLevel) * t
        applyEffectiveVolumes()

        if t >= 1 {
            let finishedTitleTarget = fade.toTitleLevel
            let finishedGameTarget  = fade.toGameLevel
            fadeState = nil
            fadeTimer?.invalidate()
            fadeTimer = nil
            pauseSilentPlayers(titleTarget: finishedTitleTarget, gameTarget: finishedGameTarget)
        }
    }

    /// Pauses whichever player faded down to silence.
    /// Taking the targets as parameters avoids reading `fadeState` after it is cleared.
    private func pauseSilentPlayers(titleTarget: Float, gameTarget: Float) {
        if titleTarget <= 0.001 { titlePlayer?.pause() }
        if gameTarget  <= 0.001 { gamePlayer?.pause()  }
    }

    private func applyEffectiveVolumes() {
        let titleVolume = isMuted ? 0 : titleLevel
        let gameVolume = isMuted ? 0 : gameLevel
        titlePlayer?.volume = titleVolume
        gamePlayer?.volume = gameVolume
    }

    private func makePlayer(resource: String, exts: [String]) -> AVAudioPlayer? {
        for ext in exts {
            guard let url = Bundle.resourceBundle.url(forResource: resource, withExtension: ext) else { continue }
            let player = try? AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1
            player?.prepareToPlay()
            if player != nil {
                return player
            }
        }
        print("[MusicPlayer] Missing or unreadable resource: \(resource)")
        return nil
    }

#if canImport(UIKit)
    // MARK: - iOS audio session interruption (calls/Siri/alarms)
    private func installInterruptionObserversIfSupported() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let info = notification.userInfo
            let rawType = info?[AVAudioSessionInterruptionTypeKey] as? UInt
            let rawOptions = info?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor [weak self] in
                self?.handleAudioInterruption(rawType: rawType, rawOptions: rawOptions)
            }
        }
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.isInterrupted else { return }
                self.resumePlayersForCurrentLevels()
            }
        }
        mediaResetObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.titlePlayer = self.makePlayer(resource: "SpaceTimeDB Survivors", exts: ["m4a", "wav"])
                self.gamePlayer = self.makePlayer(resource: "SpaceTimeDB Survivors - Alternate Music", exts: ["m4a", "wav"])
                self.resumePlayersForCurrentLevels()
            }
        }
    }

    private func handleAudioInterruption(rawType: UInt?, rawOptions: UInt?) {
        guard let rawType,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
            return
        }

        switch type {
        case .began:
            isInterrupted = true
            // Snap any active fade to its target so state remains deterministic.
            if let fade = fadeState {
                titleLevel = fade.toTitleLevel
                gameLevel = fade.toGameLevel
                fadeState = nil
                fadeTimer?.invalidate()
                fadeTimer = nil
            }
            titlePlayer?.pause()
            gamePlayer?.pause()
        case .ended:
            let shouldResume = rawOptions
                .map { AVAudioSession.InterruptionOptions(rawValue: $0).contains(.shouldResume) } ?? false
            isInterrupted = false
            if shouldResume {
                resumePlayersForCurrentLevels()
            }
        @unknown default:
            break
        }
    }
#else
    // MARK: - macOS audio route / hardware change recovery
    // macOS has no AVAudioSession, but hardware route changes (e.g. headphones
    // plug/unplug, Bluetooth handoff, display sleep) can silently reset the
    // underlying audio unit and cause players to stop. We recover by observing
    // AVAudioPlayer's notification and restarting playback if needed.
    private var routeChangeObserver: NSObjectProtocol?

    private func installInterruptionObserversIfSupported() {
        // AVAudioPlayer doesn't stop on macOS route changes, but we watch for
        // app-level background/foreground transitions that can drop the audio
        // device on macOS (e.g. display sleep on Apple Silicon).
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // If the player silently stopped while the app was inactive, restart.
                self.isInterrupted = false
                self.resumePlayersForCurrentLevels()
            }
        }
    }
#endif
}

// MARK: - Sound Effects

/// Synthesizes all UI sound effects using AVAudioEngine.
///
/// Design goals / robustness:
/// - All PCM buffers are pre-synthesized on a background thread at init, so
///   `play()` only schedules a pre-built buffer — zero main-thread synthesis.
/// - A fixed pool of `AVAudioPlayerNode`s per sound handles polyphonic rapid
///   repeats (e.g. picking up several weapons in a row) without any node leak.
/// - Handles `AVAudioEngineConfigurationChangeNotification` (headphones
///   plug/unplug, BT route change, sleep/wake on macOS) by restarting the
///   engine and re-attaching all nodes automatically.
/// - A silent warm-up buffer is played at start so the audio graph is fully
///   active before the first real sound fires.
@MainActor
final class SoundEffects {
    static let shared = SoundEffects()

    enum Sound: CaseIterable {
        case buttonPress    // soft 2-note chime C5→E5
        case menuButton     // slightly lower chime B4→D5
        case enterArena     // rising major arpeggio C5 E5 G5
        case menuOpen       // descending minor 2nd E5→Eb5
        case menuClose      // ascending perfect 4th C5→F5
        case respawn        // bright 4-note fanfare C5 E5 G5 C6
        case weaponPickup   // metallic ting (high sine, fast decay)
        case attack         // percussive thwack (low sawtooth)
        case death          // dramatic descending tritone swell
        case muteToggle     // single muffled pop
    }

    var isMuted = false {
        didSet {
            if !isMuted {
                flushPendingSounds()
            }
        }
    }

    // MARK: - Private

    private let engine = AVAudioEngine()
    private var mixer: AVAudioMixerNode { engine.mainMixerNode }
    /// Permanent node used to keep a valid graph before any SFX pool exists.
    private let bootstrapNode = AVAudioPlayerNode()

    /// Each sound gets a small round-robin pool of player nodes so rapid
    /// repeats of the same sound overlap cleanly without node thrash.
    private var pools: [Sound: NodePool] = [:]

    /// Pre-built PCM buffers, keyed by sound. Set from background thread,
    /// then only read on main actor, so access is safe after init completes.
    private var buffers: [Sound: AVAudioPCMBuffer] = [:]
    private var buffersReady = false
    private var pendingSounds: [Sound] = []
    private let maxPendingSounds = 24
    private var isEngineInterrupted = false
    private var lastPlayedAt: [Sound: TimeInterval] = [:]
    private var burstWindow: [Sound: (start: TimeInterval, count: Int)] = [:]
    private var globalBurstWindow: (start: TimeInterval, count: Int) = (start: 0, count: 0)

    private var configChangeObserver: NSObjectProtocol?
#if canImport(UIKit)
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var mediaResetObserver: NSObjectProtocol?
#else
    private var appActiveObserver: NSObjectProtocol?
#endif

    private init() {
        ensureBootstrapAttached()
        // Start the engine immediately so the output node format is available.
        restartEngine()
        // Synthesize buffers + warm up on a background thread.
        buildBuffersAndWarmUp()
        // Receive route-change / config-reset notifications.
        configChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.handleEngineReset() }
        }
        installInterruptionObserversIfSupported()
    }

    // MARK: - Public API

    func play(_ sound: Sound) {
        guard !isMuted else { return }
        let now = monotonicNow()
        guard !shouldDrop(sound: sound, now: now) else { return }
        guard consumeGlobalBudget(now: now) else { return }
        guard buffersReady, !isEngineInterrupted else {
            enqueuePending(sound)
            return
        }
        playNow(sound)
    }

    // MARK: - Engine lifecycle

    private func restartEngine() {
        ensureBootstrapAttached()
        if engine.isRunning { engine.stop() }
        do {
            // With bootstrap node attached, start is safe on macOS and iOS.
            try engine.start()
        } catch {
            print("[SoundEffects] AVAudioEngine start failed: \(error)")
        }
    }

    private func handleEngineReset() {
        recoverEngine()
        flushPendingSounds()
    }

    // MARK: - Pool management

    private func pool(for sound: Sound) -> NodePool {
        if let existing = pools[sound] { return existing }
        let p = NodePool(size: poolSize(for: sound), engine: engine, mixer: mixer)
        pools[sound] = p
        return p
    }

    private func poolSize(for sound: Sound) -> Int {
        switch sound {
        case .weaponPickup: return 2
        case .attack:       return 2
        default:            return 2
        }
    }

    // MARK: - Buffer synthesis (background)

    private func buildBuffersAndWarmUp() {
        // Capture definitions as sendable value types for the background task.
        let definitions = SoundEffects.soundDefinitions()
        Task.detached(priority: .userInitiated) {
            var built: [Sound: AVAudioPCMBuffer] = [:]
            for (sound, def) in definitions {
                if let buf = Self.synthesize(def) { built[sound] = buf }
            }
            // Deliver results and warm up back on main actor.
            await MainActor.run {
                self.buffers = built
                self.buffersReady = true
                self.warmUpEngine(sampleRate: 44100)
                self.flushPendingSounds()
            }
        }
    }

    /// Play a single frame of silence to prime the audio graph.
    private func warmUpEngine(sampleRate: Double) {
        guard ensureEngineRunning() else { return }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1) else { return }
        buf.frameLength = 1
        buf.floatChannelData![0][0] = 0
        let primer = AVAudioPlayerNode()
        engine.attach(primer)
        engine.connect(primer, to: mixer, format: format)
        primer.play()
        primer.scheduleBuffer(buf, completionCallbackType: .dataRendered) { [weak self] _ in
            Task { @MainActor [weak self] in self?.engine.detach(primer) }
        }
    }

    private func playNow(_ sound: Sound) {
        guard let buffer = buffers[sound] else {
            enqueuePending(sound)
            return
        }
        guard ensureEngineRunning() else {
            enqueuePending(sound)
            return
        }
        let played = pool(for: sound).play(buffer: buffer, through: engine)
        if !played {
            enqueuePending(sound)
        }
    }

    private func enqueuePending(_ sound: Sound) {
        if isBurstProne(sound), pendingSounds.last == sound {
            return
        }
        if pendingSounds.count >= maxPendingSounds {
            pendingSounds.removeFirst(pendingSounds.count - maxPendingSounds + 1)
        }
        pendingSounds.append(sound)
    }

    private func flushPendingSounds() {
        guard !isMuted, buffersReady, !isEngineInterrupted else { return }
        guard !pendingSounds.isEmpty else { return }
        let queued = pendingSounds
        pendingSounds.removeAll(keepingCapacity: true)
        let now = monotonicNow()
        for sound in queued {
            if shouldDrop(sound: sound, now: now) {
                continue
            }
            if !consumeGlobalBudget(now: now) {
                break
            }
            playNow(sound)
        }
    }

    private func monotonicNow() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    private func isBurstProne(_ sound: Sound) -> Bool {
        switch sound {
        case .attack, .weaponPickup:
            return true
        default:
            return false
        }
    }

    private func limits(for sound: Sound) -> (minGap: TimeInterval, maxPerWindow: Int) {
        switch sound {
        case .attack:
            // Combat can emit very dense hits; keep this conservative to avoid
            // audio I/O overload while preserving responsiveness.
            return (0.12, 2)
        case .weaponPickup:
            return (0.10, 2)
        case .menuOpen, .menuClose:
            return (0.08, 2)
        default:
            return (0.0, 8)
        }
    }

    private func shouldDrop(sound: Sound, now: TimeInterval) -> Bool {
        let rule = limits(for: sound)
        if rule.minGap > 0, let last = lastPlayedAt[sound], (now - last) < rule.minGap {
            return true
        }

        let windowDuration: TimeInterval = 0.10
        var state = burstWindow[sound] ?? (start: now, count: 0)
        if (now - state.start) > windowDuration {
            state = (start: now, count: 0)
        }
        if state.count >= rule.maxPerWindow {
            burstWindow[sound] = state
            return true
        }
        state.count += 1
        burstWindow[sound] = state
        lastPlayedAt[sound] = now
        return false
    }

    private func consumeGlobalBudget(now: TimeInterval) -> Bool {
        let windowDuration: TimeInterval = 0.10
        let maxPerWindow = 5
        if (now - globalBurstWindow.start) > windowDuration {
            globalBurstWindow = (start: now, count: 0)
        }
        guard globalBurstWindow.count < maxPerWindow else { return false }
        globalBurstWindow.count += 1
        return true
    }

    private func ensureEngineRunning() -> Bool {
        if engine.isRunning {
            return true
        }
        recoverEngine()
        return engine.isRunning
    }

    private func recoverEngine() {
        ensureBootstrapAttached()
        for pool in pools.values {
            pool.reattach(to: engine, mixer: mixer)
        }
        restartEngine()
    }

    private func ensureBootstrapAttached() {
        if !engine.attachedNodes.contains(bootstrapNode) {
            engine.attach(bootstrapNode)
            if let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) {
                engine.connect(bootstrapNode, to: mixer, format: format)
            }
        }
    }

    // MARK: - Sound definitions

    private enum Waveform: Sendable { case sine, triangle, sawtooth }

    private struct NoteSpec: Sendable {
        let freq: Double; let start: Double; let dur: Double
    }
    private struct SoundDef: Sendable {
        let notes: [NoteSpec]; let wave: Waveform; let gain: Float
    }

    private static func soundDefinitions() -> [(Sound, SoundDef)] {
        [
            (.buttonPress,   .init(notes: [.init(freq: 523.25, start: 0.00, dur: 0.06),
                                           .init(freq: 659.25, start: 0.06, dur: 0.06)],
                                   wave: .sine, gain: 0.18)),
            (.menuButton,    .init(notes: [.init(freq: 493.88, start: 0.00, dur: 0.05),
                                           .init(freq: 587.33, start: 0.05, dur: 0.06)],
                                   wave: .sine, gain: 0.14)),
            (.enterArena,    .init(notes: [.init(freq: 523.25, start: 0.00, dur: 0.07),
                                           .init(freq: 659.25, start: 0.07, dur: 0.07),
                                           .init(freq: 783.99, start: 0.14, dur: 0.10)],
                                   wave: .sine, gain: 0.20)),
            (.menuOpen,      .init(notes: [.init(freq: 659.25, start: 0.00, dur: 0.05),
                                           .init(freq: 622.25, start: 0.05, dur: 0.08)],
                                   wave: .triangle, gain: 0.15)),
            (.menuClose,     .init(notes: [.init(freq: 523.25, start: 0.00, dur: 0.05),
                                           .init(freq: 698.46, start: 0.05, dur: 0.08)],
                                   wave: .triangle, gain: 0.15)),
            (.respawn,       .init(notes: [.init(freq: 523.25, start: 0.00, dur: 0.07),
                                           .init(freq: 659.25, start: 0.07, dur: 0.07),
                                           .init(freq: 783.99, start: 0.14, dur: 0.07),
                                           .init(freq: 1046.5, start: 0.21, dur: 0.14)],
                                   wave: .sine, gain: 0.22)),
            (.weaponPickup,  .init(notes: [.init(freq: 1174.66, start: 0.00, dur: 0.04),
                                           .init(freq: 1396.91, start: 0.03, dur: 0.05)],
                                   wave: .sine, gain: 0.25)),
            (.attack,        .init(notes: [.init(freq: 180.0,  start: 0.00, dur: 0.03),
                                           .init(freq: 120.0,  start: 0.03, dur: 0.04)],
                                   wave: .sawtooth, gain: 0.28)),
            (.death,         .init(notes: [.init(freq: 440.0,  start: 0.00, dur: 0.12),
                                           .init(freq: 311.13, start: 0.10, dur: 0.14),
                                           .init(freq: 220.0,  start: 0.22, dur: 0.20)],
                                   wave: .triangle, gain: 0.30)),
            (.muteToggle,    .init(notes: [.init(freq: 300.0,  start: 0.00, dur: 0.04)],
                                   wave: .sine, gain: 0.12)),
        ]
    }

    // MARK: - PCM synthesis (pure function, runs on background thread)

    private nonisolated static func synthesize(_ def: SoundDef) -> AVAudioPCMBuffer? {
        let sampleRate: Double = 44100
        let totalDuration = def.notes.map { $0.start + $0.dur + 0.02 }.max() ?? 0.1
        let frameCount = AVAudioFrameCount(totalDuration * sampleRate)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) { data[i] = 0 }

        for note in def.notes {
            let startFrame  = Int(note.start * sampleRate)
            let noteFrames  = Int(note.dur   * sampleRate)
            let attackFrames  = max(1, Int(min(0.008, note.dur * 0.10) * sampleRate))
            let releaseFrames = max(1, Int(min(0.020, note.dur * 0.25) * sampleRate))

            for i in 0..<noteFrames {
                let gf = startFrame + i
                guard gf < Int(frameCount) else { break }
                let phase = 2.0 * Double.pi * note.freq * Double(i) / sampleRate
                let raw: Double
                switch def.wave {
                case .sine:     raw = sin(phase)
                case .triangle: raw = 2.0 / Double.pi * asin(sin(phase))
                case .sawtooth: raw = 2.0 * (phase / (2 * .pi) - floor(phase / (2 * .pi) + 0.5))
                }
                let env: Double
                if i < attackFrames {
                    env = Double(i) / Double(attackFrames)
                } else if i >= noteFrames - releaseFrames {
                    env = Double(noteFrames - i) / Double(releaseFrames)
                } else {
                    env = 1.0
                }
                data[gf] += Float(raw * env * Double(def.gain))
            }
        }
        return buffer
    }

#if canImport(UIKit)
    private func installInterruptionObserversIfSupported() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            let info = note.userInfo
            let rawType = info?[AVAudioSessionInterruptionTypeKey] as? UInt
            let rawOptions = info?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor [weak self] in
                self?.handleInterruption(rawType: rawType, rawOptions: rawOptions)
            }
        }
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.isEngineInterrupted else { return }
                self.recoverEngine()
                self.flushPendingSounds()
            }
        }
        mediaResetObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isEngineInterrupted = false
                self.recoverEngine()
                self.flushPendingSounds()
            }
        }
    }

    private func handleInterruption(rawType: UInt?, rawOptions: UInt?) {
        guard let rawType,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
            return
        }

        switch type {
        case .began:
            isEngineInterrupted = true
            if engine.isRunning {
                engine.pause()
            }
        case .ended:
            let shouldResume = rawOptions
                .map { AVAudioSession.InterruptionOptions(rawValue: $0).contains(.shouldResume) } ?? false
            isEngineInterrupted = false
            if shouldResume {
                recoverEngine()
                flushPendingSounds()
            }
        @unknown default:
            break
        }
    }
#else
    private func installInterruptionObserversIfSupported() {
        appActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.recoverEngine()
                self?.flushPendingSounds()
            }
        }
    }
#endif
}

// MARK: - NodePool

/// A fixed-size round-robin pool of `AVAudioPlayerNode`s for one sound type.
/// Prevents node exhaustion under rapid repeated triggers.
@MainActor
final class NodePool {
    private var nodes: [AVAudioPlayerNode] = []
    private var cursor = 0
    private weak var engine: AVAudioEngine?
    private weak var mixer: AVAudioMixerNode?

    init(size: Int, engine: AVAudioEngine, mixer: AVAudioMixerNode) {
        self.engine = engine
        self.mixer  = mixer
        nodes = (0..<size).map { _ in Self.makeNode(engine: engine, mixer: mixer) }
    }

    func play(buffer: AVAudioPCMBuffer, through engine: AVAudioEngine) -> Bool {
        guard engine.isRunning else {
            print("[NodePool] Engine not running — skipping sound")
            return false
        }
        let node = nodes[cursor % nodes.count]
        cursor += 1
        // Stop any currently-playing sound on this node slot (round-robin eviction).
        if node.isPlaying { node.stop() }
        node.scheduleBuffer(buffer, at: nil, options: .interrupts)
        node.play()
        return true
    }

    /// Called after an engine configuration reset to re-attach nodes.
    func reattach(to engine: AVAudioEngine, mixer: AVAudioMixerNode) {
        self.engine = engine
        self.mixer  = mixer
        for node in nodes {
            if !engine.attachedNodes.contains(node) {
                Self.attach(node: node, engine: engine, mixer: mixer)
            }
        }
    }

    private static func makeNode(engine: AVAudioEngine, mixer: AVAudioMixerNode) -> AVAudioPlayerNode {
        let node = AVAudioPlayerNode()
        attach(node: node, engine: engine, mixer: mixer)
        return node
    }

    private static func attach(node: AVAudioPlayerNode, engine: AVAudioEngine, mixer: AVAudioMixerNode) {
        engine.attach(node)
        // Use a fixed low-overhead mono format matching our synthesis rate.
        if let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) {
            engine.connect(node, to: mixer, format: format)
        }
    }
}
