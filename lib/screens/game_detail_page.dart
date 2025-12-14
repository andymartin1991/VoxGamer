import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/steam_game.dart';

class GameDetailPage extends StatelessWidget {
  final SteamGame game;

  const GameDetailPage({super.key, required this.game});

  Future<void> _launchSteamUrl(BuildContext context, String url) async {
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
        String msg = 'Error al abrir el navegador.';
        if (e.toString().contains('channel-error') || e.toString().contains('Channel')) {
          msg = 'Error de configuración. Por favor, desinstala y reinstala la app.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(game.title, overflow: TextOverflow.ellipsis),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen de cabecera
            if (game.headerImage != null)
              Image.network(
                game.headerImage!,
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
                    game.title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),

                  // Información Grid
                  _buildInfoRow(context, Icons.calendar_today, 'Lanzamiento',
                      game.releaseDate ?? 'N/A'),
                  const SizedBox(height: 12),
                  _buildInfoRow(context, Icons.sd_storage, 'Tamaño',
                      game.size ?? 'N/A'),
                  const SizedBox(height: 24),

                  // Sección Idiomas (Diseño Grid con Iconos)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Idiomas Disponibles',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      // Debug visual para verificar datos
                      if (game.voices.isNotEmpty)
                        const Icon(Icons.check_circle, size: 16, color: Colors.green)
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),

                  _buildLanguageGrid(context),

                  const SizedBox(height: 24),
                  
                  // Enlace a Steam
                   if (game.steamUrl != null) ...[
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.public, color: Colors.blue),
                      title: const Text('Ver en Steam Store', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      subtitle: Text(
                        game.steamUrl!,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      onTap: () => _launchSteamUrl(context, game.steamUrl!), 
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
    // Unimos y ordenamos todos los idiomas únicos
    final allLanguages = {...game.languages, ...game.voices}.toList()..sort();
    
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
        // Lógica de coincidencia robusta (ignora mayúsculas y espacios)
        final hasText = game.languages.any((l) => l.trim().toLowerCase() == lang.trim().toLowerCase());
        final hasAudio = game.voices.any((v) => v.trim().toLowerCase() == lang.trim().toLowerCase());
        
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
          // Borde verde si tiene audio (más premium), gris si solo texto
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
          // Nombre del idioma
          Text(
            language, 
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: 14,
              color: Colors.grey.shade800
            )
          ),
          const SizedBox(height: 6),
          
          // Fila de Iconos
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono Texto
              if (hasText) ...[
                Tooltip(
                  message: 'Interfaz / Subtítulos',
                  child: Icon(Icons.article, size: 18, color: Colors.blueGrey.shade300)
                ),
              ],
              
              if (hasText && hasAudio)
                const SizedBox(width: 8),

              // Icono Audio
              if (hasAudio) ...[
                 Tooltip(
                  message: 'Voces / Audio Completo',
                  child: Icon(Icons.mic, size: 18, color: Colors.green)
                 ),
              ],
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
