import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/audio_track.dart';
import '../services/audio_player_service.dart';
import '../services/sqlite_service.dart';
import 'service_providers.dart';

class AudioMetadataState {
  final List<AudioTrack> tracks;
  final bool isLoading;

  const AudioMetadataState({this.tracks = const [], this.isLoading = false});

  AudioMetadataState copyWith({List<AudioTrack>? tracks, bool? isLoading}) {
    return AudioMetadataState(
      tracks: tracks ?? this.tracks,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AudioMetadataNotifier extends Notifier<AudioMetadataState> {
  late AudioPlayerService _playerService;
  late SQLiteService _sqliteService;

  @override
  AudioMetadataState build() {
    _playerService = ref.watch(audioPlayerServiceProvider);
    _sqliteService = ref.watch(sqliteServiceProvider);
    // Trigger initial load after the first frame so state is fully initialized
    Future.microtask(loadTracks);
    return const AudioMetadataState(isLoading: true);
  }

  Future<void> loadTracks() async {
    state = state.copyWith(isLoading: true);
    await _scanLocalFiles();
    final tracks = await _sqliteService.getAllTracks();
    state = state.copyWith(tracks: tracks, isLoading: false);
  }

  /// Syncs the database with the actual files on disk.
  /// Removes stale entries (files that no longer exist) and imports
  /// new files pushed via simctl or copied into the container.
  Future<void> _scanLocalFiles() async {
    final filePaths = await _playerService.listAudioFiles();
    final existingTracks = await _sqliteService.getAllTracks();

    // Remove DB entries whose files no longer exist on disk
    for (final track in existingTracks) {
      if (!filePaths.contains(track.filePath)) {
        if (track.id != null) {
          await _sqliteService.deleteTrack(track.id!);
        }
      }
    }

    if (filePaths.isEmpty) return;

    // Re-read after cleanup to get current filenames
    final remainingTracks = await _sqliteService.getAllTracks();
    final existingFileNames =
        remainingTracks.map((t) => t.filePath.split('/').last).toSet();

    // Import new files (match by filename to avoid duplicates across containers)
    for (final path in filePaths) {
      final fileName = path.split('/').last;
      if (!existingFileNames.contains(fileName)) {
        final metadata = await _playerService.getMetadata(path);
        final track = AudioTrack(
          title: metadata['title'] as String,
          artist: metadata['artist'] as String,
          filePath: path,
          duration: Duration(milliseconds: metadata['durationMs'] as int),
        );
        await _sqliteService.insertTrack(track);
        existingFileNames.add(fileName);
      }
    }
  }

  Future<void> uploadTrack(String filePath) async {
    final persistentPath = await _playerService.copyToDocuments(filePath);
    final metadata = await _playerService.getMetadata(persistentPath);

    final track = AudioTrack(
      title: metadata['title'] as String,
      artist: metadata['artist'] as String,
      filePath: persistentPath,
      duration: Duration(milliseconds: metadata['durationMs'] as int),
    );

    await _sqliteService.insertTrack(track);
    await loadTracks();
  }

  Future<void> removeTrack(AudioTrack track) async {
    if (track.id == null) return;

    await _playerService.deleteFile(track.filePath);
    await _sqliteService.deleteTrack(track.id!);
    await loadTracks();
  }
}
