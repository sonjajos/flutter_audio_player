class AudioTrack {
  final int? id;
  final String title;
  final String artist;
  final String filePath;
  final Duration duration;

  const AudioTrack({
    this.id,
    required this.title,
    required this.artist,
    required this.filePath,
    required this.duration,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioTrack && filePath == other.filePath;

  @override
  int get hashCode => filePath.hashCode;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'filePath': filePath,
      'duration': duration.inMilliseconds,
    };
  }

  factory AudioTrack.fromMap(Map<String, dynamic> map) {
    return AudioTrack(
      id: map['id'] as int?,
      title: map['title'] as String,
      artist: map['artist'] as String,
      filePath: map['filePath'] as String,
      duration: Duration(milliseconds: map['duration'] as int),
    );
  }
}
