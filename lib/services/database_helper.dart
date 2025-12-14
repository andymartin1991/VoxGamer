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
      throw UnsupportedError('SQLite no está soportado en Web.');
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
      version: 3, // Versión 3
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
      voices TEXT,
      cleanTitle TEXT,
      releaseDateTs INTEGER
    )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      // Reconstrucción simple: Borramos y creamos de nuevo
      // Al cambiar estructura, forzaremos una resincronización limpia
      await db.execute('DROP TABLE IF EXISTS games');
      await _createDB(db, newVersion);
    }
  }
  
  Future<void> clearAllData() async {
    if (kIsWeb) return;
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
          'cleanTitle': game.cleanTitle,
          'releaseDateTs': game.releaseDateTs
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<SteamGame>> getGames({
    int limit = 20, 
    int offset = 0, 
    String? query,
    String? voiceLanguage // Nuevo filtro
  }) async {
    if (kIsWeb) return [];

    final db = await database;
    
    // Construcción de la Query
    String? whereClause;
    List<dynamic> whereArgs = [];

    // Filtro de Búsqueda (sobre cleanTitle)
    if (query != null && query.isNotEmpty) {
      // Normalizamos la query también
      String cleanQuery = SteamGame(
        id: 0, title: query, languages: [], voices: []
      ).cleanTitle;
      
      whereClause = 'cleanTitle LIKE ?';
      whereArgs.add('%$cleanQuery%');
    }

    // Filtro de Voces
    if (voiceLanguage != null && voiceLanguage != 'Cualquiera') {
      if (whereClause != null) {
        whereClause += ' AND voices LIKE ?';
      } else {
        whereClause = 'voices LIKE ?';
      }
      whereArgs.add('%$voiceLanguage%');
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'games',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      limit: limit,
      offset: offset,
      orderBy: 'releaseDateTs DESC', // Ordenar por fecha descendente
    );

    return maps.map((json) {
      return SteamGame(
        id: json['id'],
        title: json['title'],
        releaseDate: json['releaseDate'],
        size: json['size'],
        steamUrl: json['steamUrl'],
        headerImage: json['headerImage'],
        cleanTitle: json['cleanTitle'], // Recuperamos
        releaseDateTs: json['releaseDateTs'], // Recuperamos
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
