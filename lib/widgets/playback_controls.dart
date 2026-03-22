import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

class PlaybackControls extends ConsumerWidget {
  const PlaybackControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackState = ref.watch(audioTrackNotifierProvider);
    final notifier = ref.read(audioTrackNotifierProvider.notifier);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous, size: 36),
          color: Colors.white,
          onPressed: () => notifier.previous(),
        ),
        const SizedBox(width: 16),
        IconButton(
          icon: Icon(
            trackState.isPlaying
                ? Icons.pause_circle_filled
                : Icons.play_circle_filled,
            size: 56,
          ),
          color: Colors.white,
          onPressed: () {
            if (trackState.isPlaying) {
              notifier.pause();
            } else {
              notifier.resume();
            }
          },
        ),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.skip_next, size: 36),
          color: Colors.white,
          onPressed: () => notifier.next(),
        ),
      ],
    );
  }
}
