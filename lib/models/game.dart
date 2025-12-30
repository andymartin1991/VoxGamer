// lib/models/game.dart

class Game {
  final String slug;
  final String titulo;
  final String tipo; // "game" o "dlc"
  final String descripcionCorta;
  final String fechaLanzamiento;
  final String? storage;
  final List<String> generos;
  final List<String> plataformas;
  final String imgPrincipal;
  final List<String> galeria;
  final Idiomas idiomas;
  final int? metacritic;
  final List<Tienda> tiendas;
  
  // Nuevos campos
  final List<Video> videos;
  final List<String> desarrolladores;
  final List<String> editores;

  // Campos calculados para búsqueda y ordenamiento
  late final String cleanTitle;
  late final int releaseDateTs;

  Game({
    required this.slug,
    required this.titulo,
    required this.tipo,
    required this.descripcionCorta,
    required this.fechaLanzamiento,
    this.storage,
    required this.generos,
    required this.plataformas,
    required this.imgPrincipal,
    required this.galeria,
    required this.idiomas,
    this.metacritic,
    required this.tiendas,
    required this.videos,
    required this.desarrolladores,
    required this.editores,
  }) {
    cleanTitle = normalize(titulo);
    releaseDateTs = _parseDate(fechaLanzamiento);
  }

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      slug: json['slug'] ?? '',
      titulo: json['titulo'] ?? 'Sin título',
      tipo: json['tipo'] ?? 'game',
      descripcionCorta: _cleanDescription(json['descripcion_corta']),
      fechaLanzamiento: _cleanDate(json['fecha_lanzamiento']), // Limpiamos la fecha
      storage: json['storage'],
      generos: List<String>.from(json['generos'] ?? []),
      plataformas: List<String>.from(json['plataformas'] ?? []), 
      imgPrincipal: json['img_principal'] ?? '',
      galeria: List<String>.from(json['galeria'] ?? []),
      idiomas: Idiomas.fromJson(json['idiomas'] ?? {}),
      metacritic: json['metacritic'],
      tiendas: (json['tiendas'] as List<dynamic>?)
              ?.map((tiendaJson) => Tienda.fromJson(tiendaJson))
              .toList() ??
          [],
      videos: (json['videos'] as List<dynamic>?)
              ?.map((videoJson) => Video.fromJson(videoJson))
              .toList() ??
          [],
      desarrolladores: List<String>.from(json['desarrolladores'] ?? []),
      editores: List<String>.from(json['editores'] ?? []),
    );
  }

  static String _cleanDate(String? date) {
    if (date == null) return '';
    if (date.toLowerCase() == 'null') return ''; // El fix clave
    if (date.trim().isEmpty) return '';
    return date;
  }

  static String _cleanDescription(String? text) {
    if (text == null || text.isEmpty) return '';
    
    // 1. Reemplazar escapes literales comunes de JSON
    String clean = text;
    
    // Reemplazar "\\n" (literal) por "\n" (control)
    clean = clean.replaceAll(r'\n', '\n');
    
    // Reemplazar "\\r" por nada
    clean = clean.replaceAll(r'\r', ''); 
    
    // Reemplazar "\\t" por tabulación
    clean = clean.replaceAll(r'\t', '\t');

    // Reemplazar comillas escapadas \"
    clean = clean.replaceAll(r'\"', '"');

    return clean;
  }

  static String normalize(String input) {
    var str = input.toLowerCase();
    str = str.replaceAll(RegExp(r'[àáâãäå]'), 'a');
    str = str.replaceAll(RegExp(r'[èéêë]'), 'e');
    str = str.replaceAll(RegExp(r'[ìíîï]'), 'i');
    str = str.replaceAll(RegExp(r'[òóôõö]'), 'o');
    str = str.replaceAll(RegExp(r'[ùúûü]'), 'u');
    str = str.replaceAll(RegExp(r'[ñ]'), 'n');
    str = str.replaceAll(RegExp(r'[ç]'), 'c');
    return str.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static int _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 0;
    // Si viene "null" literal, devolvemos 0 (para que se ordene al final)
    if (dateStr.toLowerCase() == 'null') return 0;
    try {
      return DateTime.parse(dateStr).millisecondsSinceEpoch;
    } catch (e) {
      return 0;
    }
  }
}

class Idiomas {
  final List<String> voces;
  final List<String> textos;

  Idiomas({required this.voces, required this.textos});

  factory Idiomas.fromJson(Map<String, dynamic> json) {
    return Idiomas(
      voces: List<String>.from(json['voces'] ?? []),
      textos: List<String>.from(json['textos'] ?? []),
    );
  }
}

class Tienda {
  final String tienda;
  final String idExterno;
  final String url;
  final bool isFree;

  Tienda({
    required this.tienda,
    required this.idExterno,
    required this.url,
    required this.isFree,
  });

  factory Tienda.fromJson(Map<String, dynamic> json) {
    return Tienda(
      tienda: json['tienda'] ?? '',
      idExterno: json['id_externo'] ?? '',
      url: json['url'] ?? '',
      isFree: json['is_free'] ?? false,
    );
  }
}

class Video {
  final String titulo;
  final String thumbnail;
  final String url;

  Video({
    required this.titulo,
    required this.thumbnail,
    required this.url,
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      titulo: json['titulo'] ?? '',
      thumbnail: json['thumbnail'] ?? '',
      url: json['url'] ?? '',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'titulo': titulo,
      'thumbnail': thumbnail,
      'url': url,
    };
  }
}
