import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; 
import 'package:translator/translator.dart'; 
import 'package:share_plus/share_plus.dart'; 
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'dart:ui'; // Necesario para ImageFilter
import '../models/game.dart';
import '../services/data_service.dart';

class GameDetailPage extends StatefulWidget {
  final Game game;

  const GameDetailPage({super.key, required this.game});

  @override
  State<GameDetailPage> createState() => _GameDetailPageState();
}

class _GameDetailPageState extends State<GameDetailPage> {
  late Game _game;
  final DataService _dataService = DataService();
  
  String? _translatedText;
  bool _isTranslating = false;
  bool _showingTranslation = false;
  final GoogleTranslator _translator = GoogleTranslator();

  @override
  void initState() {
    super.initState();
    _game = widget.game;
    _loadFullGameDetails();
  }

  Future<void> _loadFullGameDetails() async {
    String? year;
    if (_game.fechaLanzamiento.length >= 4) {
      year = _game.fechaLanzamiento.substring(0, 4);
    }
    
    final fullGame = await _dataService.getGameBySlug(_game.slug, year: year);
    if (fullGame != null && mounted) {
      setState(() {
        _game = fullGame;
      });
    }
  }

  Future<void> _launchUrlInBrowser(BuildContext context, String url) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final Uri uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.errorGeneric}$url')),
          );
        }
      }
    } catch (e) {
      debugPrint('${l10n.errorGeneric}$e');
    }
  }

  Future<void> _handleTranslation() async {
    final l10n = AppLocalizations.of(context)!;
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
      final translation = await _translator.translate(_game.descripcionCorta, to: targetLang);

      if (mounted) {
        setState(() {
          _translatedText = translation.text;
          _showingTranslation = true;
          _isTranslating = false;
        });
      }
    } catch (e) {
      debugPrint('${l10n.errorGeneric}$e');
      if (mounted) {
        setState(() => _isTranslating = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorTranslation)));
      }
    }
  }

  void _shareGame() {
    String yearParam = '';
    if (_game.fechaLanzamiento.length >= 4) {
      final year = _game.fechaLanzamiento.substring(0, 4);
      yearParam = '?year=$year';
    }

    final String deepLink = 'https://andymartin1991.github.io/VoxGamer/game/${_game.slug}$yearParam';
    final String message = '🎮 ${_game.titulo}\n\n$deepLink';
    
    Share.share(message, subject: _game.titulo);
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
      if (_game.imgPrincipal.isNotEmpty) _game.imgPrincipal,
      ..._game.galeria
    ];

    final descriptionToShow = _showingTranslation 
        ? (_translatedText ?? _game.descripcionCorta)
        : _game.descripcionCorta;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320.0, // Un poco más alto para lucir la imagen
            pinned: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6), // Más oscuro para contraste
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1), // Borde sutil
                ),
                child: const Icon(Icons.arrow_back, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 1),
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
                _game.titulo,
                style: const TextStyle(
                  fontWeight: FontWeight.w900, // Fuente más gruesa
                  fontSize: 18,
                  shadows: [
                    Shadow(color: Colors.black, blurRadius: 15, offset: Offset(0, 2)),
                    Shadow(color: Colors.black, blurRadius: 5), // Doble sombra para legibilidad
                  ],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _GameGallerySlider(
                    images: allImages, 
                    videos: _game.videos,
                    heroTagPrefix: _game.slug,
                    onVideoTap: (url) => _launchUrlInBrowser(context, url),
                  ),
                  // Gradiente Cinematico Mejorado
                  const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black45, 
                            Colors.transparent, 
                            Colors.transparent,
                            Colors.black87,
                            Colors.black
                          ],
                          stops: [0.0, 0.3, 0.5, 0.8, 1.0],
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
                  // STATS ROW CON GLASSMORPHISM
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(Icons.calendar_today, l10n.release, _game.fechaLanzamiento.isNotEmpty ? _game.fechaLanzamiento : 'N/A'),
                        _buildVerticalDivider(),
                        if (_game.metacritic != null)
                          _buildStatItem(Icons.star, l10n.metascore, _game.metacritic.toString(), color: _getScoreColor(_game.metacritic!)),
                        if (_game.metacritic != null) _buildVerticalDivider(),
                        _buildStatItem(Icons.sd_storage, l10n.storage, _game.storage ?? 'N/A'),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),

                  _buildSectionTitle(l10n.filterGenre),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10, runSpacing: 10,
                    children: _game.generos.map((g) => _buildNeonChip(g, primaryColor)).toList(),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  _buildSectionTitle(l10n.filterPlatform), 
                  const SizedBox(height: 12),
                  if (_game.plataformas.isNotEmpty)
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _game.plataformas.map((p) => _buildPlatformChip(p)).toList(),
                    ),

                  if (_game.desarrolladores.isNotEmpty || _game.editores.isNotEmpty) ...[
                     const SizedBox(height: 24),
                     _buildCreditsSection(context),
                  ],

                  const SizedBox(height: 32),

                  // SECCIÓN DESCRIPCIÓN
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E232F).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildSectionTitle(l10n.aboutGame),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                backgroundColor: primaryColor.withOpacity(0.1),
                                foregroundColor: primaryColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                              onPressed: _isTranslating ? null : _handleTranslation,
                              icon: _isTranslating 
                                  ? SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor))
                                  : Icon(_showingTranslation ? Icons.undo : Icons.translate, size: 16),
                              label: Text(_showingTranslation ? l10n.viewOriginal : l10n.btnTranslate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            descriptionToShow.isNotEmpty ? descriptionToShow : "Sin descripción disponible.", 
                            key: ValueKey(descriptionToShow),
                            style: TextStyle(fontSize: 15, height: 1.6, color: Colors.grey.shade300),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  _buildSectionTitle(l10n.languages),
                  const SizedBox(height: 12),
                  _buildLanguageGrid(context),

                  const SizedBox(height: 40),

                  if (_game.tiendas.isNotEmpty) ...[
                    _buildSectionTitle(l10n.availableStores),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 3.2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _game.tiendas.length,
                      itemBuilder: (context, index) {
                        final tienda = _game.tiendas[index];
                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E232F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.white.withOpacity(0.1))
                            ),
                            elevation: 4,
                            shadowColor: Colors.black45,
                          ),
                          onPressed: () => _launchUrlInBrowser(context, tienda.url),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.shopping_cart, size: 18, color: Colors.grey),
                              const SizedBox(width: 10),
                              Expanded(child: Text(tienda.tienda, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                              const Icon(Icons.open_in_new, size: 14, color: Colors.grey),
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

  Widget _buildVerticalDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.white.withOpacity(0.1),
    );
  }

  // CHIP NEON CON ESTILO CYBERPUNK
  Widget _buildNeonChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 8,
            spreadRadius: 0,
          )
        ],
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color.withOpacity(0.9), 
          fontSize: 11, 
          fontWeight: FontWeight.bold, 
          letterSpacing: 0.5
        ),
      ),
    );
  }

  Widget _buildPlatformChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2E3B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildCreditsSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(l10n.credits),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
             ..._game.desarrolladores.map((dev) => Chip(
               avatar: const CircleAvatar(backgroundColor: Colors.transparent, child: Icon(Icons.code, size: 14, color: Colors.cyanAccent)),
               label: Text(dev, style: const TextStyle(fontSize: 12, color: Colors.cyanAccent)),
               backgroundColor: const Color(0xFF1A2733),
               shape: const StadiumBorder(side: BorderSide(color: Colors.cyanAccent, width: 0.5)),
               padding: const EdgeInsets.symmetric(horizontal: 4),
               visualDensity: VisualDensity.compact,
             )),
             ..._game.editores.map((pub) => Chip(
               avatar: const CircleAvatar(backgroundColor: Colors.transparent, child: Icon(Icons.business, size: 14, color: Colors.purpleAccent)),
               label: Text(pub, style: const TextStyle(fontSize: 12, color: Colors.purpleAccent)),
               backgroundColor: const Color(0xFF251A33),
               shape: const StadiumBorder(side: BorderSide(color: Colors.purpleAccent, width: 0.5)),
               padding: const EdgeInsets.symmetric(horizontal: 4),
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
        fontSize: 12, 
        fontWeight: FontWeight.w900, 
        color: Colors.grey.shade500, 
        letterSpacing: 1.5 // Más espaciado para toque premium
      ),
    );
  }

  // STAT ITEM AHORA ES MÁS LIMPIO Y GRANDE
  Widget _buildStatItem(IconData icon, String label, String value, {Color? color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color ?? Colors.grey.shade400, size: 20),
        const SizedBox(height: 6),
        Text(
          value, 
          style: TextStyle(
            color: color ?? Colors.white, 
            fontWeight: FontWeight.bold, 
            fontSize: 15,
            shadows: color != null ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 8)] : null
          )
        ),
        const SizedBox(height: 2),
        Text(label.toUpperCase(), style: TextStyle(color: Colors.grey.shade600, fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildLanguageGrid(BuildContext context) {
    final allLanguages = {..._game.idiomas.textos, ..._game.idiomas.voces}.toList()..sort();
    if (allLanguages.isEmpty) return const Text('N/A', style: TextStyle(color: Colors.grey));

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: allLanguages.map((lang) {
        final hasAudio = _game.idiomas.voces.any((v) => v.trim().toLowerCase() == lang.trim().toLowerCase());
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: hasAudio ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : const Color(0xFF1E232F),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: hasAudio ? Theme.of(context).colorScheme.primary.withOpacity(0.3) : Colors.white10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(lang, style: TextStyle(fontSize: 12, fontWeight: hasAudio ? FontWeight.bold : FontWeight.normal, color: hasAudio ? Theme.of(context).colorScheme.primary : Colors.grey.shade400)),
              if (hasAudio) ...[const SizedBox(width: 6), Icon(Icons.mic, size: 12, color: Theme.of(context).colorScheme.primary)]
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
  final Function(String) onVideoTap;

  const _GameGallerySlider({
    required this.images,
    required this.videos,
    required this.heroTagPrefix,
    required this.onVideoTap,
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
            
            // --- Lógica para mostrar VIDEOS primero ---
            if (index < widget.videos.length) {
              final video = widget.videos[index];
              return _InAppVideoPlayer(
                key: ValueKey(video.url), 
                videoUrl: video.url, 
                thumbnailUrl: video.thumbnail,
              );
            }

            // --- Lógica para mostrar IMÁGENES ---
            final imgIndex = index - widget.videos.length;
            final imageUrl = widget.images[imgIndex];
            
            final imageWidget = CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: const Color(0xFF151921)),
              errorWidget: (_, __, ___) => Container(color: const Color(0xFF151921)),
            );

            if (imgIndex == 0) {
              return Hero(
                tag: 'game_img_${widget.heroTagPrefix}',
                child: imageWidget,
              );
            }
            return imageWidget;
          },
        ),
        
        if (totalCount > 1)
          Positioned(
            bottom: 30, // Subido un poco para no chocar con el gradiente oscuro
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalCount > 15 ? 15 : totalCount, (i) {
                final isActive = i == _currentIndex;
                final isVideo = i < widget.videos.length;
                
                return AnimatedContainer( // ANIMACIÓN DE PUNTOS
                  duration: const Duration(milliseconds: 300),
                  width: isActive ? 24.0 : 6.0,
                  height: 6.0,
                  margin: const EdgeInsets.symmetric(horizontal: 3.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: isVideo 
                        ? (isActive ? Colors.redAccent : Colors.redAccent.withOpacity(0.5)) 
                        : (isActive ? Colors.white : Colors.white.withOpacity(0.3)),
                    boxShadow: isActive ? [BoxShadow(color: (isVideo ? Colors.redAccent : Colors.white).withOpacity(0.5), blurRadius: 8)] : null,
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
    final l10n = AppLocalizations.of(context)!;
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
          Container(color: Colors.black38), 
          
          Center(
            child: _isInitializing
                ? const CircularProgressIndicator(color: Colors.redAccent)
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      // Sombra (hack para que se vea fuera del clip)
                      Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Theme.of(context).colorScheme.primary.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)
                          ],
                        ),
                      ),
                      // Efecto cristal
                      ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white54, width: 1.5),
                            ),
                            child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          
          if (!_isInitializing)
            Positioned(
              bottom: 60, // Subido para no chocar con indicador
              left: 10,
              right: 10,
              child: Text(
                l10n.viewTrailer,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  fontSize: 12,
                  shadows: [Shadow(color: Colors.black, blurRadius: 10)],
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
