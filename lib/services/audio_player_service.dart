import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../models/audio_track.dart';

/// Playback state event received from the native audio engine.
class PlayerStateEvent {
  final String state; // idle, playing, paused, stopped
  final Duration position;
  final Duration duration;

  const PlayerStateEvent({
    required this.state,
    required this.position,
    required this.duration,
  });

  bool get isPlaying => state == 'playing';
}

/// FFT data event from native vDSP processing.
class FFTEvent {
  final List<double> bands;
  final int nativeFftTimeUs;
  final int timestampUs;

  const FFTEvent({
    required this.bands,
    required this.nativeFftTimeUs,
    required this.timestampUs,
  });
}

class AudioPlayerService {
  static const _control = MethodChannel('audio_player/control');
  static const _stateChannel = EventChannel('audio_player/state');
  static const _fftChannel = EventChannel('audio_player/fft');
  static const _commandChannel = EventChannel('audio_player/commands');

  // Persistent broadcast controllers — the native EventChannel subscription
  // stays alive for the lifetime of the service, regardless of how many
  // Dart listeners subscribe/unsubscribe.
  final _stateController = StreamController<PlayerStateEvent>.broadcast();
  final _fftController = StreamController<FFTEvent>.broadcast();
  final _commandController = StreamController<String>.broadcast();

  Stream<PlayerStateEvent> get stateStream => _stateController.stream;
  Stream<FFTEvent> get fftStream => _fftController.stream;
  Stream<String> get commandStream => _commandController.stream;

  AudioPlayerService() {
    _stateChannel.receiveBroadcastStream().listen((event) {
      final map = Map<String, dynamic>.from(event as Map);
      _stateController.add(PlayerStateEvent(
        state: map['state'] as String,
        position: Duration(milliseconds: map['positionMs'] as int),
        duration: Duration(milliseconds: map['durationMs'] as int),
      ));
    });

    _fftChannel.receiveBroadcastStream().listen((event) {
      final map = Map<String, dynamic>.from(event as Map);
      final Float32List rawBands = (map['bands'] as Float32List);
      _fftController.add(FFTEvent(
        bands: rawBands.map((v) => v.toDouble()).toList(),
        nativeFftTimeUs: map['nativeFftTimeUs'] as int,
        timestampUs: map['timestamp'] as int,
      ));
    });

    _commandChannel.receiveBroadcastStream().listen((event) {
      _commandController.add(event as String);
    });
  }

  Future<void> play(AudioTrack track) async {
    await _control.invokeMethod('play', {
      'filePath': track.filePath,
      'title': track.title,
      'artist': track.artist,
    });
  }

  Future<void> pause() async {
    await _control.invokeMethod('pause');
  }

  Future<void> resume() async {
    await _control.invokeMethod('resume');
  }

  Future<void> stop() async {
    await _control.invokeMethod('stop');
  }

  Future<void> seek(Duration position) async {
    await _control.invokeMethod('seek', {
      'positionMs': position.inMilliseconds,
    });
  }

  /// Set number of FFT bands: 16, 32, 64, or 128.
  Future<void> setBandCount(int count) async {
    await _control.invokeMethod('setBandCount', {'count': count});
  }

  /// Extract metadata (title, artist, duration) from an audio file via native AVAsset.
  Future<Map<String, dynamic>> getMetadata(String filePath) async {
    final result = await _control.invokeMethod<Map>('getMetadata', {
      'filePath': filePath,
    });
    return Map<String, dynamic>.from(result!);
  }

  /// Copy a file to the app's Documents/audio_files directory.
  /// Returns the new persistent file path.
  Future<String> copyToDocuments(String filePath) async {
    final result = await _control.invokeMethod<String>('copyToDocuments', {
      'filePath': filePath,
    });
    return result!;
  }

  /// List all audio files in Documents/audio_files/.
  Future<List<String>> listAudioFiles() async {
    final result = await _control.invokeMethod<List>('listAudioFiles');
    return result?.cast<String>() ?? [];
  }

  /// Delete a file from the app's Documents directory.
  Future<void> deleteFile(String filePath) async {
    await _control.invokeMethod('deleteFile', {
      'filePath': filePath,
    });
  }

  void dispose() {
    _stateController.close();
    _fftController.close();
    _commandController.close();
  }
}
