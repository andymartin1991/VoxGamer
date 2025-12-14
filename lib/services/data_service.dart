import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // Para kIsWeb y debugPrint
import '../models/steam_game.dart';
import 'database_helper.dart';

class DataService {
  static const String _dataUrl = 'https://raw.githubusercontent.com/andymartin1991/SteamDataScraper/main/juegos_nuevos.json';
  
  // Instancia de DB Helper solo para móvil
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Caché en memoria exclusiva para Web
  List<SteamGame> _webCache = [];

  Future<bool> needsUpdate() async {
    if (kIsWeb) {
      // En Web siempre necesitamos cargar los datos al inicio porque no hay persistencia
      return _webCache.isEmpty;
    } else {
      // En móvil comprobamos si la DB está vacía
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
      // Timestamp anti-caché
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
  
  Future<List<SteamGame>> getLocalGames({int limit = 20, int offset = 0, String? query}) async {
    if (kIsWeb) {
      // Implementación en memoria para Web
      var filtered = _webCache;
      
      // Filtrado
      if (query != null && query.isNotEmpty) {
        final q = query.toLowerCase();
        filtered = _webCache.where((g) => g.title.toLowerCase().contains(q)).toList();
      }

      // Paginación simulada
      if (offset >= filtered.length) return [];
      
      final end = (offset + limit < filtered.length) ? offset + limit : filtered.length;
      return filtered.sublist(offset, end);
      
    } else {
      // Implementación SQLite para Nativo
      return _dbHelper.getGames(limit: limit, offset: offset, query: query);
    }
  }
}
