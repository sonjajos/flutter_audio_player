import Flutter
import AVFoundation

public class AudioEnginePlugin: NSObject, FlutterPlugin {

    private let player = AudioEnginePlayer()
    private let sessionManager = AudioSessionManager()
    private let nowPlayingService = NowPlayingService()

    // Event sinks
    private var stateSink: FlutterEventSink?
    private var fftSink: FlutterEventSink?
    private var commandSink: FlutterEventSink?

    // Current track info for Now Playing
    private var currentTitle: String = ""
    private var currentArtist: String = ""

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = AudioEnginePlugin()
        instance.setupChannels(registrar: registrar)
    }

    private func setupChannels(registrar: FlutterPluginRegistrar) {
        // Method channel for playback control
        let controlChannel = FlutterMethodChannel(
            name: "audio_player/control",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(self, channel: controlChannel)

        // Event channels
        let stateChannel = FlutterEventChannel(
            name: "audio_player/state",
            binaryMessenger: registrar.messenger()
        )
        stateChannel.setStreamHandler(StreamHandler(
            onListen: { [weak self] sink in self?.stateSink = sink },
            onCancel: { [weak self] in self?.stateSink = nil }
        ))

        let fftChannel = FlutterEventChannel(
            name: "audio_player/fft",
            binaryMessenger: registrar.messenger()
        )
        fftChannel.setStreamHandler(StreamHandler(
            onListen: { [weak self] sink in self?.fftSink = sink },
            onCancel: { [weak self] in self?.fftSink = nil }
        ))

        let commandChannel = FlutterEventChannel(
            name: "audio_player/commands",
            binaryMessenger: registrar.messenger()
        )
        commandChannel.setStreamHandler(StreamHandler(
            onListen: { [weak self] sink in self?.commandSink = sink },
            onCancel: { [weak self] in self?.commandSink = nil }
        ))

        // Configure audio session
        try? sessionManager.configure()

        // Wire up callbacks
        setupCallbacks()
    }

    private func setupCallbacks() {
        // Player state changes → EventChannel
        player.onStateChanged = { [weak self] state, positionMs, durationMs in
            guard let self = self else { return }
            self.stateSink?([
                "state": state,
                "positionMs": positionMs,
                "durationMs": durationMs,
            ])

            // Update Now Playing info
            if !self.currentTitle.isEmpty {
                self.nowPlayingService.updateNowPlaying(
                    title: self.currentTitle,
                    artist: self.currentArtist,
                    durationSeconds: Double(durationMs) / 1000.0,
                    positionSeconds: Double(positionMs) / 1000.0,
                    isPlaying: state == "playing"
                )
            }
        }

        // FFT data → EventChannel
        player.onFFTData = { [weak self] bands, nativeFftTimeUs in
            guard let self = self else { return }
            self.fftSink?([
                "bands": FlutterStandardTypedData(float32: Data(
                    bytes: bands,
                    count: bands.count * MemoryLayout<Float>.size
                )),
                "nativeFftTimeUs": nativeFftTimeUs,
                "timestamp": Int64(CACurrentMediaTime() * 1_000_000),
            ])
        }

        // Track completion
        player.onTrackCompleted = { [weak self] in
            self?.commandSink?("completed")
        }

        // Audio session interruptions
        sessionManager.onInterruption = { [weak self] began, shouldResume in
            guard let self = self else { return }
            if began {
                self.player.pause()
            } else if shouldResume {
                self.player.resume()
            }
        }

        // Now Playing remote commands → EventChannel
        nowPlayingService.setup()
        nowPlayingService.onCommand = { [weak self] command in
            self?.commandSink?(command)
        }
        nowPlayingService.onSeek = { [weak self] positionSeconds in
            let positionMs = Int(positionSeconds * 1000.0)
            self?.player.seek(to: positionMs)
        }
    }

    // MARK: - FlutterPlugin Method Call Handler

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]

        switch call.method {
        case "play":
            guard let filePath = args?["filePath"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "filePath required", details: nil))
                return
            }
            // Store track info for Now Playing
            currentTitle = args?["title"] as? String ?? "Unknown"
            currentArtist = args?["artist"] as? String ?? "Unknown"

            do {
                try player.load(filePath: filePath)
                player.play()
                result(nil)
            } catch {
                result(FlutterError(code: "PLAY_ERROR", message: error.localizedDescription, details: nil))
            }

        case "pause":
            player.pause()
            result(nil)

        case "resume":
            player.resume()
            result(nil)

        case "stop":
            player.stop()
            nowPlayingService.clearNowPlaying()
            result(nil)

        case "seek":
            guard let positionMs = args?["positionMs"] as? Int else {
                result(FlutterError(code: "INVALID_ARGS", message: "positionMs required", details: nil))
                return
            }
            player.seek(to: positionMs)
            result(nil)

        case "setBandCount":
            guard let count = args?["count"] as? Int else {
                result(FlutterError(code: "INVALID_ARGS", message: "count required", details: nil))
                return
            }
            player.setBandCount(count)
            result(nil)

        case "listAudioFiles":
            let fm = FileManager.default
            guard let documentsDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
                result([String]())
                return
            }
            let audioDir = documentsDir.appendingPathComponent("audio_files")
            do {
                let files = try fm.contentsOfDirectory(atPath: audioDir.path)
                let audioExtensions = Set(["mp3", "m4a", "wav", "aac", "flac", "ogg", "aiff"])
                let audioPaths = files
                    .filter { audioExtensions.contains(($0 as NSString).pathExtension.lowercased()) }
                    .map { audioDir.appendingPathComponent($0).path }
                result(audioPaths)
            } catch {
                result([String]())
            }

        case "getMetadata":
            guard let filePath = args?["filePath"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "filePath required", details: nil))
                return
            }
            AudioEnginePlugin.extractMetadata(filePath: filePath, result: result)

        case "copyToDocuments":
            guard let filePath = args?["filePath"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "filePath required", details: nil))
                return
            }
            AudioEnginePlugin.copyFileToDocuments(filePath: filePath, result: result)

        case "deleteFile":
            guard let filePath = args?["filePath"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "filePath required", details: nil))
                return
            }
            let fm = FileManager.default
            do {
                if fm.fileExists(atPath: filePath) {
                    try fm.removeItem(atPath: filePath)
                }
                result(nil)
            } catch {
                result(FlutterError(code: "DELETE_ERROR", message: error.localizedDescription, details: nil))
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - File Operations

    private static func copyFileToDocuments(filePath: String, result: @escaping FlutterResult) {
        let fm = FileManager.default
        guard let documentsDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            result(FlutterError(code: "DIR_ERROR", message: "Cannot access Documents directory", details: nil))
            return
        }

        let audioDir = documentsDir.appendingPathComponent("audio_files")
        do {
            if !fm.fileExists(atPath: audioDir.path) {
                try fm.createDirectory(at: audioDir, withIntermediateDirectories: true)
            }

            let sourceURL = URL(fileURLWithPath: filePath)
            let fileName = sourceURL.lastPathComponent
            var destURL = audioDir.appendingPathComponent(fileName)

            // Avoid overwriting: append number if file exists
            var counter = 1
            let nameWithoutExt = destURL.deletingPathExtension().lastPathComponent
            let ext = destURL.pathExtension
            while fm.fileExists(atPath: destURL.path) {
                let newName = "\(nameWithoutExt)_\(counter).\(ext)"
                destURL = audioDir.appendingPathComponent(newName)
                counter += 1
            }

            try fm.copyItem(at: sourceURL, to: destURL)
            result(destURL.path)
        } catch {
            result(FlutterError(code: "COPY_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    // MARK: - Metadata Extraction

    private static func extractMetadata(filePath: String, result: @escaping FlutterResult) {
        let url = URL(fileURLWithPath: filePath)

        // Get duration from AVAudioFile (fast, no async)
        var durationMs: Int = 0
        if let audioFile = try? AVAudioFile(forReading: url) {
            let frames = audioFile.length
            let sampleRate = audioFile.processingFormat.sampleRate
            durationMs = Int(Double(frames) / sampleRate * 1000.0)
        }

        // Get ID3/MP4 metadata from AVAsset
        let asset = AVAsset(url: url)
        var title: String?
        var artist: String?

        // Synchronous metadata read via commonMetadata
        let metadata = asset.commonMetadata
        for item in metadata {
            if item.commonKey == .commonKeyTitle {
                title = item.stringValue
            } else if item.commonKey == .commonKeyArtist {
                artist = item.stringValue
            }
        }

        // Fallback title to filename
        if title == nil || title!.isEmpty {
            title = url.deletingPathExtension().lastPathComponent
        }

        result([
            "title": title ?? "Unknown",
            "artist": artist ?? "Unknown Artist",
            "durationMs": durationMs,
        ])
    }
}

// MARK: - Stream Handler Helper

private class StreamHandler: NSObject, FlutterStreamHandler {
    private let onListenHandler: (@escaping FlutterEventSink) -> Void
    private let onCancelHandler: () -> Void

    init(onListen: @escaping (@escaping FlutterEventSink) -> Void, onCancel: @escaping () -> Void) {
        self.onListenHandler = onListen
        self.onCancelHandler = onCancel
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        onListenHandler(events)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        onCancelHandler()
        return nil
    }
}
