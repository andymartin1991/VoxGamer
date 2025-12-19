import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; 
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
            SnackBar(content: Text('Error: $url')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300.0,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                game.titulo,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  game.imgPrincipal.isNotEmpty
                      ? Image.network(
                          game.imgPrincipal,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(color: const Color(0xFF151921)),
                        )
                      : Container(color: const Color(0xFF151921)),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xCC0A0E14)],
                        stops: [0.6, 1.0]
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildBadge(Icons.calendar_today, game.fechaLanzamiento.isNotEmpty ? game.fechaLanzamiento.substring(0, 4) : 'N/A'),
                      const SizedBox(width: 12),
                      if (game.metacritic != null)
                        _buildBadge(Icons.star, '${l10n.metascore}: ${game.metacritic}', color: primaryColor),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Text(
                    l10n.aboutGame,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    game.descripcionCorta,
                    style: const TextStyle(fontSize: 16, height: 1.5, color: Color(0xFFEDEDED)),
                  ),
                  const SizedBox(height: 32),

                  _buildInfoSection(context, l10n),
                  const SizedBox(height: 32),

                  Text(
                    l10n.languages,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 12),
                  _buildLanguageGrid(context),
                  const SizedBox(height: 40),

                  if (game.tiendas.isNotEmpty) ...[
                     Text(
                      'TIENDAS DISPONIBLES',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 16),
                    ...game.tiendas.map((tienda) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.shopping_cart),
                          label: Text('${l10n.viewIn} ${tienda.tienda}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E232F),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: primaryColor.withOpacity(0.5))
                            ),
                            elevation: 0,
                          ),
                          onPressed: () => _launchUrlInBrowser(context, tienda.url),
                        ),
                      ),
                    )).toList(),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E232F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color?.withOpacity(0.3) ?? Colors.grey.shade800),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? Colors.grey.shade400),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color ?? Colors.grey.shade300, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151921),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade900),
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.sd_storage, l10n.storage, game.storage ?? 'N/A'),
          const Divider(color: Color(0xFF1E232F), height: 24),
          _buildInfoRow(Icons.category, l10n.filterGenre, game.generos.join(', ')),
          const Divider(color: Color(0xFF1E232F), height: 24),
          _buildInfoRow(Icons.gamepad, 'Plataformas', game.plataformas.isNotEmpty ? game.plataformas.join(', ') : 'N/A'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageGrid(BuildContext context) {
    final allLanguages = {...game.idiomas.textos, ...game.idiomas.voces}.toList()..sort();

    if (allLanguages.isEmpty) {
      return const Text('N/A', style: TextStyle(color: Colors.grey));
    }

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: allLanguages.map((lang) {
        final hasAudio = game.idiomas.voces.any((v) => v.trim().toLowerCase() == lang.trim().toLowerCase());
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: hasAudio ? Theme.of(context).colorScheme.primary.withOpacity(0.15) : const Color(0xFF1E232F),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasAudio ? Theme.of(context).colorScheme.primary.withOpacity(0.5) : Colors.transparent
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                lang,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: hasAudio ? FontWeight.bold : FontWeight.normal,
                  color: hasAudio ? Theme.of(context).colorScheme.primary : Colors.grey.shade300
                ),
              ),
              if (hasAudio) ...[
                const SizedBox(width: 4),
                Icon(Icons.mic, size: 12, color: Theme.of(context).colorScheme.primary)
              ]
            ],
          ),
        );
      }).toList(),
    );
  }
}
