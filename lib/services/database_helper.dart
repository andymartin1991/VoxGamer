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
      version: 5, 
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE games (
      slug TEXT PRIMARY KEY,
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
      releaseDateTs INTEGER
    )
    ''');
    
    await db.execute('''
    CREATE TABLE meta_filters (
      type TEXT NOT NULL,
      value TEXT NOT NULL,
      display_order INTEGER DEFAULT 0,
      PRIMARY KEY (type, value)
    )
    ''');

    await _createIndices(db);
  }

  Future<void> _createIndices(DatabaseExecutor db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cleanTitle ON games(cleanTitle)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_releaseDateTs ON games(releaseDateTs)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tipo ON games(tipo)'); 
    await db.execute('CREATE INDEX IF NOT EXISTS idx_metacritic ON games(metacritic)'); 
  }

  Future<void> _dropIndices(DatabaseExecutor db) async {
    await db.execute('DROP INDEX IF EXISTS idx_cleanTitle');
    await db.execute('DROP INDEX IF EXISTS idx_releaseDateTs');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 5) {
      await db.execute('DROP TABLE IF EXISTS games');
      await db.execute('DROP TABLE IF EXISTS meta_filters');
      await _createDB(db, newVersion);
    }
  }

  Future<void> clearAllData() async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete('games');
    await db.delete('meta_filters');
    debugPrint('Base de datos limpiada.');
  }

  Future<void> saveMetaFilters(
      List<String> genres, 
      List<String> voices, 
      List<String> texts, 
      List<String> years, 
      List<String> platforms) async {
    if (kIsWeb) return;
    final db = await database;
    
    await db.transaction((txn) async {
      await txn.delete('meta_filters');
      
      final batch = txn.batch();
      
      int i = 0;
      for (var g in genres) {
        batch.insert('meta_filters', {'type': 'genre', 'value': g, 'display_order': i++});
      }
      i = 0;
      for (var v in voices) {
        batch.insert('meta_filters', {'type': 'voice', 'value': v, 'display_order': i++});
      }
      i = 0;
      for (var t in texts) {
        batch.insert('meta_filters', {'type': 'text', 'value': t, 'display_order': i++});
      }
      i = 0;
      for (var y in years) {
        batch.insert('meta_filters', {'type': 'year', 'value': y, 'display_order': i++});
      }
      // Guardamos plataformas tal cual vienen (alfabéticas o como decida DataService), 
      // pero usaremos una query especial para los "Top Chips"
      i = 0;
      for (var p in platforms) {
        batch.insert('meta_filters', {'type': 'platform', 'value': p, 'display_order': i++});
      }
      
      await batch.commit(noResult: true);
    });
    debugPrint('Filtros dinámicos guardados.');
  }

  Future<Map<String, List<String>>> getMetaFilters() async {
    if (kIsWeb) return {};
    final db = await database;
    
    final result = await db.query('meta_filters', orderBy: 'display_order ASC'); // Recuperamos en orden guardado
    
    final genres = <String>[];
    final voices = <String>[];
    final texts = <String>[];
    final years = <String>[];
    final platforms = <String>[];
    
    for (var row in result) {
      final val = row['value'] as String;
      switch (row['type']) {
        case 'genre': genres.add(val); break;
        case 'voice': voices.add(val); break;
        case 'text': texts.add(val); break;
        case 'year': years.add(val); break;
        case 'platform': platforms.add(val); break;
      }
    }
    
    // Devolvemos las listas. Las plataformas vienen completas para el buscador.
    return {
      'genres': genres,
      'voices': voices,
      'texts': texts,
      'years': years,
      'platforms': platforms,
    };
  }

  // NUEVO MÉTODO EFICIENTE PARA CHIPS
  Future<List<String>> getTopPlatformsRecent(int limit) async {
    if (kIsWeb) return [];
    final db = await database;
    
    // Calculamos timestamp de hace 1 año (aprox)
    final oneYearAgo = DateTime.now().subtract(const Duration(days: 365)).millisecondsSinceEpoch;

    // Esta query es un poco compleja porque 'plataformas' es un JSON Array string.
    // SQLite nativo no tiene funciones JSON potentes habilitadas en todas las versiones de Android antigua.
    // ESTRATEGIA: Recuperamos SOLO las plataformas de juegos recientes y hacemos el conteo en Dart (memoria).
    // Es rápido porque recuperamos solo una columna de texto de unos pocos cientos de registros recientes.

    try {
      final List<Map<String, dynamic>> result = await db.query(
        'games',
        columns: ['plataformas'],
        where: 'releaseDateTs >= ?',
        whereArgs: [oneYearAgo],
      );

      final Map<String, int> counts = {};

      for (var row in result) {
        try {
          final List<dynamic> list = jsonDecode(row['plataformas'] as String);
          for (var p in list) {
            final pStr = p.toString();
            counts[pStr] = (counts[pStr] ?? 0) + 1;
          }
        } catch (_) {}
      }

      // Si no hay datos recientes, hacemos fallback al total histórico
      if (counts.isEmpty) {
        final List<Map<String, dynamic>> fallbackResult = await db.query(
           'games',
           columns: ['plataformas'],
           limit: 2000 // Limitamos para no saturar memoria en fallback
        );
        for (var row in fallbackResult) {
          try {
             final List<dynamic> list = jsonDecode(row['plataformas'] as String);
             for (var p in list) {
               final pStr = p.toString();
               counts[pStr] = (counts[pStr] ?? 0) + 1;
             }
          } catch (_) {}
        }
      }

      final sortedKeys = counts.keys.toList()
        ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

      return sortedKeys.take(limit).toList();

    } catch (e) {
      debugPrint('Error obteniendo top plataformas: $e');
      return [];
    }
  }

  Future<void> insertGames(List<Game> games, {Function(double progress)? onProgress}) async {
    if (kIsWeb) return;

    final db = await database;
    const int batchSize = 200; 
    int total = games.length;

    debugPrint('Iniciando inserción v4 con TurboMode dinámico...');

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
          if (tipoAGuardar.isEmpty) {
            tipoAGuardar = 'game';
          }

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
            'idiomas': jsonEncode({
              'voces': game.idiomas.voces,
              'textos': game.idiomas.textos,
            }),
            'idiomas_voces': jsonEncode(game.idiomas.voces),
            'idiomas_textos': jsonEncode(game.idiomas.textos),
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
      });

      if (onProgress != null) {
        onProgress(end / total);
      }

      if (turboMode) {
        await Future.delayed(Duration(milliseconds: insertDelay));
      } else {
        await Future.delayed(const Duration(milliseconds: 30));
      }
    }
    
    final counts = await db.rawQuery('SELECT tipo, COUNT(*) as c FROM games GROUP BY tipo');
    debugPrint('RESUMEN DE TIPOS EN DB: $counts');
    
    debugPrint('Inserción dinámica finalizada.');
  }

  Future<List<Game>> getGames({
    int limit = 20,
    int offset = 0,
    String? query,
    String? voiceLanguage,
    String? textLanguage,
    String? year,
    String? genre,
    String? platform,
    String? tipo,
    String sortBy = 'date', // NUEVO PARAMETRO
  }) async {
    if (kIsWeb) return [];

    final db = await database;
    String? whereClause;
    List<dynamic> whereArgs = [];

    if (query != null && query.isNotEmpty) {
      String cleanQuery = Game.normalize(query);
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

    if (tipo != null) {
      addCondition('tipo = ?', tipo);
    }

    if (voiceLanguage != null && voiceLanguage != 'Cualquiera') {
      addCondition('idiomas_voces LIKE ?', '%${jsonEncode(voiceLanguage)}%');
    }

    if (textLanguage != null && textLanguage != 'Cualquiera') {
      addCondition('idiomas_textos LIKE ?', '%${jsonEncode(textLanguage)}%');
    }

    if (year != null && year != 'Cualquiera') {
      addCondition('fecha_lanzamiento LIKE ?', '$year%');
    }

    if (genre != null && genre != 'Cualquiera') {
      addCondition('generos LIKE ?', '%"$genre"%'); 
    }

    if (platform != null && platform != 'Cualquiera') {
      addCondition('plataformas LIKE ?', '%"$platform"%');
    }

    // LÓGICA DE ORDENACIÓN
    String orderByClause = 'releaseDateTs DESC';
    if (sortBy == 'score') {
      orderByClause = 'metacritic DESC, releaseDateTs DESC'; // Nota alta primero, luego fecha
    }

    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'games',
        where: whereClause,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        limit: limit,
        offset: offset,
        orderBy: orderByClause,
      );
      
      if (offset == 0) debugPrint('getGames -> Resultados encontrados: ${maps.length}');
      
      return maps.map((dbMap) {
          Map<String, dynamic> jsonMap = Map.of(dbMap);
          try {
            jsonMap['generos'] = jsonDecode(dbMap['generos'] ?? '[]');
            jsonMap['plataformas'] = jsonDecode(dbMap['plataformas'] ?? '[]');
            jsonMap['galeria'] = jsonDecode(dbMap['galeria'] ?? '[]');
            jsonMap['idiomas'] = jsonDecode(dbMap['idiomas'] ?? '{}');
            jsonMap['tiendas'] = jsonDecode(dbMap['tiendas'] ?? '[]');
          } catch (e) {
          }
          return Game.fromJson(jsonMap);
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
