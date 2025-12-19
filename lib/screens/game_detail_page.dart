import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; 
import 'package:translator/translator.dart'; 
import '../models/steam_game.dart';

class GameDetailPage extends StatefulWidget {
  final SteamGame game;

  const GameDetailPage({super.key, required this.game});

  @override
  State<GameDetailPage> createState() => _GameDetailPageState();
}

class _GameDetailPageState extends State<GameDetailPage> {
  String? _translatedText;
  bool _isTranslating = false;
  bool _showingTranslation = false;
  final GoogleTranslator _translator = GoogleTranslator();

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

  Future<void> _handleTranslation() async {
    if (_showingTranslation) {
      setState(() {
        _showingTranslation = false;
      });
      return;
    }

    if (_translatedText != null) {
      setState(() {
        _showingTranslation = true;
      });
      return;
    }

    setState(() => _isTranslating = true);

    try {
      final locale = Localizations.localeOf(context);
      final targetLang = locale.languageCode; 

      final translation = await _translator.translate(
        widget.game.descripcionCorta, 
        to: targetLang
      );

      if (mounted) {
        setState(() {
          _translatedText = translation.text;
          _showingTranslation = true;
          _isTranslating = false;
        });
      }
    } catch (e) {
      debugPrint('Error de traducción: $e');
      if (mounted) {
        setState(() => _isTranslating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al traducir. Verifica tu conexión.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    final List<String> allImages = [
      if (widget.game.imgPrincipal.isNotEmpty) widget.game.imgPrincipal,
      ...widget.game.galeria
    ];

    final descriptionToShow = _showingTranslation 
        ? (_translatedText ?? widget.game.descripcionCorta)
        : widget.game.descripcionCorta;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300.0,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.game.titulo,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  allImages.isNotEmpty
                      ? PageView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: allImages.length,
                          itemBuilder: (context, index) {
                            return Image.network(
                              allImages[index],
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / 
                                          loadingProgress.expectedTotalBytes!
                                        : null,
                                    color: primaryColor,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: const Color(0xFF151921),
                                    child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                                  ),
                            );
                          },
                        )
                      : Container(color: const Color(0xFF151921)),
                  
                  const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xCC0A0E14)],
                          stops: [0.6, 1.0]
                        ),
                      ),
                    ),
                  ),
                  
                  if (allImages.length > 1)
                    Positioned(
                      right: 16,
                      bottom: 16 + MediaQuery.of(context).padding.bottom, 
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12)
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.photo_library, color: Colors.white70, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${allImages.length}',
                                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
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
                      _buildBadge(Icons.calendar_today, widget.game.fechaLanzamiento.isNotEmpty ? widget.game.fechaLanzamiento.substring(0, 4) : 'N/A'),
                      const SizedBox(width: 12),
                      if (widget.game.metacritic != null)
                        _buildBadge(Icons.star, '${l10n.metascore}: ${widget.game.metacritic}', color: primaryColor),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.aboutGame,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.2),
                      ),
                      
                      TextButton.icon(
                        onPressed: _isTranslating ? null : _handleTranslation,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: _showingTranslation ? secondaryColor : primaryColor, 
                        ),
                        icon: _isTranslating 
                            ? SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor))
                            : Icon(_showingTranslation ? Icons.translate : Icons.translate_outlined, size: 16),
                        label: Text(
                          _showingTranslation ? 'Ver Original' : l10n.btnTranslate, 
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      descriptionToShow,
                      key: ValueKey<bool>(_showingTranslation), 
                      style: const TextStyle(fontSize: 16, height: 1.5, color: Color(0xFFEDEDED)),
                    ),
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

                  if (widget.game.tiendas.isNotEmpty) ...[
                     Text(
                      'TIENDAS DISPONIBLES',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 16),
                    ...widget.game.tiendas.map((tienda) => Padding(
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
          _buildInfoRow(Icons.sd_storage, l10n.storage, widget.game.storage ?? 'N/A'),
          const Divider(color: Color(0xFF1E232F), height: 24),
          _buildInfoRow(Icons.category, l10n.filterGenre, widget.game.generos.join(', ')),
          const Divider(color: Color(0xFF1E232F), height: 24),
          _buildInfoRow(Icons.gamepad, 'Plataformas', widget.game.plataformas.isNotEmpty ? widget.game.plataformas.join(', ') : 'N/A'),
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
    final allLanguages = {...widget.game.idiomas.textos, ...widget.game.idiomas.voces}.toList()..sort();

    if (allLanguages.isEmpty) {
      return const Text('N/A', style: TextStyle(color: Colors.grey));
    }

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: allLanguages.map((lang) {
        final hasAudio = widget.game.idiomas.voces.any((v) => v.trim().toLowerCase() == lang.trim().toLowerCase());
        
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
