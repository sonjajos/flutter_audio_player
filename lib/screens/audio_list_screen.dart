import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../widgets/audio_list_tile.dart';
import '../widgets/mini_player_bar.dart';

class AudioListScreen extends ConsumerStatefulWidget {
  const AudioListScreen({super.key});

  @override
  ConsumerState<AudioListScreen> createState() => _AudioListScreenState();
}

class _AudioListScreenState extends ConsumerState<AudioListScreen> {
  bool _isPicking = false;

  Future<void> _uploadAudio() async {
    if (_isPicking) return;
    _isPicking = true;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );

      if (result != null && mounted) {
        final notifier = ref.read(audioMetadataNotifierProvider.notifier);
        for (final file in result.files) {
          if (file.path != null) {
            await notifier.uploadTrack(file.path!);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick files: $e')),
        );
      }
    } finally {
      _isPicking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final metadataState = ref.watch(audioMetadataNotifierProvider);

    final hasActiveTrack =
        ref.watch(audioTrackNotifierProvider).currentTrack != null;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Audio Player'),
        backgroundColor: const Color(0xFF1E1E1E),
      ),
      body: Column(
        children: [
          if (hasActiveTrack) const MiniPlayerBar(),
          Expanded(
            child: metadataState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : metadataState.tracks.isEmpty
                ? const Center(
                    child: Text(
                      'No audio files yet.\nTap + to upload.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  )
                : ListView.separated(
                    itemCount: metadataState.tracks.length,
                    separatorBuilder: (_, _) =>
                        const Divider(color: Colors.white12, height: 1),
                    itemBuilder: (context, index) {
                      final track = metadataState.tracks[index];
                      return AudioListTile(
                        track: track,
                        onTap: () async {
                          await ref
                              .read(audioTrackNotifierProvider.notifier)
                              .playAt(index, queue: metadataState.tracks);
                          if (context.mounted) {
                            context.push('/player');
                          }
                        },
                        onDelete: () {
                          ref
                              .read(audioMetadataNotifierProvider.notifier)
                              .removeTrack(track);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadAudio,
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add),
      ),
    );
  }
}
