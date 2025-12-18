import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
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
    _database = await _initDB('voxgamer_v3.db'); 
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE games (
      slug TEXT PRIMARY KEY,
      titulo TEXT NOT NULL,
      descripcion_corta TEXT,
      fecha_lanzamiento TEXT,
      storage TEXT,
      generos TEXT,
      img_principal TEXT,
      galeria TEXT,
      idiomas TEXT,
      metacritic INTEGER,
      tiendas TEXT,
      cleanTitle TEXT,
      releaseDateTs INTEGER
    )
    ''');
    
    await db.execute('''
    CREATE TABLE meta_filters (
      type TEXT NOT NULL,
      value TEXT NOT NULL,
      PRIMARY KEY (type, value)
    )
    ''');

    await db.execute('CREATE INDEX idx_cleanTitle ON games(cleanTitle)');
    await db.execute('CREATE INDEX idx_releaseDateTs ON games(releaseDateTs)');
  }

  Future<void> clearAllData() async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete('games');
    await db.delete('meta_filters');
    debugPrint('Base de datos limpiada.');
  }

  // UPDATED: Aceptamos lista de años
  Future<void> saveMetaFilters(List<String> genres, List<String> voices, List<String> texts, List<String> years) async {
    if (kIsWeb) return;
    final db = await database;
    
    await db.transaction((txn) async {
      await txn.delete('meta_filters');
      
      final batch = txn.batch();
      
      for (var g in genres) {
        batch.insert('meta_filters', {'type': 'genre', 'value': g});
      }
      for (var v in voices) {
        batch.insert('meta_filters', {'type': 'voice', 'value': v});
      }
      for (var t in texts) {
        batch.insert('meta_filters', {'type': 'text', 'value': t});
      }
      for (var y in years) {
        batch.insert('meta_filters', {'type': 'year', 'value': y}); // Nuevo tipo
      }
      
      await batch.commit(noResult: true);
    });
    debugPrint('Filtros dinámicos (incluyendo años) guardados en DB.');
  }

  Future<Map<String, List<String>>> getMetaFilters() async {
    if (kIsWeb) return {};
    final db = await database;
    
    final result = await db.query('meta_filters');
    
    final genres = <String>[];
    final voices = <String>[];
    final texts = <String>[];
    final years = <String>[];
    
    for (var row in result) {
      final val = row['value'] as String;
      switch (row['type']) {
        case 'genre': genres.add(val); break;
        case 'voice': voices.add(val); break;
        case 'text': texts.add(val); break;
        case 'year': years.add(val); break;
      }
    }
    
    genres.sort();
    voices.sort();
    texts.sort();
    // Los años los ordenamos descendente (más nuevo primero)
    years.sort((a, b) => b.compareTo(a)); 
    
    return {
      'genres': genres,
      'voices': voices,
      'texts': texts,
      'years': years,
    };
  }

  Future<void> insertGames(List<SteamGame> games) async {
    if (kIsWeb) return;

    final db = await database;
    const int batchSize = 500;
    int total = games.length;

    debugPrint('Iniciando inserción de $total juegos en lotes de $batchSize...');

    await db.transaction((txn) async {
      await txn.delete('games');

      for (var i = 0; i < total; i += batchSize) {
        final end = (i + batchSize < total) ? i + batchSize : total;
        final batch = txn.batch();
        final chunk = games.sublist(i, end);

        for (var game in chunk) {
          batch.insert('games', {
            'slug': game.slug,
            'titulo': game.titulo,
            'descripcion_corta': game.descripcionCorta,
            'fecha_lanzamiento': game.fechaLanzamiento,
            'storage': game.storage,
            'generos': jsonEncode(game.generos),
            'img_principal': game.imgPrincipal,
            'galeria': jsonEncode(game.galeria),
            'idiomas': jsonEncode({
              'voces': game.idiomas.voces,
              'textos': game.idiomas.textos,
            }),
            'metacritic': game.metacritic,
            'tiendas': jsonEncode(game.tiendas.map((t) => {
              'tienda': t.tienda,
              'id_externo': t.idExterno,
              'url': t.url,
              'is_free': t.isFree,
            }).toList()),
            'cleanTitle': game.cleanTitle,
            'releaseDateTs': game.releaseDateTs
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        
        await batch.commit(noResult: true);
      }
    });
    debugPrint('Inserción masiva finalizada.');
  }

  Future<List<SteamGame>> getGames({
    int limit = 20,
    int offset = 0,
    String? query,
    String? voiceLanguage,
    String? textLanguage,
    String? year,
    String? genre,
  }) async {
    if (kIsWeb) return [];

    final db = await database;
    String? whereClause;
    List<dynamic> whereArgs = [];

    if (query != null && query.isNotEmpty) {
      String cleanQuery = SteamGame.normalize(query);
      whereClause = 'cleanTitle LIKE ?';
      whereArgs.add('%$cleanQuery%');
    }

    void addCondition(String clause, dynamic arg) {
      if (whereClause != null) {
        whereClause = '$whereClause AND $clause';
      } else {
        whereClause = clause;
      }
      whereArgs.add(arg);
    }

    if (voiceLanguage != null && voiceLanguage != 'Cualquiera') {
      addCondition('idiomas LIKE ?', '%"voces":%${jsonEncode(voiceLanguage)}%');
    }

    if (textLanguage != null && textLanguage != 'Cualquiera') {
      addCondition('idiomas LIKE ?', '%"textos":%${jsonEncode(textLanguage)}%');
    }

    if (year != null && year != 'Cualquiera') {
      addCondition('fecha_lanzamiento LIKE ?', '$year%');
    }

    if (genre != null && genre != 'Cualquiera') {
      addCondition('generos LIKE ?', '%"$genre"%'); 
    }

    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'games',
        where: whereClause,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        limit: limit,
        offset: offset,
        orderBy: 'releaseDateTs DESC',
      );
      
      return maps.map((dbMap) {
          Map<String, dynamic> jsonMap = Map.of(dbMap);
          try {
            jsonMap['generos'] = jsonDecode(dbMap['generos'] ?? '[]');
            jsonMap['galeria'] = jsonDecode(dbMap['galeria'] ?? '[]');
            jsonMap['idiomas'] = jsonDecode(dbMap['idiomas'] ?? '{}');
            jsonMap['tiendas'] = jsonDecode(dbMap['tiendas'] ?? '[]');
          } catch (e) {
            // Error silencioso
          }
          return SteamGame.fromJson(jsonMap);
      }).toList();
    } catch (e) {
      debugPrint('Error ejecutando query en getGames: $e');
      return [];
    }
  }

  Future<int> countGames() async {
    if (kIsWeb) return 0;
    try {
      final db = await database;
      return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM games')) ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
