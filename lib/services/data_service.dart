import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart'; // Importante para descomprimir
import '../models/steam_game.dart';
import 'database_helper.dart';

class DataService {
  // URL actualizada para el archivo comprimido .gz
  static const String _dataUrl = 'https://raw.githubusercontent.com/andymartin1991/SteamDataScraper/main/steam_games.json.gz';

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  // Cache en memoria para Web
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
      debugPrint('Iniciando descarga de juegos comprimidos (${kIsWeb ? "Web Mode" : "Native Mode"})...');
      final uri = Uri.parse('$_dataUrl?t=${DateTime.now().millisecondsSinceEpoch}');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        debugPrint('Descarga completada. Tamaño comprimido: ${(response.bodyBytes.length / 1024).toStringAsFixed(2)} KB.');
        
        if (response.bodyBytes.isEmpty) {
          throw Exception('El archivo descargado está vacío.');
        }

        // Usamos compute para la descompresión y el parseo pesado
        // Pasamos los bytes crudos al isolate para evitar congelar la UI durante la descompresión
        final List<SteamGame> games = await compute(_decompressAndParse, response.bodyBytes);
        
        if (games.isEmpty) {
           debugPrint('Advertencia: La lista de juegos parseada está vacía.');
        }

        if (kIsWeb) {
          debugPrint('Guardando ${games.length} juegos en memoria RAM (Web)...');
          // Ordenamos una sola vez al inicio
          games.sort((a, b) => b.releaseDateTs.compareTo(a.releaseDateTs));
          _webCache = games;
        } else {
          debugPrint('Insertando ${games.length} juegos en SQLite (Nativo)...');
          await _dbHelper.insertGames(games);
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
  
  static int minimum(int a, int b) => (a < b) ? a : b;

  // Esta función ahora se encarga de TODO el trabajo pesado: Descomprimir -> Decodificar UTF8 -> Parsear JSON
  static List<SteamGame> _decompressAndParse(Uint8List compressedBytes) {
    try {
      // 1. Descomprimir GZIP
      // Usamos GZipDecoder de package:archive
      final List<int> decompressedBytes = GZipDecoder().decodeBytes(compressedBytes);
      
      // 2. Convertir bytes a String UTF-8
      final String jsonString = utf8.decode(decompressedBytes);
      
      // 3. Parsear JSON
      final decoded = json.decode(jsonString);
      
      if (decoded is List) {
        return decoded.map<SteamGame>((json) => SteamGame.fromJson(json)).toList();
      } else if (decoded is Map) {
        return [SteamGame.fromJson(decoded as Map<String, dynamic>)];
      } else {
        throw Exception('El JSON no es ni una lista ni un mapa: ${decoded.runtimeType}');
      }
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
  }) async {
    if (kIsWeb) {
      var filtered = _webCache;

      if (query != null && query.isNotEmpty) {
        String cleanQuery = SteamGame.normalize(query);
        filtered = filtered.where((g) => g.cleanTitle.contains(cleanQuery)).toList();
      }

      if (voiceLanguage != null && voiceLanguage != 'Cualquiera') {
        filtered = filtered
            .where((g) => g.idiomas.voces.any(
                (v) => v.toLowerCase().contains(voiceLanguage.toLowerCase())))
            .toList();
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
          voiceLanguage: voiceLanguage
        );
    }
  }
}
