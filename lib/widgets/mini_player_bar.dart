import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../services/audio_player_service.dart';
import 'circular_visualizer.dart';

class MiniPlayerBar extends ConsumerStatefulWidget {
  const MiniPlayerBar({super.key});

  @override
  ConsumerState<MiniPlayerBar> createState() => _MiniPlayerBarState();
}

class _MiniPlayerBarState extends ConsumerState<MiniPlayerBar> {
  final _miniVisualizerKey = GlobalKey<PillarVisualizerState>();
  StreamSubscription<FFTEvent>? _fftSub;

  @override
  void initState() {
    super.initState();
    final service = ref.read(audioPlayerServiceProvider);
    _fftSub = service.fftStream.listen((event) {
      _miniVisualizerKey.currentState?.updateBands(event.bands);
    });
  }

  @override
  void dispose() {
    _fftSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trackState = ref.watch(audioTrackNotifierProvider);
    final currentTrack = trackState.currentTrack;

    // Don't show if no track has been loaded
    if (currentTrack == null) return const SizedBox.shrink();

    final notifier = ref.read(audioTrackNotifierProvider.notifier);

    return GestureDetector(
      onTap: () => context.push('/player'),
      child: Container(
        height: 80,
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          border: Border(bottom: BorderSide(color: Colors.white12, width: 0.5)),
        ),
        child: Row(
          children: [
            // Mini visualizer
            SizedBox(
              width: 80,
              height: 80,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: PillarVisualizer(
                  key: _miniVisualizerKey,
                  bandCount: 16,
                  maxHeightFraction: 0.55,
                ),
              ),
            ),
            // Track name
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentTrack.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentTrack.artist,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            // Controls
            IconButton(
              icon: const Icon(Icons.skip_previous, size: 24),
              color: Colors.white70,
              onPressed: () => notifier.previous(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36),
            ),
            IconButton(
              icon: Icon(
                trackState.isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                size: 36,
              ),
              color: Colors.white,
              onPressed: () {
                if (trackState.isPlaying) {
                  notifier.pause();
                } else {
                  notifier.resume();
                }
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 44),
            ),
            IconButton(
              icon: const Icon(Icons.skip_next, size: 24),
              color: Colors.white70,
              onPressed: () => notifier.next(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
