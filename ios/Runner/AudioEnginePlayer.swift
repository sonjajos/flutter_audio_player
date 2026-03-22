import AVFoundation
import Accelerate

enum PlaybackState: String {
    case idle
    case playing
    case paused
    case stopped
}

/// Callback types for communicating state and data back to the plugin layer.
typealias StateCallback = (_ state: String, _ positionMs: Int, _ durationMs: Int) -> Void
typealias FFTCallback = (_ bands: [Float], _ nativeFftTimeUs: Int64) -> Void
typealias CompletionCallback = () -> Void

class AudioEnginePlayer {

    // MARK: - Audio Engine

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var audioFile: AVAudioFile?

    // MARK: - Playback State

    private(set) var playbackState: PlaybackState = .idle
    private var seekFrameOffset: AVAudioFramePosition = 0
    private var fileDurationMs: Int = 0
    private var fileSampleRate: Double = 44100.0
    private var fileTotalFrames: AVAudioFramePosition = 0
    private var loadGeneration: Int = 0

    // MARK: - Position Timer

    private var positionTimer: Timer?

    // MARK: - FFT Configuration

    private var bandCount: Int = 32
    private let fftSize: Int = 4096
    private var fftSetup: FFTSetup?
    private var log2n: vDSP_Length = 0
    private var window: [Float] = []
    private let fftQueue = DispatchQueue(label: "com.audioplayer.fft", qos: .userInteractive)

    // Pre-allocated FFT buffers
    private var fftRealp: [Float] = []
    private var fftImagp: [Float] = []
    private var magnitudes: [Float] = []

    // (no adaptive state needed — normalization is per-frame relative to peak)

    // MARK: - Callbacks

    var onStateChanged: StateCallback?
    var onFFTData: FFTCallback?
    var onTrackCompleted: CompletionCallback?

    // MARK: - Init

    init() {
        setupFFT()
        setupEngine()
    }

    deinit {
        positionTimer?.invalidate()
        removeTap()
        engine.stop()
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
    }

    // MARK: - Engine Setup

    private func setupEngine() {
        engine.attach(playerNode)
    }

    private func connectNodes(format: AVAudioFormat) {
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
    }

    // MARK: - FFT Setup

    private func setupFFT() {
        log2n = vDSP_Length(log2(Float(fftSize)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))

        // Hann window
        window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        // Pre-allocate buffers
        let halfN = fftSize / 2
        fftRealp = [Float](repeating: 0, count: halfN)
        fftImagp = [Float](repeating: 0, count: halfN)
        magnitudes = [Float](repeating: 0, count: halfN)
    }

    // MARK: - Public API

    func load(filePath: String) throws {
        // Invalidate any pending completion callbacks from the previous track
        loadGeneration += 1

        // Stop current playback and engine before loading a new track
        playerNode.stop()
        stopPositionTimer()
        removeTap()
        engine.disconnectNodeOutput(playerNode)
        if engine.isRunning {
            engine.stop()
        }
        engine.reset()
        engine.attach(playerNode)

        let url = URL(fileURLWithPath: filePath)
        audioFile = try AVAudioFile(forReading: url)

        guard let file = audioFile else { return }

        fileSampleRate = file.processingFormat.sampleRate
        fileTotalFrames = file.length
        fileDurationMs = Int(Double(fileTotalFrames) / fileSampleRate * 1000.0)
        seekFrameOffset = 0
        playbackState = .idle

        // Connect nodes with the file's format
        connectNodes(format: file.processingFormat)

        // Install tap for FFT / PCM data
        installTap(format: file.processingFormat)

        // Prepare and start engine
        engine.prepare()
        try engine.start()

        notifyState()
    }

    func play() {
        guard let file = audioFile else { return }

        // Schedule from current offset
        scheduleFile(from: seekFrameOffset)

        playerNode.play()
        playbackState = .playing

        startPositionTimer()
        notifyState()
    }

    func pause() {
        playerNode.pause()
        // Capture current position before pausing
        seekFrameOffset = currentFramePosition()
        playbackState = .paused

        stopPositionTimer()
        notifyState()
    }

    func resume() {
        playerNode.play()
        playbackState = .playing

        startPositionTimer()
        notifyState()
    }

    func stop() {
        playerNode.stop()
        seekFrameOffset = 0
        playbackState = .stopped

        stopPositionTimer()
        notifyState()
    }

    func seek(to positionMs: Int) {
        let wasPlaying = playbackState == .playing
        playerNode.stop()

        let targetFrame = AVAudioFramePosition(Double(positionMs) / 1000.0 * fileSampleRate)
        seekFrameOffset = min(targetFrame, fileTotalFrames)

        scheduleFile(from: seekFrameOffset)

        if wasPlaying {
            playerNode.play()
            playbackState = .playing
            startPositionTimer()
        } else {
            playbackState = .paused
        }

        notifyState()
    }

    func setBandCount(_ count: Int) {
        bandCount = count
    }

    // MARK: - Position Tracking

    func currentPositionMs() -> Int {
        let frame = currentFramePosition()
        return Int(Double(frame) / fileSampleRate * 1000.0)
    }

    private func currentFramePosition() -> AVAudioFramePosition {
        guard playbackState == .playing || playbackState == .paused else {
            return seekFrameOffset
        }

        guard let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else {
            return seekFrameOffset
        }

        let currentFrame = seekFrameOffset + playerTime.sampleTime
        return min(max(currentFrame, 0), fileTotalFrames)
    }

    private func startPositionTimer() {
        positionTimer?.invalidate()
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.notifyState()
        }
    }

    private func stopPositionTimer() {
        positionTimer?.invalidate()
        positionTimer = nil
    }

    // MARK: - Schedule Playback

    private func scheduleFile(from frameOffset: AVAudioFramePosition) {
        guard let file = audioFile else { return }

        let remainingFrames = fileTotalFrames - frameOffset
        guard remainingFrames > 0 else { return }

        let generation = loadGeneration

        playerNode.scheduleSegment(
            file,
            startingFrame: frameOffset,
            frameCount: AVAudioFrameCount(remainingFrames),
            at: nil,
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self,
                      self.loadGeneration == generation,
                      self.playbackState == .playing else { return }
                self.playbackState = .stopped
                self.seekFrameOffset = 0
                self.stopPositionTimer()
                self.notifyState()
                self.onTrackCompleted?()
            }
        }
    }

    // MARK: - Audio Tap + FFT

    private func installTap(format: AVAudioFormat) {
        removeTap()

        // Tap with the mixer's native format (preserves stereo)
        engine.mainMixerNode.installTap(
            onBus: 0,
            bufferSize: AVAudioFrameCount(fftSize),
            format: nil
        ) { [weak self] buffer, _ in
            guard let self = self else { return }

            let frameLength = Int(buffer.frameLength)
            guard frameLength > 0,
                  let channelData = buffer.floatChannelData else { return }

            let count = min(frameLength, self.fftSize)
            let channelCount = Int(buffer.format.channelCount)

            // Mix all channels to mono
            var monoSamples = [Float](repeating: 0, count: count)
            for ch in 0..<channelCount {
                let chPtr = channelData[ch]
                for i in 0..<count {
                    monoSamples[i] += chPtr[i]
                }
            }
            if channelCount > 1 {
                var divisor = Float(channelCount)
                vDSP_vsdiv(monoSamples, 1, &divisor, &monoSamples, 1, vDSP_Length(count))
            }

            self.fftQueue.async {
                self.processFFT(samples: monoSamples)
            }
        }
    }

    private func removeTap() {
        engine.mainMixerNode.removeTap(onBus: 0)
    }

    private func processFFT(samples: [Float]) {
        let startTime = CACurrentMediaTime()
        let halfN = fftSize / 2

        // Copy samples into windowed buffer (zero-pad if needed)
        var windowed = [Float](repeating: 0, count: fftSize)
        let sampleCount = min(samples.count, fftSize)
        for i in 0..<sampleCount {
            windowed[i] = samples[i]
        }

        // Apply Hann window
        vDSP_vmul(windowed, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        // Convert real signal to split complex form for vDSP_fft_zrip
        // vDSP_ctoz treats the input as interleaved complex pairs:
        // [r0, r1, r2, r3, ...] → realp = [r0, r2, ...], imagp = [r1, r3, ...]
        windowed.withUnsafeBufferPointer { ptr in
            ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { complexPtr in
                var split = DSPSplitComplex(realp: &self.fftRealp, imagp: &self.fftImagp)
                vDSP_ctoz(complexPtr, 2, &split, 1, vDSP_Length(halfN))
            }
        }

        // Execute real FFT in-place
        guard let setup = fftSetup else { return }
        var splitComplex = DSPSplitComplex(realp: &fftRealp, imagp: &fftImagp)
        vDSP_fft_zrip(setup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

        // Compute squared magnitudes
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfN))

        // Convert to dB (10 * log10)
        var one: Float = 1.0e-10 // small floor to avoid log(0)
        vDSP_vdbcon(magnitudes, 1, &one, &magnitudes, 1, vDSP_Length(halfN), 0)

        // Logarithmic band grouping
        let bands = logarithmicBandGrouping(magnitudes: magnitudes, bandCount: bandCount, binCount: halfN)

        let endTime = CACurrentMediaTime()
        let fftTimeUs = Int64((endTime - startTime) * 1_000_000)

        DispatchQueue.main.async { [weak self] in
            self?.onFFTData?(bands, fftTimeUs)
        }
    }

    /// Groups FFT magnitude bins into bands using logarithmic spacing.
    /// Low frequencies get fewer bins per band, high frequencies get more.
    /// This matches human auditory perception.
    private func logarithmicBandGrouping(magnitudes: [Float], bandCount: Int, binCount: Int) -> [Float] {
        var bandDbValues = [Float](repeating: -Float.infinity, count: bandCount)

        // Map bands to frequency bins logarithmically
        // Start from bin 3 (~32Hz at 44.1kHz) to skip sub-bass rumble
        let minBin: Float = 3.0
        let maxBin = Float(binCount - 1)
        let logMin = log2(minBin)
        let logMax = log2(maxBin)

        // Pre-compute bin edges to ensure no overlap
        var binEdges = [Int]()
        for i in 0...bandCount {
            let t = Float(i) / Float(bandCount)
            let edge = Int(pow(2.0, logMin + t * (logMax - logMin)))
            // Ensure each band gets at least one new bin
            if let last = binEdges.last {
                binEdges.append(max(edge, last + 1))
            } else {
                binEdges.append(max(edge, Int(minBin)))
            }
        }

        for i in 0..<bandCount {
            let start = binEdges[i]
            let clampedEnd = min(binEdges[i + 1], binCount)

            var sum: Float = 0
            var count = 0
            for j in start..<clampedEnd {
                sum += magnitudes[j]
                count += 1
            }

            if count > 0 {
                bandDbValues[i] = sum / Float(count)
            }
        }

        // Find the actual dB range in this frame
        let validValues = bandDbValues.filter { $0 > -Float.infinity }
        guard !validValues.isEmpty else {
            return [Float](repeating: 0, count: bandCount)
        }

        let frameMax = validValues.max()!

        // Use a fixed floor relative to the peak — gives consistent dynamic range
        // 60 dB below peak ensures quiet bands are near zero
        let dbFloor = frameMax - 60.0

        // Normalize each band with a power curve to exaggerate differences
        var bands = [Float](repeating: 0, count: bandCount)
        for i in 0..<bandCount {
            if bandDbValues[i] > -Float.infinity {
                let normalized = (bandDbValues[i] - dbFloor) / 60.0
                let clamped = max(0.0, min(1.0, normalized))
                // Power curve (square) makes quiet bands quieter, loud bands louder
                bands[i] = clamped * clamped
            }
        }

        return bands
    }

    // MARK: - State Notification

    private func notifyState() {
        let posMs = currentPositionMs()
        onStateChanged?(playbackState.rawValue, posMs, fileDurationMs)
    }
}
