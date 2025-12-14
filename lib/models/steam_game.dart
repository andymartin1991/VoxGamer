class SteamGame {
  final int id;
  final String title;
  final String? releaseDate;
  final String? size;
  final String? steamUrl;
  final String? headerImage;
  final List<String> languages;
  final List<String> voices;
  
  // Nuevos campos calculados
  late final String cleanTitle; // Para búsqueda inteligente
  late final int releaseDateTs; // Para ordenamiento

  SteamGame({
    required this.id,
    required this.title,
    this.releaseDate,
    this.size,
    this.steamUrl,
    this.headerImage,
    required this.languages,
    required this.voices,
    String? cleanTitle,
    int? releaseDateTs,
  }) {
    // Generamos el título limpio si no viene dado
    this.cleanTitle = cleanTitle ?? _normalize(title);
    // Parseamos la fecha si no viene dada
    this.releaseDateTs = releaseDateTs ?? _parseDate(releaseDate);
  }

  factory SteamGame.fromJson(Map<String, dynamic> json) {
    List<String> parseList(String key) {
      if (json[key] != null) {
        return List<String>.from(json[key])
            .map((s) => s.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
      return [];
    }

    return SteamGame(
      id: json['id'] ?? 0,
      title: json['titulo'] ?? 'Sin título',
      releaseDate: json['fecha'],
      size: json['size'],
      steamUrl: json['url_steam'],
      headerImage: json['img'],
      languages: parseList('idiomas_texto'),
      voices: parseList('idiomas_voces'),
    );
  }

  // Normalizador agresivo: quita acentos, símbolos y espacios
  static String _normalize(String input) {
    var str = input.toLowerCase();
    
    // Reemplazos manuales de acentos comunes
    str = str.replaceAll(RegExp(r'[àáâãäå]'), 'a');
    str = str.replaceAll(RegExp(r'[èéêë]'), 'e');
    str = str.replaceAll(RegExp(r'[ìíîï]'), 'i');
    str = str.replaceAll(RegExp(r'[òóôõö]'), 'o');
    str = str.replaceAll(RegExp(r'[ùúûü]'), 'u');
    str = str.replaceAll(RegExp(r'[ñ]'), 'n');
    str = str.replaceAll(RegExp(r'[ç]'), 'c');
    
    // Elimina todo lo que NO sea letra o número
    return str.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static int _parseDate(String? dateStr) {
    if (dateStr == null) return 0;
    
    // Formatos típicos de Steam: "9 Jun, 2021", "Oct 2020", "2023", "Coming soon"
    try {
      // Si dice "Coming soon" o "TBA", lo ponemos muy en el futuro
      if (dateStr.toLowerCase().contains('coming') || 
          dateStr.toLowerCase().contains('tba') || 
          dateStr.toLowerCase().contains('to be')) {
        return 9999999999999; 
      }

      // Intentamos parsear formato estándar "9 Jun, 2021"
      // Como Dart no tiene un DateFormat flexible sin librerías externas (intl),
      // hacemos un parseo manual básico o usamos un fallback.
      
      // Mapeo rápido de meses
      final months = {
        'Jan': '01', 'Feb': '02', 'Mar': '03', 'Apr': '04', 'May': '05', 'Jun': '06',
        'Jul': '07', 'Aug': '08', 'Sep': '09', 'Oct': '10', 'Nov': '11', 'Dec': '12'
      };

      // Limpiamos la coma
      String clean = dateStr.replaceAll(',', ''); 
      List<String> parts = clean.split(' ');

      // Caso "9 Jun 2021" (3 partes)
      if (parts.length == 3) {
        String d = parts[0].padLeft(2, '0');
        String m = months[parts[1]] ?? '01';
        String y = parts[2];
        return DateTime.parse('$y-$m-$d').millisecondsSinceEpoch;
      }
      // Caso "Jun 2021" (2 partes)
      else if (parts.length == 2) {
         String m = months[parts[0]] ?? '01';
         String y = parts[1];
         // Si es numérico asumimos año
         if (int.tryParse(parts[0]) != null) { 
           // Caso raro, asumimos primer parte
           return DateTime(int.parse(parts[0])).millisecondsSinceEpoch;
         }
         return DateTime.parse('$y-$m-01').millisecondsSinceEpoch;
      }
      // Caso "2021" (1 parte)
      else if (parts.length == 1 && int.tryParse(parts[0]) != null) {
        return DateTime(int.parse(parts[0])).millisecondsSinceEpoch;
      }

    } catch (e) {
      // Si falla, retornamos 0 (fecha antigua)
    }
    return 0;
  }
}
