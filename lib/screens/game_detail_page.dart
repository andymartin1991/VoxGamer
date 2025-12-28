import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; 
import 'package:translator/translator.dart'; 
import 'package:share_plus/share_plus.dart'; 
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
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
                  // Slider con Videos e Imágenes
                  _GameGallerySlider(
                    images: allImages, 
                    videos: widget.game.videos,
                    heroTagPrefix: widget.game.slug,
                  ),
                  
                  // Gradiente para legibilidad (si el video no está activo)
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

                  // GÉNEROS
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
                  
                  // PLATAFORMAS
                  _buildSectionTitle(l10n.filterPlatform), 
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

                  // --- CRÉDITOS (Desarrolladores y Editores) ---
                  if (widget.game.desarrolladores.isNotEmpty || widget.game.editores.isNotEmpty) ...[
                     const SizedBox(height: 24),
                     _buildCreditsSection(context),
                  ],

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

  Widget _buildCreditsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Créditos'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
             ...widget.game.desarrolladores.map((dev) => Chip(
               avatar: const Icon(Icons.code, size: 14, color: Colors.cyanAccent),
               label: Text(dev, style: const TextStyle(fontSize: 12, color: Colors.cyanAccent)),
               backgroundColor: Colors.cyan.withOpacity(0.1),
               side: BorderSide(color: Colors.cyan.withOpacity(0.3)),
               padding: EdgeInsets.zero,
               visualDensity: VisualDensity.compact,
             )),
             ...widget.game.editores.map((pub) => Chip(
               avatar: const Icon(Icons.business, size: 14, color: Colors.purpleAccent),
               label: Text(pub, style: const TextStyle(fontSize: 12, color: Colors.purpleAccent)),
               backgroundColor: Colors.deepPurple.withOpacity(0.1),
               side: BorderSide(color: Colors.deepPurple.withOpacity(0.3)),
               padding: EdgeInsets.zero,
               visualDensity: VisualDensity.compact,
             )),
          ],
        )
      ],
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
  final List<Video> videos;
  final String heroTagPrefix;

  const _GameGallerySlider({
    required this.images,
    required this.videos,
    required this.heroTagPrefix,
  });

  @override
  State<_GameGallerySlider> createState() => _GameGallerySliderState();
}

class _GameGallerySliderState extends State<_GameGallerySlider> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final totalCount = widget.videos.length + widget.images.length;

    if (totalCount == 0) return Container(color: const Color(0xFF151921));

    return Stack(
      children: [
        PageView.builder(
          itemCount: totalCount,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          itemBuilder: (context, index) {
            
            // --- MOSTRAR VIDEO ---
            if (index < widget.videos.length) {
              final video = widget.videos[index];
              return _InAppVideoPlayer(
                key: ValueKey(video.url), // Para reciclar correctamente
                videoUrl: video.url, 
                thumbnailUrl: video.thumbnail,
              );
            }

            // --- MOSTRAR IMÁGENES ---
            final imgIndex = index - widget.videos.length;
            final imageUrl = widget.images[imgIndex];
            
            final imageWidget = CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: const Color(0xFF151921)),
              errorWidget: (_, __, ___) => Container(color: const Color(0xFF151921)),
            );

            // HERO SOLO EN LA PRIMERA IMAGEN
            if (imgIndex == 0) {
              return Hero(
                tag: 'game_img_${widget.heroTagPrefix}',
                child: imageWidget,
              );
            }
            return imageWidget;
          },
        ),
        
        // Paginador (Puntos)
        if (totalCount > 1)
          Positioned(
            bottom: 16, 
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalCount > 15 ? 15 : totalCount, (i) {
                final isActive = i == _currentIndex;
                final isVideo = i < widget.videos.length;
                
                return Container(
                  width: isActive ? 12.0 : 6.0,
                  height: 6.0,
                  margin: const EdgeInsets.symmetric(horizontal: 3.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: isVideo 
                        ? (isActive ? Colors.redAccent : Colors.redAccent.withOpacity(0.5)) 
                        : (isActive ? Colors.white : Colors.white.withOpacity(0.3)),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

class _InAppVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String thumbnailUrl;

  const _InAppVideoPlayer({super.key, required this.videoUrl, required this.thumbnailUrl});

  @override
  State<_InAppVideoPlayer> createState() => _InAppVideoPlayerState();
}

class _InAppVideoPlayerState extends State<_InAppVideoPlayer> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isPlaying = false;
  bool _isInitializing = false;
  String? _errorMessage;

  Future<void> _initializePlayer() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoController!.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(child: Text(errorMessage, style: const TextStyle(color: Colors.white)));
        },
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.redAccent,
          handleColor: Colors.red,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.white24,
        ),
      );

      if (mounted) {
        setState(() {
          _isPlaying = true;
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = "No se pudo reproducir el video";
        });
      }
      debugPrint("Error inicializando video: $e");
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isPlaying && _chewieController != null) {
      return Chewie(controller: _chewieController!);
    }

    return GestureDetector(
      onTap: _isInitializing ? null : _initializePlayer,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: widget.thumbnailUrl,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(color: Colors.black),
          ),
          Container(color: Colors.black38), // Overlay
          
          Center(
            child: _isInitializing
                ? const CircularProgressIndicator(color: Colors.redAccent)
                : Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(color: Theme.of(context).colorScheme.primary.withOpacity(0.5), blurRadius: 20, spreadRadius: 2)
                      ]
                    ),
                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
                  ),
          ),
          
          if (!_isInitializing)
            const Positioned(
              bottom: 40,
              left: 10,
              right: 10,
              child: Text(
                "VER TRAILER",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                ),
              ),
            ),
            
          if (_errorMessage != null)
             Center(child: Container(color: Colors.black54, padding: const EdgeInsets.all(8), child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))))
        ],
      ),
    );
  }
}
