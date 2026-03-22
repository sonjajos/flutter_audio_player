import 'package:flutter/material.dart';
import '../models/audio_track.dart';

class AudioListTile extends StatelessWidget {
  final AudioTrack track;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const AudioListTile({
    super.key,
    required this.track,
    required this.onTap,
    this.onDelete,
  });

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(track.id ?? track.filePath),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red.shade900,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete track'),
            content: Text('Remove "${track.title}" from your library?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) => onDelete?.call(),
      child: ListTile(
        leading: const Icon(Icons.music_note, color: Colors.white70),
        title: Text(track.title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(
          track.artist,
          style: const TextStyle(color: Colors.white54),
        ),
        trailing: Text(
          _formatDuration(track.duration),
          style: const TextStyle(color: Colors.white54),
        ),
        onTap: onTap,
      ),
    );
  }
}
