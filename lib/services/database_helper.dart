import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../models/game.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  
  static int insertDelay = 30;
  static bool turboMode = false;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite no está soportado en Web.');
    }
    if (_database != null) return _database!;
    _database = await _initDB('voxgamer_v6.db'); 
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 9, 
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE games (
      slug TEXT,
      titulo TEXT NOT NULL,
      tipo TEXT DEFAULT 'game', 
      descripcion_corta TEXT,
      fecha_lanzamiento TEXT,
      storage TEXT,
      generos TEXT,
      plataformas TEXT,
      img_principal TEXT,
      galeria TEXT,
      idiomas TEXT,
      idiomas_voces TEXT, 
      idiomas_textos TEXT, 
      metacritic INTEGER,
      tiendas TEXT,
      videos TEXT,
      desarrolladores TEXT,
      editores TEXT,
      cleanTitle TEXT,
      releaseDateTs INTEGER,
      PRIMARY KEY (slug, releaseDateTs)
    )
    ''');
    
    await db.execute('''
    CREATE TABLE IF NOT EXISTS upcoming_games (
      slug TEXT PRIMARY KEY,
      titulo TEXT NOT NULL,
      fecha_lanzamiento TEXT,
      img_principal TEXT,
      tiendas TEXT,
      releaseDateTs INTEGER
    )
    ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS meta_filters (
      type TEXT NOT NULL,
      value TEXT NOT NULL,
      display_order INTEGER DEFAULT 0,
      PRIMARY KEY (type, value)
    )
    ''');

    await db.execute('CREATE TABLE IF NOT EXISTS platforms_list (name TEXT PRIMARY KEY)');

    await _createIndices(db);
  }

  Future<void> _createIndices(DatabaseExecutor db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cleanTitle ON games(cleanTitle)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_releaseDateTs ON games(releaseDateTs)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tipo ON games(tipo)'); 
    await db.execute('CREATE INDEX IF NOT EXISTS idx_metacritic ON games(metacritic)');
    
    await db.execute('CREATE INDEX IF NOT EXISTS idx_upcoming_date ON upcoming_games(releaseDateTs)'); 
  }

  Future<void> _dropIndices(DatabaseExecutor db) async {
    await db.execute('DROP INDEX IF EXISTS idx_cleanTitle');
    await db.execute('DROP INDEX IF EXISTS idx_releaseDateTs');
    await db.execute('DROP INDEX IF EXISTS idx_tipo'); 
    await db.execute('DROP INDEX IF EXISTS idx_metacritic'); 
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 5) {
      await db.execute('DROP TABLE IF EXISTS games');
      await db.execute('DROP TABLE IF EXISTS meta_filters');
      await _createDB(db, newVersion);
      return;
    }
    
    if (oldVersion < 6) {
      await db.execute('CREATE TABLE IF NOT EXISTS platforms_list (name TEXT PRIMARY KEY)');
    }
    if (oldVersion < 7) {
       await db.execute('''
        CREATE TABLE IF NOT EXISTS upcoming_games (
          slug TEXT PRIMARY KEY,
          titulo TEXT NOT NULL,
          fecha_lanzamiento TEXT,
          img_principal TEXT,
          tiendas TEXT,
          releaseDateTs INTEGER
        )
       ''');
    }

    if (oldVersion < 8) {
      debugPrint("Upgrading DB to v8: Applying Composite Primary Key...");
      await db.execute('DROP TABLE IF EXISTS games');
      // En v8 se creó con un esquema sin los nuevos campos
      await db.execute('''
        CREATE TABLE games (
          slug TEXT,
          titulo TEXT NOT NULL,
          tipo TEXT DEFAULT 'game', 
          descripcion_corta TEXT,
          fecha_lanzamiento TEXT,
          storage TEXT,
          generos TEXT,
          plataformas TEXT,
          img_principal TEXT,
          galeria TEXT,
          idiomas TEXT,
          idiomas_voces TEXT, 
          idiomas_textos TEXT, 
          metacritic INTEGER,
          tiendas TEXT,
          cleanTitle TEXT,
          releaseDateTs INTEGER,
          PRIMARY KEY (slug, releaseDateTs)
        )
      ''');
      await _createIndices(db);
    }

    if (oldVersion < 9) {
      debugPrint("Upgrading DB to v9: Adding videos, developers and publishers...");
      // Recreamos la tabla games para incluir los nuevos campos de forma limpia
      await db.execute('DROP TABLE IF EXISTS games');
      
      await db.execute('''
        CREATE TABLE games (
          slug TEXT,
          titulo TEXT NOT NULL,
          tipo TEXT DEFAULT 'game', 
          descripcion_corta TEXT,
          fecha_lanzamiento TEXT,
          storage TEXT,
          generos TEXT,
          plataformas TEXT,
          img_principal TEXT,
          galeria TEXT,
          idiomas TEXT,
          idiomas_voces TEXT, 
          idiomas_textos TEXT, 
          metacritic INTEGER,
          tiendas TEXT,
          videos TEXT,
          desarrolladores TEXT,
          editores TEXT,
          cleanTitle TEXT,
          releaseDateTs INTEGER,
          PRIMARY KEY (slug, releaseDateTs)
        )
      ''');
      await _createIndices(db);
    }
  }

  Future<void> clearAllData() async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete('games');
    await db.delete('upcoming_games');
    await db.delete('meta_filters');
    await db.delete('platforms_list'); 
    debugPrint('Base de datos limpiada.');
  }

  Future<void> savePlatformsDedicated(List<String> platforms) async {
    if (kIsWeb) return;
    final db = await database;
    
    await db.transaction((txn) async {
      await txn.delete('platforms_list');
      final batch = txn.batch();
      for (var p in platforms) {
        if (p.trim().isNotEmpty) {
           batch.insert('platforms_list', {'name': p.trim()}, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<String>> getPlatformsDedicated() async {
    if (kIsWeb) return [];
    final db = await database;
    final result = await db.query('platforms_list', orderBy: 'name ASC');
    if (result.isEmpty) return [];
    return result.map((row) => row['name'] as String).toList();
  }

  Future<void> saveMetaFilters(List<String> genres, List<String> voices, List<String> texts, List<String> years, List<String> platforms) async {
    if (kIsWeb) return;
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('meta_filters');
      final batch = txn.batch();
      int i = 0;
      for (var g in genres) batch.insert('meta_filters', {'type': 'genre', 'value': g, 'display_order': i++}, conflictAlgorithm: ConflictAlgorithm.replace);
      i = 0;
      for (var v in voices) batch.insert('meta_filters', {'type': 'voice', 'value': v, 'display_order': i++}, conflictAlgorithm: ConflictAlgorithm.replace);
      i = 0;
      for (var t in texts) batch.insert('meta_filters', {'type': 'text', 'value': t, 'display_order': i++}, conflictAlgorithm: ConflictAlgorithm.replace);
      i = 0;
      for (var y in years) batch.insert('meta_filters', {'type': 'year', 'value': y, 'display_order': i++}, conflictAlgorithm: ConflictAlgorithm.replace);
      i = 0;
      for (var p in platforms) batch.insert('meta_filters', {'type': 'platform', 'value': p, 'display_order': i++}, conflictAlgorithm: ConflictAlgorithm.replace);
      await batch.commit(noResult: true);
    });
    await savePlatformsDedicated(platforms);
  }

  Future<Map<String, List<String>>> getMetaFilters() async {
    if (kIsWeb) return {};
    final db = await database;
    var result = await db.query('meta_filters', orderBy: 'display_order ASC'); 
    List<String> platforms = await getPlatformsDedicated();
    if (platforms.isEmpty) {
        for (var row in result) {
           if (row['type'] == 'platform') {
              platforms.add(row['value'] as String);
           }
        }
    }
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM games')) ?? 0;
    if (platforms.isEmpty && count > 0) {
          await _regenerateFiltersInternal(db);
          platforms = await getPlatformsDedicated();
          result = await db.query('meta_filters', orderBy: 'display_order ASC');
    }
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
    return {'genres': genres, 'voices': voices, 'texts': texts, 'years': years, 'platforms': platforms};
  }

  Future<void> _regenerateFiltersInternal(Database db) async {
    try {
      final Set<String> genresSet = {};
      final Set<String> voicesSet = {};
      final Set<String> textsSet = {};
      final Set<String> yearsSet = {};
      final Set<String> allPlatformsSet = {};
      const int batchSize = 2000;
      int offset = 0;
      bool hasMore = true;
      while (hasMore) {
          final List<Map<String, dynamic>> cursor = await db.query('games', columns: ['generos', 'plataformas', 'idiomas_voces', 'idiomas_textos', 'fecha_lanzamiento'], limit: batchSize, offset: offset);
          if (cursor.isEmpty) { hasMore = false; break; }
          for (var row in cursor) {
             try {
                 final gList = jsonDecode(row['generos'] as String);
                 for (var g in gList) genresSet.add(g.toString().trim());
                 final pList = jsonDecode(row['plataformas'] as String);
                 for (var p in pList) { final pStr = p.toString().trim(); if (pStr.isNotEmpty) allPlatformsSet.add(pStr); }
                 final vList = jsonDecode(row['idiomas_voces'] as String);
                 for (var v in vList) voicesSet.add(v.toString().trim());
                 final tList = jsonDecode(row['idiomas_textos'] as String);
                 for (var t in tList) textsSet.add(t.toString().trim());
                 final date = row['fecha_lanzamiento'] as String?;
                 if (date != null && date.length >= 4) { final y = date.substring(0, 4); if (int.tryParse(y) != null) yearsSet.add(y); }
             } catch (_) {}
          }
          offset += batchSize;
          await Future.delayed(const Duration(milliseconds: 5)); 
      }
      final genres = genresSet.toList()..sort();
      final voices = voicesSet.toList()..sort();
      final texts = textsSet.toList()..sort();
      final years = yearsSet.toList()..sort((a, b) => b.compareTo(a));
      final platforms = allPlatformsSet.toList()..sort();
      await db.transaction((txn) async {
        await txn.delete('meta_filters');
        final batch = txn.batch();
        int i = 0;
        for (var g in genres) batch.insert('meta_filters', {'type': 'genre', 'value': g, 'display_order': i++}, conflictAlgorithm: ConflictAlgorithm.replace);
        i = 0;
        for (var v in voices) batch.insert('meta_filters', {'type': 'voice', 'value': v, 'display_order': i++}, conflictAlgorithm: ConflictAlgorithm.replace);
        i = 0;
        for (var t in texts) batch.insert('meta_filters', {'type': 'text', 'value': t, 'display_order': i++}, conflictAlgorithm: ConflictAlgorithm.replace);
        i = 0;
        for (var y in years) batch.insert('meta_filters', {'type': 'year', 'value': y, 'display_order': i++}, conflictAlgorithm: ConflictAlgorithm.replace);
        await batch.commit(noResult: true);
      });
      await db.transaction((txn) async {
         await txn.delete('platforms_list');
         final batch = txn.batch();
         for (var p in platforms) { batch.insert('platforms_list', {'name': p}, conflictAlgorithm: ConflictAlgorithm.replace); }
         await batch.commit(noResult: true);
      });
    } catch (e) { debugPrint("Error regenerando filtros: $e"); }
  }

  Future<List<String>> getTopPlatformsRecent(int limit) async {
    if (kIsWeb) return [];
    final db = await database;
    final oneYearAgo = DateTime.now().subtract(const Duration(days: 365)).millisecondsSinceEpoch;
    try {
      final Map<String, int> counts = {};
      const int batchSize = 2000;
      int offset = 0;
      bool hasMore = true;
      while (hasMore) {
        final List<Map<String, dynamic>> result = await db.query('games', columns: ['plataformas'], where: 'releaseDateTs >= ?', whereArgs: [oneYearAgo], limit: batchSize, offset: offset);
        if (result.isEmpty) { hasMore = false; break; }
        for (var row in result) {
          try {
            final List<dynamic> list = jsonDecode(row['plataformas'] as String);
            for (var p in list) { final pStr = p.toString(); counts[pStr] = (counts[pStr] ?? 0) + 1; }
          } catch (_) {}
        }
        offset += batchSize;
        await Future.delayed(const Duration(milliseconds: 2));
      }
      if (counts.isEmpty) {
        final List<Map<String, dynamic>> fallbackResult = await db.query('games', columns: ['plataformas'], limit: 5000);
        for (var row in fallbackResult) {
          try {
             final List<dynamic> list = jsonDecode(row['plataformas'] as String);
             for (var p in list) { final pStr = p.toString(); counts[pStr] = (counts[pStr] ?? 0) + 1; }
          } catch (_) {}
        }
      }
      final sortedKeys = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
      return sortedKeys.take(limit).toList();
    } catch (e) { return []; }
  }

  Future<void> insertGames(List<Game> games, {Function(double progress)? onProgress}) async {
    if (kIsWeb) return;

    final db = await database;
    const int batchSize = 200; 
    int total = games.length;

    debugPrint('Iniciando inserción v4 con TurboMode dinámico...');
    await _dropIndices(db);

    await db.transaction((txn) async {
       await txn.delete('games');
    });

    for (var i = 0; i < total; i += batchSize) {
      final end = (i + batchSize < total) ? i + batchSize : total;
      final chunk = games.sublist(i, end);

      await db.transaction((txn) async {
        final batch = txn.batch();
        for (var game in chunk) {
          String tipoAGuardar = game.tipo.trim();
          if (tipoAGuardar.isEmpty) tipoAGuardar = 'game';

          batch.insert('games', {
            'slug': game.slug,
            'titulo': game.titulo,
            'tipo': tipoAGuardar, 
            'descripcion_corta': game.descripcionCorta,
            'fecha_lanzamiento': game.fechaLanzamiento,
            'storage': game.storage,
            'generos': jsonEncode(game.generos),
            'plataformas': jsonEncode(game.plataformas),
            'img_principal': game.imgPrincipal,
            'galeria': jsonEncode(game.galeria),
            'idiomas': jsonEncode({'voces': game.idiomas.voces, 'textos': game.idiomas.textos}),
            'idiomas_voces': jsonEncode(game.idiomas.voces),
            'idiomas_textos': jsonEncode(game.idiomas.textos),
            'metacritic': game.metacritic,
            'tiendas': jsonEncode(game.tiendas.map((t) => {'tienda': t.tienda, 'id_externo': t.idExterno, 'url': t.url, 'is_free': t.isFree}).toList()),
            'videos': jsonEncode(game.videos.map((v) => v.toJson()).toList()),
            'desarrolladores': jsonEncode(game.desarrolladores),
            'editores': jsonEncode(game.editores),
            'cleanTitle': game.cleanTitle,
            'releaseDateTs': game.releaseDateTs
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      });

      if (onProgress != null) onProgress(end / total);
      if (turboMode) await Future.delayed(Duration(milliseconds: insertDelay));
      else await Future.delayed(const Duration(milliseconds: 30));
    }

    await _createIndices(db);
    debugPrint('Inserción masiva finalizada.');
  }

  Future<List<Game>> getGames({int limit = 20, int offset = 0, String? query, String? voiceLanguage, String? textLanguage, String? year, String? genre, String? platform, String? tipo, String sortBy = 'date'}) async {
    if (kIsWeb) return [];
    final db = await database;
    String? whereClause;
    List<dynamic> whereArgs = [];

    if (query != null && query.isNotEmpty) {
      String cleanQuery = Game.normalize(query);
      whereClause = 'cleanTitle LIKE ?';
      whereArgs.add('%$cleanQuery%');
    }
    void addCondition(String clause, dynamic arg) { if (whereClause != null) whereClause = '$whereClause AND $clause'; else whereClause = clause; whereArgs.add(arg); }

    if (tipo != null) addCondition('tipo = ?', tipo);
    if (voiceLanguage != null && voiceLanguage != 'Cualquiera') addCondition('idiomas_voces LIKE ?', '%${jsonEncode(voiceLanguage)}%');
    if (textLanguage != null && textLanguage != 'Cualquiera') addCondition('idiomas_textos LIKE ?', '%${jsonEncode(textLanguage)}%');
    if (year != null && year != 'Cualquiera') addCondition('fecha_lanzamiento LIKE ?', '$year%');
    if (genre != null && genre != 'Cualquiera') addCondition('generos LIKE ?', '%"$genre"%'); 
    if (platform != null && platform != 'Cualquiera') addCondition('plataformas LIKE ?', '%"$platform"%');

    String orderByClause = 'releaseDateTs DESC';
    if (sortBy == 'score') orderByClause = 'metacritic DESC, releaseDateTs DESC'; 

    try {
      final List<Map<String, dynamic>> maps = await db.query('games', where: whereClause, whereArgs: whereArgs.isNotEmpty ? whereArgs : null, limit: limit, offset: offset, orderBy: orderByClause);
      return maps.map((dbMap) {
          Map<String, dynamic> jsonMap = Map.of(dbMap);
          try {
            jsonMap['generos'] = jsonDecode(dbMap['generos'] ?? '[]');
            jsonMap['plataformas'] = jsonDecode(dbMap['plataformas'] ?? '[]');
            jsonMap['galeria'] = jsonDecode(dbMap['galeria'] ?? '[]');
            jsonMap['idiomas'] = jsonDecode(dbMap['idiomas'] ?? '{}');
            jsonMap['tiendas'] = jsonDecode(dbMap['tiendas'] ?? '[]');
            jsonMap['videos'] = jsonDecode(dbMap['videos'] ?? '[]');
            jsonMap['desarrolladores'] = jsonDecode(dbMap['desarrolladores'] ?? '[]');
            jsonMap['editores'] = jsonDecode(dbMap['editores'] ?? '[]');
          } catch (e) {}
          return Game.fromJson(jsonMap);
      }).toList();
    } catch (e) { return []; }
  }

  // --- ACTUALIZADO: Acepta un 'year' opcional para filtrar duplicados ---
  Future<Game?> getGameBySlug(String slug, {String? year}) async {
    if (kIsWeb) return null;
    final db = await database;
    try {
      String whereClause = 'slug = ?';
      List<dynamic> args = [slug];

      // Si nos pasan un año, filtramos también por fecha de lanzamiento
      if (year != null && year.isNotEmpty) {
        whereClause += ' AND fecha_lanzamiento LIKE ?';
        args.add('$year%'); // Busca "1998-01-21" usando "1998%"
      }

      final List<Map<String, dynamic>> maps = await db.query(
        'games',
        where: whereClause,
        whereArgs: args,
        orderBy: 'releaseDateTs DESC', 
        limit: 1,
      );
      
      if (maps.isNotEmpty) {
          Map<String, dynamic> jsonMap = Map.of(maps.first);
          try {
            jsonMap['generos'] = jsonDecode(maps.first['generos'] ?? '[]');
            jsonMap['plataformas'] = jsonDecode(maps.first['plataformas'] ?? '[]');
            jsonMap['galeria'] = jsonDecode(maps.first['galeria'] ?? '[]');
            jsonMap['idiomas'] = jsonDecode(maps.first['idiomas'] ?? '{}');
            jsonMap['tiendas'] = jsonDecode(maps.first['tiendas'] ?? '[]');
            jsonMap['videos'] = jsonDecode(maps.first['videos'] ?? '[]');
            jsonMap['desarrolladores'] = jsonDecode(maps.first['desarrolladores'] ?? '[]');
            jsonMap['editores'] = jsonDecode(maps.first['editores'] ?? '[]');
          } catch (e) {}
          return Game.fromJson(jsonMap);
      }
      return null;
    } catch (e) {
      debugPrint('Error buscando juego por slug: $e');
      return null;
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
