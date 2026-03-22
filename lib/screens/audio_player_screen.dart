import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../widgets/playback_controls.dart';
import '../widgets/pillar_visualizer.dart';
import '../services/audio_player_service.dart';

class AudioPlayerScreen extends ConsumerStatefulWidget {
  const AudioPlayerScreen({super.key});

  @override
  ConsumerState<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends ConsumerState<AudioPlayerScreen> {
  final _visualizerKey = GlobalKey<PillarVisualizerState>();
  StreamSubscription<FFTEvent>? _fftSub;
  StreamSubscription<PlayerStateEvent>? _stateSub;
  StreamSubscription<String>? _commandSub;

  @override
  void initState() {
    super.initState();

    final service = ref.read(audioPlayerServiceProvider);

    // Listen to native playback state
    _stateSub = service.stateStream.listen((event) {
      ref.read(audioTrackNotifierProvider.notifier).updateFromNativeState(event);
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

  @override
  void dispose() {
    _fftSub?.cancel();
    _stateSub?.cancel();
    _commandSub?.cancel();
    super.dispose();
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
              '${bandCount}b',
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
                const SizedBox(height: 48),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: PillarVisualizer(
                      key: _visualizerKey,
                      bandCount: bandCount,
                    ),
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
