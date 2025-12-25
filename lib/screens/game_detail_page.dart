import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; 
import 'package:translator/translator.dart'; 
import 'package:share_plus/share_plus.dart'; 
import '../models/game.dart';

class GameDetailPage extends StatefulWidget {
  final Game game;

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
      setState(() => _showingTranslation = false);
      return;
    }
    if (_translatedText != null) {
      setState(() => _showingTranslation = true);
      return;
    }
    setState(() => _isTranslating = true);

    try {
      final locale = Localizations.localeOf(context);
      final targetLang = locale.languageCode; 
      final translation = await _translator.translate(widget.game.descripcionCorta, to: targetLang);

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al traducir.')));
      }
    }
  }

  void _shareGame() {
    // Extraer año de la fecha (YYYY-MM-DD)
    String yearParam = '';
    if (widget.game.fechaLanzamiento.length >= 4) {
      final year = widget.game.fechaLanzamiento.substring(0, 4);
      yearParam = '?year=$year';
    }

    final String deepLink = 'https://andymartin1991.github.io/VoxGamer/game/${widget.game.slug}$yearParam';
    final String message = '🎮 ${widget.game.titulo}\n\n$deepLink';
    
    Share.share(message, subject: widget.game.titulo);
  }

  Color _getScoreColor(int score) {
    if (score >= 75) return const Color(0xFF66CC33);
    if (score >= 50) return const Color(0xFFFFCC33);
    return const Color(0xFFFF0000);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

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
          // 1. HEADER EXPANDIBLE
          SliverAppBar(
            expandedHeight: 300.0,
            pinned: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              // BOTÓN COMPARTIR
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.share, size: 20, color: Colors.white),
                ),
                onPressed: _shareGame,
                tooltip: 'Compartir juego',
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16, right: 16),
              title: Text(
                widget.game.titulo,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Pasamos el slug para el Hero tag
                  _GameGallerySlider(images: allImages, heroTagPrefix: widget.game.slug),
                  
                  // Gradiente para legibilidad
                  const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black26, Colors.transparent, Colors.black87],
                          stops: [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. CONTENIDO
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // STATS ROW (Fecha, Nota, Storage)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(Icons.calendar_today, l10n.release, widget.game.fechaLanzamiento.isNotEmpty ? widget.game.fechaLanzamiento : 'N/A'),
                      if (widget.game.metacritic != null)
                        _buildStatItem(Icons.star, l10n.metascore, widget.game.metacritic.toString(), color: _getScoreColor(widget.game.metacritic!)),
                      _buildStatItem(Icons.sd_storage, l10n.storage, widget.game.storage ?? 'N/A'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 24),

                  // GÉNEROS Y PLATAFORMAS
                  _buildSectionTitle(l10n.filterGenre),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: widget.game.generos.map((g) => Chip(
                      label: Text(g, style: const TextStyle(fontSize: 12)),
                      backgroundColor: const Color(0xFF1E232F),
                      side: BorderSide.none,
                      padding: EdgeInsets.zero,
                    )).toList(),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  _buildSectionTitle(l10n.filterPlatform), // "Plataforma"
                  const SizedBox(height: 8),
                  if (widget.game.plataformas.isNotEmpty)
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: widget.game.plataformas.map((p) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: primaryColor.withOpacity(0.3)),
                        ),
                        child: Text(p, style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                      )).toList(),
                    ),

                  const SizedBox(height: 32),

                  // DESCRIPCIÓN
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle(l10n.aboutGame),
                      TextButton.icon(
                        onPressed: _isTranslating ? null : _handleTranslation,
                        icon: _isTranslating 
                            ? SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor))
                            : Icon(_showingTranslation ? Icons.undo : Icons.translate, size: 16),
                        label: Text(_showingTranslation ? l10n.viewOriginal : l10n.btnTranslate),
                      ),
                    ],
                  ),
                  Text(
                    descriptionToShow,
                    style: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFFE0E0E0)),
                  ),

                  const SizedBox(height: 32),

                  // IDIOMAS
                  _buildSectionTitle(l10n.languages),
                  const SizedBox(height: 12),
                  _buildLanguageGrid(context),

                  const SizedBox(height: 40),

                  // TIENDAS (GRID)
                  if (widget.game.tiendas.isNotEmpty) ...[
                    _buildSectionTitle(l10n.availableStores),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 3.5,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: widget.game.tiendas.length,
                      itemBuilder: (context, index) {
                        final tienda = widget.game.tiendas[index];
                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E232F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () => _launchUrlInBrowser(context, tienda.url),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.shopping_cart, size: 16),
                              const SizedBox(width: 8),
                              Expanded(child: Text(tienda.tienda, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                            ],
                          ),
                        );
                      },
                    ),
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 13, 
        fontWeight: FontWeight.w900, 
        color: Colors.grey.shade500, 
        letterSpacing: 1.1
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, {Color? color}) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.grey.shade400, size: 24),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color ?? Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
      ],
    );
  }

  Widget _buildLanguageGrid(BuildContext context) {
    final allLanguages = {...widget.game.idiomas.textos, ...widget.game.idiomas.voces}.toList()..sort();
    if (allLanguages.isEmpty) return const Text('N/A', style: TextStyle(color: Colors.grey));

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: allLanguages.map((lang) {
        final hasAudio = widget.game.idiomas.voces.any((v) => v.trim().toLowerCase() == lang.trim().toLowerCase());
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: hasAudio ? Theme.of(context).colorScheme.primary.withOpacity(0.15) : const Color(0xFF1E232F),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: hasAudio ? Theme.of(context).colorScheme.primary.withOpacity(0.5) : Colors.transparent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(lang, style: TextStyle(fontSize: 12, color: hasAudio ? Theme.of(context).colorScheme.primary : Colors.grey.shade300)),
              if (hasAudio) ...[const SizedBox(width: 4), Icon(Icons.mic, size: 10, color: Theme.of(context).colorScheme.primary)]
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _GameGallerySlider extends StatefulWidget {
  final List<String> images;
  final String heroTagPrefix; // Nuevo parámetro

  const _GameGallerySlider({required this.images, required this.heroTagPrefix});

  @override
  State<_GameGallerySlider> createState() => _GameGallerySliderState();
}

class _GameGallerySliderState extends State<_GameGallerySlider> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return Container(color: const Color(0xFF151921));

    return Stack(
      children: [
        PageView.builder(
          itemCount: widget.images.length,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          itemBuilder: (context, index) {
            final imageWidget = Image.network(
              widget.images[index],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: const Color(0xFF151921)),
            );

            // APLICAMOS HERO SOLO A LA PRIMERA IMAGEN
            if (index == 0) {
              return Hero(
                tag: 'game_img_${widget.heroTagPrefix}',
                child: imageWidget,
              );
            }
            return imageWidget;
          },
        ),
        if (widget.images.length > 1)
          Positioned(
            bottom: 40, 
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: widget.images.take(15).toList().asMap().entries.map((entry) { 
                return Container(
                  width: 6.0,
                  height: 6.0,
                  margin: const EdgeInsets.symmetric(horizontal: 3.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(_currentIndex == entry.key ? 0.9 : 0.3),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
