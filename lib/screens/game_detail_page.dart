import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/steam_game.dart';

class GameDetailPage extends StatelessWidget {
  final SteamGame game;

  const GameDetailPage({super.key, required this.game});

  Future<void> _launchUrlInBrowser(BuildContext context, String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo abrir el enlace: $url')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error abriendo URL: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al abrir el navegador.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Obtenemos la URL de la primera tienda, si existe.
    final storeUrl = game.tiendas.isNotEmpty ? game.tiendas.first.url : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(game.titulo, overflow: TextOverflow.ellipsis),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen de cabecera
            if (game.imgPrincipal.isNotEmpty)
              Image.network(
                game.imgPrincipal,
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 220,
                  color: Colors.grey[300],
                  child: const Center(child: Icon(Icons.broken_image, size: 64)),
                ),
              )
            else
              Container(
                height: 220,
                color: Colors.grey[300],
                child: const Center(child: Icon(Icons.videogame_asset, size: 64)),
              ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Text(
                    game.titulo,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  // Descripción corta
                  Text(
                    game.descripcionCorta,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 16),

                  // Información Grid
                  _buildInfoRow(context, Icons.calendar_today, 'Lanzamiento',
                      game.fechaLanzamiento.isNotEmpty ? game.fechaLanzamiento : 'N/A'),
                  const SizedBox(height: 12),
                  _buildInfoRow(context, Icons.sd_storage, 'Tamaño',
                      game.storage ?? 'N/A'),
                   if (game.metacritic != null) ...[
                    const SizedBox(height: 12),
                    _buildInfoRow(context, Icons.star, 'Metacritic',
                      game.metacritic.toString()),
                   ],
                  const SizedBox(height: 24),

                  // Sección Idiomas
                  const Text(
                    'Idiomas Disponibles',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  const SizedBox(height: 12),
                  _buildLanguageGrid(context),
                  const SizedBox(height: 24),

                  // Enlace a la tienda
                  if (storeUrl != null && storeUrl.isNotEmpty) ...[
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.public, color: Colors.blue),
                      title: Text('Ver en ${game.tiendas.first.tienda}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      subtitle: Text(
                        storeUrl,
                        style: const TextStyle(color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _launchUrlInBrowser(context, storeUrl),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageGrid(BuildContext context) {
    // Unimos y ordenamos todos los idiomas únicos de textos y voces
    final allLanguages = {...game.idiomas.textos, ...game.idiomas.voces}.toList()..sort();

    if (allLanguages.isEmpty) {
      return const Text(
        'No se especifica información de idiomas.',
        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
      );
    }

    return Wrap(
      spacing: 12.0,
      runSpacing: 12.0,
      children: allLanguages.map((lang) {
        final hasText = game.idiomas.textos.any((l) => l.trim().toLowerCase() == lang.trim().toLowerCase());
        final hasAudio = game.idiomas.voces.any((v) => v.trim().toLowerCase() == lang.trim().toLowerCase());
        return _buildLanguageCard(context, lang, hasText, hasAudio);
      }).toList(),
    );
  }

  Widget _buildLanguageCard(BuildContext context, String language, bool hasText, bool hasAudio) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasAudio ? Colors.green.shade200 : Colors.grey.shade300,
          width: hasAudio ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ]
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            language,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey.shade800)
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasText)
                Tooltip(
                  message: 'Interfaz / Subtítulos',
                  child: Icon(Icons.article, size: 18, color: Colors.blueGrey.shade300)
                ),
              if (hasText && hasAudio) const SizedBox(width: 8),
              if (hasAudio)
                 Tooltip(
                  message: 'Voces / Audio Completo',
                  child: Icon(Icons.mic, size: 18, color: Colors.green)
                 ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }
}
