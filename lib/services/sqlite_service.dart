import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/audio_track.dart';

class SQLiteService {
  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'audio_player.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tracks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            filePath TEXT NOT NULL UNIQUE,
            duration INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<int> insertTrack(AudioTrack track) async {
    final db = await database;
    return db.insert('tracks', track.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<AudioTrack>> getAllTracks() async {
    final db = await database;
    final maps = await db.query('tracks');
    return maps.map((map) => AudioTrack.fromMap(map)).toList();
  }

  Future<void> deleteTrack(int id) async {
    final db = await database;
    await db.delete('tracks', where: 'id = ?', whereArgs: [id]);
  }
}
