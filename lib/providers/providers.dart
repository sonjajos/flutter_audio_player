import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sqlite_service.dart';
import '../services/audio_player_service.dart';
import 'audio_track_notifier.dart';
import 'audio_metadata_notifier.dart';

// Services
final sqliteServiceProvider = Provider<SQLiteService>((ref) {
  return SQLiteService();
});

final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final service = AudioPlayerService();
  ref.onDispose(() => service.dispose());
  return service;
});

// Band count: 16, 32, 64, or 128
final bandCountProvider = StateProvider<int>((ref) => 32);

// Playback state stream from native engine
final playerStateStreamProvider = StreamProvider<PlayerStateEvent>((ref) {
  final service = ref.watch(audioPlayerServiceProvider);
  return service.stateStream;
});

// Native FFT stream
final fftStreamProvider = StreamProvider<FFTEvent>((ref) {
  final service = ref.watch(audioPlayerServiceProvider);
  return service.fftStream;
});

// Remote command stream (lock screen controls, track completion)
final commandStreamProvider = StreamProvider<String>((ref) {
  final service = ref.watch(audioPlayerServiceProvider);
  return service.commandStream;
});

// State notifiers
final audioTrackNotifierProvider =
    StateNotifierProvider<AudioTrackNotifier, AudioTrackState>((ref) {
      final playerService = ref.watch(audioPlayerServiceProvider);
      return AudioTrackNotifier(playerService);
    });

final audioMetadataNotifierProvider =
    StateNotifierProvider<AudioMetadataNotifier, AudioMetadataState>((ref) {
      final playerService = ref.watch(audioPlayerServiceProvider);
      final sqliteService = ref.watch(sqliteServiceProvider);
      return AudioMetadataNotifier(playerService, sqliteService);
    });
