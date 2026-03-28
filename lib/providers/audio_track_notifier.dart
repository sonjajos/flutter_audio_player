import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/audio_track.dart';
import '../services/audio_player_service.dart';
import 'service_providers.dart';

class AudioTrackState {
  final AudioTrack? currentTrack;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final List<AudioTrack> queue;
  final int currentIndex;

  const AudioTrackState({
    this.currentTrack,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.queue = const [],
    this.currentIndex = -1,
  });

  AudioTrackState copyWith({
    AudioTrack? currentTrack,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    List<AudioTrack>? queue,
    int? currentIndex,
  }) {
    return AudioTrackState(
      currentTrack: currentTrack ?? this.currentTrack,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}

class AudioTrackNotifier extends Notifier<AudioTrackState> {
  late AudioPlayerService _playerService;
  StreamSubscription<PlayerStateEvent>? _stateSub;
  StreamSubscription<String>? _commandSub;

  @override
  AudioTrackState build() {
    _playerService = ref.watch(audioPlayerServiceProvider);

    // Subscribe to native playback state
    _stateSub = _playerService.stateStream.listen((event) {
      state = state.copyWith(
        isPlaying: event.isPlaying,
        position: event.position,
        duration: event.duration,
      );
    });

    // Subscribe to remote commands (lock screen + track completion)
    _commandSub = _playerService.commandStream.listen((command) {
      switch (command) {
        case 'play':
          resume();
        case 'pause':
          pause();
        case 'next':
          next();
        case 'previous':
          previous();
        case 'completed':
          next();
      }
    });

    ref.onDispose(() {
      _stateSub?.cancel();
      _commandSub?.cancel();
    });

    return const AudioTrackState();
  }

  /// Play a track at a specific index in the given (or current) queue.
  Future<void> playAt(int index, {List<AudioTrack>? queue}) async {
    final trackQueue = queue ?? state.queue;
    if (index < 0 || index >= trackQueue.length) return;
    final track = trackQueue[index];
    state = state.copyWith(
      currentTrack: track,
      isPlaying: true,
      queue: trackQueue,
      currentIndex: index,
      position: Duration.zero,
    );
    await _playerService.play(track);
  }

  Future<void> pause() async {
    state = state.copyWith(isPlaying: false);
    await _playerService.pause();
  }

  Future<void> resume() async {
    state = state.copyWith(isPlaying: true);
    await _playerService.resume();
  }

  Future<void> stop() async {
    state = state.copyWith(isPlaying: false, position: Duration.zero);
    await _playerService.stop();
  }

  Future<void> next() async {
    if (state.queue.isEmpty) return;
    final current = state.currentIndex < 0 ? 0 : state.currentIndex;
    final nextIndex = (current + 1) % state.queue.length;
    await playAt(nextIndex);
  }

  Future<void> previous() async {
    if (state.queue.isEmpty) return;
    final current = state.currentIndex < 0 ? 0 : state.currentIndex;
    final prevIndex = (current - 1 + state.queue.length) % state.queue.length;
    await playAt(prevIndex);
  }

  void updatePosition(Duration position) {
    state = state.copyWith(position: position);
  }
}
