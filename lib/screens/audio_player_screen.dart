import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../widgets/playback_controls.dart';
import '../widgets/circular_visualizer.dart';
import '../widgets/waveform_seeker.dart';
import '../services/audio_player_service.dart';
import '../services/waveform_ffi.dart';

class AudioPlayerScreen extends ConsumerStatefulWidget {
  const AudioPlayerScreen({super.key});

  @override
  ConsumerState<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends ConsumerState<AudioPlayerScreen>
    with WidgetsBindingObserver {
  final _visualizerKey = GlobalKey<PillarVisualizerState>();
  StreamSubscription<FFTEvent>? _fftSub;
  StreamSubscription<PlayerStateEvent>? _stateSub;
  StreamSubscription<String>? _commandSub;

  List<double>? _waveformPeaks;
  String? _waveformTrackPath; // track which file peaks belong to

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscribeStreams();
    // Load waveform for any track that's already playing when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final track = ref.read(audioTrackNotifierProvider).currentTrack;
      if (track != null) _loadWaveform(track.filePath);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelStreams();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App is going to background — cancel ALL streams.
      // Native side stops everything too, so nothing to consume.
      _cancelStreams();
    } else if (state == AppLifecycleState.resumed) {
      // App is back — resubscribe to all streams.
      _subscribeStreams();
    }
  }

  Future<void> _loadWaveform(String filePath) async {
    if (_waveformTrackPath == filePath) return; // already loaded
    setState(() {
      _waveformPeaks = null;
      _waveformTrackPath = filePath;
    });
    final service = ref.read(audioPlayerServiceProvider);
    try {
      final pcm = await service.decodePCM(filePath);
      debugPrint('[WaveformDebug] decodePCM returned ${pcm.length} samples');
      if (!mounted) return;
      if (pcm.isEmpty) {
        debugPrint('[WaveformDebug] PCM is empty — skipping FFI call');
        return;
      }
      final peaks = WaveformFFI.generatePeaks(pcm, 300);
      debugPrint(
        '[WaveformDebug] FFI generatePeaks returned ${peaks.length} peaks',
      );
      if (!mounted) return;
      setState(() => _waveformPeaks = peaks);
    } catch (e, st) {
      debugPrint('[WaveformDebug] ERROR: $e\n$st');
    }
  }

  void _subscribeStreams() {
    final service = ref.read(audioPlayerServiceProvider);

    // Listen to native playback state
    _stateSub = service.stateStream.listen((event) {
      ref
          .read(audioTrackNotifierProvider.notifier)
          .updateFromNativeState(event);
    });

    // Listen to remote commands (lock screen + track completion)
    _commandSub = service.commandStream.listen((command) {
      final notifier = ref.read(audioTrackNotifierProvider.notifier);
      switch (command) {
        case 'play':
          notifier.resume();
        case 'pause':
          notifier.pause();
        case 'next':
          notifier.next();
        case 'previous':
          notifier.previous();
        case 'completed':
          notifier.next();
      }
    });

    // Subscribe to native FFT stream
    _fftSub = service.fftStream.listen((event) {
      _visualizerKey.currentState?.updateBands(event.bands);
    });
  }

  void _cancelStreams() {
    _fftSub?.cancel();
    _stateSub?.cancel();
    _commandSub?.cancel();
  }

  void _cycleBandCount() {
    const counts = [16, 32, 64, 128];
    final current = ref.read(bandCountProvider);
    final index = counts.indexOf(current);
    final next = counts[(index + 1) % counts.length];
    ref.read(bandCountProvider.notifier).state = next;
    ref.read(audioPlayerServiceProvider).setBandCount(next);
  }

  @override
  Widget build(BuildContext context) {
    // React to track changes — load waveform only when currentTrack changes
    ref.listen(audioTrackNotifierProvider.select((s) => s.currentTrack), (
      prev,
      next,
    ) {
      if (next != null && next.filePath != prev?.filePath) {
        _loadWaveform(next.filePath);
      }
    });

    final trackState = ref.watch(audioTrackNotifierProvider);
    final currentTrack = trackState.currentTrack;
    final bandCount = ref.watch(bandCountProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Now Playing'),
        actions: [
          TextButton(
            onPressed: _cycleBandCount,
            child: Text(
              '${bandCount * 2}b',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
      body: currentTrack == null
          ? const Center(
              child: Text(
                'No track selected',
                style: TextStyle(color: Colors.white54),
              ),
            )
          : Column(
              children: [
                const SizedBox(height: 32),
                Text(
                  currentTrack.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  currentTrack.artist,
                  style: const TextStyle(color: Colors.white54, fontSize: 16),
                ),
                const SizedBox(height: 24),
                const SizedBox(height: 24),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: PillarVisualizer(
                      key: _visualizerKey,
                      bandCount: bandCount,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: WaveformSeeker(
                    peaks: _waveformPeaks,
                    progress: trackState.duration > Duration.zero
                        ? trackState.position.inMilliseconds /
                              trackState.duration.inMilliseconds
                        : 0.0,
                    currentPositionMs: trackState.position.inMilliseconds,
                    durationMs: trackState.duration.inMilliseconds,
                    isPlaying: trackState.isPlaying,
                  ),
                ),
                const SizedBox(height: 24),
                const PlaybackControls(),
                const SizedBox(height: 48),
              ],
            ),
    );
  }
}
