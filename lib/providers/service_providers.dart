import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sqlite_service.dart';
import '../services/audio_player_service.dart';

final sqliteServiceProvider = Provider<SQLiteService>((ref) {
  final service = SQLiteService();
  ref.onDispose(() => service.dispose());
  return service;
});

final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final service = AudioPlayerService();
  ref.onDispose(() => service.dispose());
  return service;
});
