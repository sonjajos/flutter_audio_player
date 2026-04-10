import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../widgets/playback_controls.dart';
import '../widgets/circular_visualizer.dart';
import '../widgets/waveform_seeker.dart';
import '../services/audio_player_service.dart';

// Top-level so compute() can send it to a background isolate.
List<double> _generatePeaksDart(Float32List pcm) {
  const barCount = 300;
  if (pcm.isEmpty) return [];
  final samplesPerBar = (pcm.length / barCount).ceil();
  final peaks = List<double>.filled(barCount, 0.0);
  for (var i = 0; i < barCount; i++) {
    final start = i * samplesPerBar;
    final end = (start + samplesPerBar).clamp(0, pcm.length);
    if (start >= pcm.length) break;
    double sum = 0.0;
    for (var j = start; j < end; j++) {
      final v = pcm[j];
      sum += v * v;
    }
    peaks[i] = (sum / (end - start) > 0) ? (sum / (end - start)) : 0.0;
  }
  final maxVal = peaks.reduce((a, b) => a > b ? a : b);
  if (maxVal > 0) {
    for (var i = 0; i < peaks.length; i++) {
      peaks[i] = peaks[i] / maxVal;
    }
  }
  return peaks;
}

class AudioPlayerScreen extends ConsumerStatefulWidget {
  const AudioPlayerScreen({super.key});

  @override
  ConsumerState<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends ConsumerState<AudioPlayerScreen> {
  final _visualizerKey = GlobalKey<PillarVisualizerState>();
  StreamSubscription<FFTEvent>? _fftSub;

  List<double>? _waveformPeaks;
  String? _waveformTrackPath;

  @override
  void initState() {
    super.initState();
    final service = ref.read(audioPlayerServiceProvider);
    // Sync engine band count with provider default on screen open
    final bandCount = ref.read(bandCountProvider);
    service.setBandCount(bandCount);
    _fftSub = service.fftStream.listen((event) {
      _visualizerKey.currentState?.updateBands(event.bands);
    });
    // Load waveform for any track that's already playing when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final track = ref.read(audioTrackNotifierProvider).currentTrack;
      if (track != null) _loadWaveform(track.filePath);
    });
  }

  @override
  void dispose() {
    _fftSub?.cancel();
    super.dispose();
  }

  Future<void> _loadWaveform(String filePath) async {
    if (_waveformTrackPath == filePath) return;
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
      final peaks = await compute(_generatePeaksDart, pcm);
      debugPrint(
        '[WaveformDebug] FFI generatePeaks returned ${peaks.length} peaks',
      );
      if (!mounted) return;
      setState(() => _waveformPeaks = peaks);
    } catch (e, st) {
      debugPrint('[WaveformDebug] ERROR: $e\n$st');
    }
  }

  void _cycleBandCount() {
    // bandCount = number of FFT bands from the engine.
    // Visualizer draws bandCount * 2 pillars total (mirrored left + right).
    const counts = [16, 32, 64, 128];
    final current = ref.read(bandCountProvider);
    final index = counts.indexOf(current);
    final next = counts[(index + 1) % counts.length];
    ref.read(bandCountProvider.notifier).set(next);
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
          : LayoutBuilder(
              builder: (context, constraints) {
                final h = constraints.maxHeight;
                final isSmall = h < 700;
                final topPad = isSmall ? 16.0 : 32.0;
                final midGap = isSmall ? 12.0 : 24.0;
                final bottomPad = isSmall ? 16.0 : 32.0;

                return Column(
                  children: [
                    SizedBox(height: topPad),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        currentTrack.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmall ? 20 : 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      currentTrack.artist,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: isSmall ? 14 : 16,
                      ),
                    ),
                    SizedBox(height: midGap),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: PillarVisualizer(
                          key: _visualizerKey,
                          bandCount: bandCount,
                        ),
                      ),
                    ),
                    SizedBox(height: midGap),
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
                    SizedBox(height: midGap),
                    const PlaybackControls(),
                    SizedBox(height: bottomPad),
                  ],
                );
              },
            ),
    );
  }
}
