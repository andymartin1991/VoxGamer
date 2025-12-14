import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; 
import '../models/steam_game.dart';
import 'database_helper.dart';

class DataService {
  static const String _dataUrl = 'https://raw.githubusercontent.com/andymartin1991/SteamDataScraper/main/juegos_nuevos.json';
  
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<SteamGame> _webCache = [];

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
    } else {
      await _dbHelper.clearAllData();
    }
  }

  Future<void> syncGames() async {
    try {
      debugPrint('Iniciando descarga de juegos (${kIsWeb ? "Web Mode" : "Native Mode"})...');
      final uri = Uri.parse('$_dataUrl?t=${DateTime.now().millisecondsSinceEpoch}');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        debugPrint('Descarga completada. Decodificando JSON...');
        
        final List<SteamGame> games = await compute(_parseGames, response.body);
        
        if (kIsWeb) {
          debugPrint('Guardando ${games.length} juegos en memoria RAM (Web)...');
          _webCache = games;
        } else {
          debugPrint('Insertando ${games.length} juegos en SQLite (Nativo)...');
          await _dbHelper.insertGames(games);
        }
        
        debugPrint('Sincronización finalizada.');
      } else {
        throw Exception('Error al descargar: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error en syncGames: $e');
      rethrow;
    }
  }

  static List<SteamGame> _parseGames(String responseBody) {
    final parsed = json.decode(responseBody).cast<Map<String, dynamic>>();
    return parsed.map<SteamGame>((json) => SteamGame.fromJson(json)).toList();
  }
  
  Future<List<SteamGame>> getLocalGames({
    int limit = 20, 
    int offset = 0, 
    String? query,
    String? voiceLanguage
  }) async {
    if (kIsWeb) {
      var filtered = _webCache;
      
      // Filtrado Búsqueda (sobre cleanTitle)
      if (query != null && query.isNotEmpty) {
        String cleanQuery = SteamGame(
          id: 0, title: query, languages: [], voices: []
        ).cleanTitle;
        
        filtered = filtered.where((g) => g.cleanTitle.contains(cleanQuery)).toList();
      }

      // Filtro de Voces
      if (voiceLanguage != null && voiceLanguage != 'Cualquiera') {
        filtered = filtered.where((g) => 
          g.voices.any((v) => v.toLowerCase().contains(voiceLanguage.toLowerCase()))
        ).toList();
      }

      // Ordenamiento Descendente por Fecha
      // Hacemos una copia para no alterar el orden original de la caché si no es necesario
      filtered = List.from(filtered);
      filtered.sort((a, b) => b.releaseDateTs.compareTo(a.releaseDateTs));

      // Paginación
      if (offset >= filtered.length) return [];
      
      final end = (offset + limit < filtered.length) ? offset + limit : filtered.length;
      return filtered.sublist(offset, end);
      
    } else {
      return _dbHelper.getGames(
        limit: limit, 
        offset: offset, 
        query: query,
        voiceLanguage: voiceLanguage
      );
    }
  }
}
