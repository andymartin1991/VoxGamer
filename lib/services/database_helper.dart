import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/steam_game.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite no está soportado en Web. Usa la caché en memoria.');
    }
    if (_database != null) return _database!;
    _database = await _initDB('voxgamer.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, 
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE games (
      id INTEGER PRIMARY KEY,
      title TEXT NOT NULL,
      releaseDate TEXT,
      size TEXT,
      steamUrl TEXT,
      headerImage TEXT,
      languages TEXT,
      voices TEXT
    )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE games ADD COLUMN voices TEXT');
      } catch (e) {
        // Ignorar si ya existe
      }
    }
  }
  
  Future<void> clearAllData() async {
    if (kIsWeb) return; // No hacemos nada en web aquí
    final db = await database;
    await db.delete('games');
  }

  Future<void> insertGames(List<SteamGame> games) async {
    if (kIsWeb) return;
    
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      batch.delete('games');
      
      for (var game in games) {
        batch.insert('games', {
          'id': game.id,
          'title': game.title,
          'releaseDate': game.releaseDate,
          'size': game.size,
          'steamUrl': game.steamUrl,
          'headerImage': game.headerImage,
          'languages': game.languages.join(','), 
          'voices': game.voices.join(','), 
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<SteamGame>> getGames({int limit = 20, int offset = 0, String? query}) async {
    if (kIsWeb) return [];

    final db = await database;
    
    List<Map<String, dynamic>> maps;

    if (query != null && query.isNotEmpty) {
      maps = await db.query(
        'games',
        where: 'title LIKE ?',
        whereArgs: ['%$query%'],
        limit: limit,
        offset: offset,
        orderBy: 'title ASC', 
      );
    } else {
      maps = await db.query(
        'games',
        limit: limit,
        offset: offset,
      );
    }

    return maps.map((json) {
      return SteamGame(
        id: json['id'],
        title: json['title'],
        releaseDate: json['releaseDate'],
        size: json['size'],
        steamUrl: json['steamUrl'],
        headerImage: json['headerImage'],
        languages: (json['languages'] as String?)?.isNotEmpty == true
            ? (json['languages'] as String).split(',') 
            : [],
        voices: (json['voices'] as String?)?.isNotEmpty == true
            ? (json['voices'] as String).split(',')
            : [],
      );
    }).toList();
  }

  Future<int> countGames() async {
    if (kIsWeb) return 0;
    final db = await database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM games')) ?? 0;
  }
}
