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
    _database = await _initDB('voxgamer_v2.db');
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
    // Índices para mejorar la velocidad de búsqueda y ordenamiento
    await db.execute('CREATE INDEX idx_cleanTitle ON games(cleanTitle)');
    await db.execute('CREATE INDEX idx_releaseDateTs ON games(releaseDateTs)');
  }

  Future<void> clearAllData() async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete('games');
    debugPrint('Base de datos limpiada.');
  }

  // OPTIMIZADO: Inserción por lotes (Chunks)
  Future<void> insertGames(List<SteamGame> games) async {
    if (kIsWeb) return;

    final db = await database;
    const int batchSize = 500; // Tamaño del lote seguro
    int total = games.length;

    debugPrint('Iniciando inserción de $total juegos en lotes de $batchSize...');

    // Usamos una transacción global para velocidad, pero commits internos si fuera necesario
    // Para 75k registros, una sola transacción está bien si los batches no son gigantes en memoria.
    await db.transaction((txn) async {
      // Borramos todo primero
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
        
        // Progreso en consola cada 5000 registros
        if (end % 5000 == 0 || end == total) {
           debugPrint('Insertados $end / $total juegos...');
        }
      }
    });
    debugPrint('Inserción masiva finalizada.');
  }

  Future<List<SteamGame>> getGames({
    int limit = 20,
    int offset = 0,
    String? query,
    String? voiceLanguage,
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

    if (voiceLanguage != null && voiceLanguage != 'Cualquiera') {
       if (whereClause != null) {
        whereClause += ' AND idiomas LIKE ?';
      } else {
        whereClause = 'idiomas LIKE ?';
      }
      whereArgs.add('%"voces":%${jsonEncode(voiceLanguage)}%');
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
      
      debugPrint('SQL Query result: ${maps.length} rows found (offset: $offset, limit: $limit)');

      return maps.map((dbMap) {
          Map<String, dynamic> jsonMap = Map.of(dbMap);
          // Decodificación segura
          try {
            jsonMap['generos'] = jsonDecode(dbMap['generos'] ?? '[]');
            jsonMap['galeria'] = jsonDecode(dbMap['galeria'] ?? '[]');
            jsonMap['idiomas'] = jsonDecode(dbMap['idiomas'] ?? '{}');
            jsonMap['tiendas'] = jsonDecode(dbMap['tiendas'] ?? '[]');
          } catch (e) {
            debugPrint('Error decodificando JSON de DB para juego ${dbMap['slug']}: $e');
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
      final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM games')) ?? 0;
      debugPrint('Total juegos en DB: $count');
      return count;
    } catch (e) {
      debugPrint('Error contando juegos: $e');
      return 0;
    }
  }
}
