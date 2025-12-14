class SteamGame {
  final int id;
  final String title;
  final String? releaseDate;
  final String? size;
  final String? steamUrl;
  final String? headerImage;
  final List<String> languages; // 'idiomas_texto'
  final List<String> voices;    // 'idiomas_voces'

  SteamGame({
    required this.id,
    required this.title,
    this.releaseDate,
    this.size,
    this.steamUrl,
    this.headerImage,
    required this.languages,
    required this.voices,
  });

  factory SteamGame.fromJson(Map<String, dynamic> json) {
    // Helper para limpiar espacios extra que puedan venir del scraping
    List<String> parseList(String key) {
      if (json[key] != null) {
        return List<String>.from(json[key])
            .map((s) => s.toString().trim()) // Importante: Trim para evitar duplicados "English " vs "English"
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
}
