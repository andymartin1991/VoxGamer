import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import '../models/steam_game.dart';
import 'database_helper.dart';

class SyncResult {
  final List<SteamGame> games;
  final List<String> genres;
  final List<String> voices;
  final List<String> texts;
  final List<String> years; // Nuevo campo

  SyncResult(this.games, this.genres, this.voices, this.texts, this.years);
}

class DataService {
  static const String _dataUrl = 'https://raw.githubusercontent.com/andymartin1991/SteamDataScraper/main/steam_games.json.gz';

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  List<SteamGame> _webCache = [];
  Map<String, List<String>> _webFilters = {};

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

  Future<void> syncGames() async {
    try {
      debugPrint('Iniciando descarga de juegos comprimidos (${kIsWeb ? "Web Mode" : "Native Mode"})...');
      final uri = Uri.parse('$_dataUrl?t=${DateTime.now().millisecondsSinceEpoch}');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        debugPrint('Descarga completada. Tamaño comprimido: ${(response.bodyBytes.length / 1024).toStringAsFixed(2)} KB.');
        
        if (response.bodyBytes.isEmpty) throw Exception('El archivo descargado está vacío.');

        final SyncResult result = await compute(_decompressAndParse, response.bodyBytes);
        
        if (kIsWeb) {
          debugPrint('Guardando ${result.games.length} juegos en memoria RAM (Web)...');
          result.games.sort((a, b) => b.releaseDateTs.compareTo(a.releaseDateTs));
          _webCache = result.games;
          _webFilters = {
            'genres': result.genres,
            'voices': result.voices,
            'texts': result.texts,
            'years': result.years,
          };
        } else {
          debugPrint('Insertando ${result.games.length} juegos en SQLite (Nativo)...');
          await _dbHelper.insertGames(result.games);
          // Guardamos también los años extraídos
          await _dbHelper.saveMetaFilters(result.genres, result.voices, result.texts, result.years);
        }

        debugPrint('Sincronización finalizada correctamente.');
      } else {
        throw Exception('Error HTTP al descargar: ${response.statusCode}');
      }
    } catch (e, stack) {
      debugPrint('Error CRÍTICO en syncGames: $e');
      debugPrintStack(stackTrace: stack);
      rethrow;
    }
  }
  
  static SyncResult _decompressAndParse(Uint8List compressedBytes) {
    try {
      final List<int> decompressedBytes = GZipDecoder().decodeBytes(compressedBytes);
      final String jsonString = utf8.decode(decompressedBytes);
      final decoded = json.decode(jsonString);
      
      List<SteamGame> games = [];
      if (decoded is List) {
        games = decoded.map<SteamGame>((json) => SteamGame.fromJson(json)).toList();
      } else if (decoded is Map) {
        games = [SteamGame.fromJson(decoded as Map<String, dynamic>)];
      } else {
        throw Exception('El JSON no es ni una lista ni un mapa: ${decoded.runtimeType}');
      }

      final Set<String> genresSet = {};
      final Set<String> voicesSet = {};
      final Set<String> textsSet = {};
      final Set<String> yearsSet = {}; // Set para años únicos

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
        
        // Extracción de Año: "2013-10-22" -> "2013"
        if (game.fechaLanzamiento.length >= 4) {
          final yearCandidate = game.fechaLanzamiento.substring(0, 4);
          // Verificamos que sea numérico para no guardar basura
          if (int.tryParse(yearCandidate) != null) {
            yearsSet.add(yearCandidate);
          }
        }
      }

      final genresList = genresSet.toList()..sort();
      final voicesList = voicesSet.toList()..sort();
      final textsList = textsSet.toList()..sort();
      // Ordenamos años descendente (más recientes primero)
      final yearsList = yearsSet.toList()..sort((a, b) => b.compareTo(a));

      return SyncResult(games, genresList, voicesList, textsList, yearsList);

    } catch (e) {
      debugPrint('Error en _decompressAndParse: $e');
      rethrow;
    }
  }

  Future<List<SteamGame>> getLocalGames({
    int limit = 20,
    int offset = 0,
    String? query,
    String? voiceLanguage,
    String? textLanguage,
    String? year,
    String? genre,
  }) async {
    if (kIsWeb) {
      var filtered = _webCache;

      if (query != null && query.isNotEmpty) {
        String cleanQuery = SteamGame.normalize(query);
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

      if (offset >= filtered.length) return [];

      final end = (offset + limit < filtered.length)
          ? offset + limit
          : filtered.length;
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
        );
    }
  }
}
