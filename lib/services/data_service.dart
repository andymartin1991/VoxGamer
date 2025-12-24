import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/game.dart';
import 'database_helper.dart';

class SyncResult {
  final List<Game> games;
  final List<String> genres;
  final List<String> voices;
  final List<String> texts;
  final List<String> years;
  final List<String> platforms;

  SyncResult(this.games, this.genres, this.voices, this.texts, this.years, this.platforms);
}

class DataService {
  static const String _dataUrl = 'https://raw.githubusercontent.com/andymartin1991/SteamDataScraper/main/global_games.json.gz';
  // NUEVA URL (Placeholder para cuando tengas el JSON de Próximos Lanzamientos)
  static const String _upcomingDataUrl = 'https://raw.githubusercontent.com/andymartin1991/SteamDataScraper/main/upcoming_games.json.gz';
  
  static const String _localFileName = 'games_cache.json.gz';

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  List<Game> _webCache = [];
  Map<String, List<String>> _webFilters = {};

  // Método público para contar juegos
  Future<int> countLocalGames() async {
    if (kIsWeb) return _webCache.length;
    return await _dbHelper.countGames();
  }

  Future<bool> needsUpdate() async {
    if (kIsWeb) {
      return _webCache.isEmpty;
    } else {
      final count = await _dbHelper.countGames();
      return count == 0;
    }
  }

  Future<void> clearDatabase() async {
    if (kIsWeb) {
      _webCache.clear();
      _webFilters.clear();
    } else {
      await _dbHelper.clearAllData();
    }
  }

  Future<Map<String, List<String>>> getFilterOptions() async {
    if (kIsWeb) {
      return _webFilters;
    } else {
      return await _dbHelper.getMetaFilters();
    }
  }

  // NUEVO MÉTODO PASARELA
  Future<List<String>> getTopPlatforms(int limit) async {
    if (kIsWeb) return []; 
    return await _dbHelper.getTopPlatformsRecent(limit);
  }

  Future<void> syncGames({Function(double progress)? onProgress, bool forceDownload = true}) async {
    try {
      if (kIsWeb) {
        await _syncWeb(onProgress);
      } else {
        if (!forceDownload) {
          final gameCount = await _dbHelper.countGames();
          if (gameCount > 1000) { 
            debugPrint('Sincronización omitida: La BBDD ya contiene $gameCount juegos.');
            if (onProgress != null) onProgress(1.0); 
            return;
          }
        }
        await _syncNative(onProgress, forceDownload);
      }
    } catch (e, stack) {
      debugPrint('Error CRÍTICO en syncGames: $e');
      debugPrintStack(stackTrace: stack);
      rethrow;
    }
  }

  Future<void> _syncWeb(Function(double progress)? onProgress) async {
    final uri = Uri.parse('$_dataUrl?t=${DateTime.now().millisecondsSinceEpoch}');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      if (onProgress != null) onProgress(0.1);
      final SyncResult result = await compute(_decompressAndParse, response.bodyBytes);
      if (onProgress != null) onProgress(0.2);
      
      _webCache = result.games;
      _webFilters = {
        'genres': result.genres,
        'voices': result.voices,
        'texts': result.texts,
        'years': result.years,
        'platforms': result.platforms,
      };
      if (onProgress != null) onProgress(1.0);
    }
  }

  Future<void> _syncNative(Function(double progress)? onProgress, bool forceDownload) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$_localFileName';
    final file = File(filePath);

    bool fileExists = await file.exists();
    
    if (forceDownload || !fileExists) {
        debugPrint('Iniciando descarga a archivo: $filePath');
        if (onProgress != null) onProgress(0.01);

        final request = http.Request('GET', Uri.parse('$_dataUrl?t=${DateTime.now().millisecondsSinceEpoch}'));
        final response = await http.Client().send(request);
        
        if (response.statusCode != 200) throw Exception('Error descarga: ${response.statusCode}');

        final totalBytes = response.contentLength ?? 0;
        int receivedBytes = 0;

        final sink = file.openWrite();
        await response.stream.forEach((chunk) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          
          if (onProgress != null) {
            if (totalBytes > 0) {
               onProgress((receivedBytes / totalBytes) * 0.2);
            } else {
               double fakeProgress = 0.05 + ((receivedBytes % 1000000) / 1000000) * 0.1;
               onProgress(fakeProgress);
            }
          }
        });
        await sink.flush();
        await sink.close();
        debugPrint('Descarga completada en disco.');
    } else {
        debugPrint('Archivo local encontrado. Saltando descarga.');
        if (onProgress != null) onProgress(0.2); 
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw Exception("El archivo cacheado está vacío.");

    final SyncResult result = await compute(_decompressAndParse, bytes);
    
    debugPrint('Insertando ${result.games.length} juegos en SQLite...');
    
    await _dbHelper.insertGames(result.games, onProgress: (dbProgress) {
      if (onProgress != null) {
        final totalProgress = 0.2 + (dbProgress * 0.8);
        onProgress(totalProgress);
      }
    });
    
    // GUARDAR FILTROS (Incluyendo lógica dedicada)
    await _dbHelper.saveMetaFilters(result.genres, result.voices, result.texts, result.years, result.platforms);
    
    // -------------------------------------------------------------
    // AQUÍ IRÍA LA LLAMADA FUTURA A _syncUpcoming()
    // -------------------------------------------------------------
    // await _syncUpcoming(onProgress); 
  }

  // MÉTODO SKELETON PARA FUTURA IMPLEMENTACIÓN
  Future<void> _syncUpcoming(Function(double progress)? onProgress) async {
     debugPrint("Sincronizando próximos lanzamientos...");
     // 1. Descargar _upcomingDataUrl
     // 2. Descomprimir
     // 3. Insertar en tabla 'upcoming_games' (que deberás crear en DatabaseHelper)
  }
  
  static SyncResult _decompressAndParse(Uint8List compressedBytes) {
    try {
      final List<int> decompressedBytes = GZipDecoder().decodeBytes(compressedBytes);
      final String jsonString = utf8.decode(decompressedBytes);
      final decoded = json.decode(jsonString);
      
      List<Game> games = [];
      if (decoded is List) {
        games = decoded.map<Game>((json) => Game.fromJson(json)).toList();
      } else if (decoded is Map) {
        games = [Game.fromJson(decoded as Map<String, dynamic>)];
      } else {
        throw Exception('El JSON no es ni una lista ni un mapa: ${decoded.runtimeType}');
      }

      final Set<String> genresSet = {};
      final Set<String> voicesSet = {};
      final Set<String> textsSet = {};
      final Set<String> yearsSet = {};
      final Set<String> allPlatformsSet = {};

      for (var game in games) {
        for (var g in game.generos) {
          if (g.isNotEmpty) genresSet.add(g.trim());
        }
        for (var v in game.idiomas.voces) {
          if (v.isNotEmpty) voicesSet.add(v.trim());
        }
        for (var t in game.idiomas.textos) {
          if (t.isNotEmpty) textsSet.add(t.trim());
        }
        for (var p in game.plataformas) {
          final plat = p.trim();
          if (plat.isNotEmpty) {
            allPlatformsSet.add(plat);
          }
        }
        
        if (game.fechaLanzamiento.length >= 4) {
          final yearCandidate = game.fechaLanzamiento.substring(0, 4);
          if (int.tryParse(yearCandidate) != null) {
            yearsSet.add(yearCandidate);
          }
        }
      }

      final genresList = genresSet.toList()..sort();
      final voicesList = voicesSet.toList()..sort();
      final textsList = textsSet.toList()..sort();
      final yearsList = yearsSet.toList()..sort((a, b) => b.compareTo(a));
      final platformsList = allPlatformsSet.toList()..sort(); 

      return SyncResult(games, genresList, voicesList, textsList, yearsList, platformsList);

    } catch (e) {
      debugPrint('Error en _decompressAndParse: $e');
      rethrow;
    }
  }

  Future<List<Game>> getLocalGames({
    int limit = 20,
    int offset = 0,
    String? query,
    String? voiceLanguage,
    String? textLanguage,
    String? year,
    String? genre,
    String? platform,
    String? tipo,
    String sortBy = 'date',
  }) async {
    if (kIsWeb) {
      var filtered = _webCache;

      if (tipo != null) {
        filtered = filtered.where((g) => g.tipo == tipo).toList();
      }

      if (query != null && query.isNotEmpty) {
        String cleanQuery = Game.normalize(query);
        filtered = filtered.where((g) => g.cleanTitle.contains(cleanQuery)).toList();
      }
      
      if (voiceLanguage != null && voiceLanguage != 'Cualquiera') {
        filtered = filtered.where((g) => g.idiomas.voces.contains(voiceLanguage)).toList();
      }

      if (textLanguage != null && textLanguage != 'Cualquiera') {
        filtered = filtered.where((g) => g.idiomas.textos.contains(textLanguage)).toList();
      }

      if (year != null && year != 'Cualquiera') {
        filtered = filtered.where((g) => g.fechaLanzamiento.startsWith(year)).toList();
      }

      if (genre != null && genre != 'Cualquiera') {
        filtered = filtered.where((g) => g.generos.contains(genre)).toList();
      }

      if (platform != null && platform != 'Cualquiera') {
        filtered = filtered.where((g) => g.plataformas.contains(platform)).toList();
      }

      if (sortBy == 'score') {
        filtered.sort((a, b) => (b.metacritic ?? 0).compareTo(a.metacritic ?? 0));
      } else {
        filtered.sort((a, b) => b.releaseDateTs.compareTo(a.releaseDateTs));
      }

      if (offset >= filtered.length) return [];
      final end = (offset + limit < filtered.length) ? offset + limit : filtered.length;
      return filtered.sublist(offset, end);

    } else {
        return _dbHelper.getGames(
          limit: limit,
          offset: offset,
          query: query,
          voiceLanguage: voiceLanguage,
          textLanguage: textLanguage,
          year: year,
          genre: genre,
          platform: platform,
          tipo: tipo,
          sortBy: sortBy,
        );
    }
  }
}
