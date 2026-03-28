import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_player_service.dart';
import 'service_providers.dart';
import 'audio_track_notifier.dart';
import 'audio_metadata_notifier.dart';

export 'service_providers.dart';

// Band count: 16, 32, 64, or 128
class BandCountNotifier extends Notifier<int> {
  @override
  int build() => 32;

  void set(int count) => state = count;
}

final bandCountProvider = NotifierProvider<BandCountNotifier, int>(
  BandCountNotifier.new,
);

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
    NotifierProvider<AudioTrackNotifier, AudioTrackState>(
      AudioTrackNotifier.new,
    );

final audioMetadataNotifierProvider =
    NotifierProvider<AudioMetadataNotifier, AudioMetadataState>(
      AudioMetadataNotifier.new,
    );
