// lib/models/steam_game.dart

class SteamGame {
  final String slug;
  final String titulo;
  final String descripcionCorta;
  final String fechaLanzamiento;
  final String? storage;
  final List<String> generos;
  final String imgPrincipal;
  final List<String> galeria;
  final Idiomas idiomas;
  final int? metacritic;
  final List<Tienda> tiendas;

  // Campos calculados para búsqueda y ordenamiento
  late final String cleanTitle;
  late final int releaseDateTs;

  SteamGame({
    required this.slug,
    required this.titulo,
    required this.descripcionCorta,
    required this.fechaLanzamiento,
    this.storage,
    required this.generos,
    required this.imgPrincipal,
    required this.galeria,
    required this.idiomas,
    this.metacritic,
    required this.tiendas,
  }) {
    cleanTitle = normalize(titulo); // Cambiado a método público
    releaseDateTs = _parseDate(fechaLanzamiento);
  }

  factory SteamGame.fromJson(Map<String, dynamic> json) {
    return SteamGame(
      slug: json['slug'] ?? '',
      titulo: json['titulo'] ?? 'Sin título',
      descripcionCorta: json['descripcion_corta'] ?? '',
      fechaLanzamiento: json['fecha_lanzamiento'] ?? '',
      storage: json['storage'],
      generos: List<String>.from(json['generos'] ?? []),
      imgPrincipal: json['img_principal'] ?? '',
      galeria: List<String>.from(json['galeria'] ?? []),
      idiomas: Idiomas.fromJson(json['idiomas'] ?? {}),
      metacritic: json['metacritic'],
      tiendas: (json['tiendas'] as List<dynamic>?)
              ?.map((tiendaJson) => Tienda.fromJson(tiendaJson))
              .toList() ??
          [],
    );
  }

  // Ahora es público para ser accesible desde otros archivos
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
    try {
      return DateTime.parse(dateStr).millisecondsSinceEpoch;
    } catch (e) {
      // Si el formato no es 'YYYY-MM-DD', retorna 0
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
