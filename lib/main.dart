import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'models/steam_game.dart';
import 'services/data_service.dart';
import 'screens/game_detail_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Configurar estilo de barra de sistema para que coincida con el tema oscuro
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Color(0xFF0A0E14),
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const VoxGamerApp());
}

class VoxGamerApp extends StatelessWidget {
  const VoxGamerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Definición de Colores "Digital Arcade"
    const bgDark = Color(0xFF0A0E14); // Casi negro, evita smearing
    const cardBg = Color(0xFF151921); // Un poco más claro para superficie
    const primaryNeon = Color(0xFF7C4DFF); // Violeta Neón Brillante
    const secondaryNeon = Color(0xFF03DAC6); // Cian secundario
    
    return MaterialApp(
      title: 'VoxGamer',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark, // Forzamos modo oscuro
      
      // TEMA OSCURO PERSONALIZADO
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgDark,
        useMaterial3: true,
        
        colorScheme: const ColorScheme.dark(
          primary: primaryNeon,
          secondary: secondaryNeon,
          surface: cardBg,
          background: bgDark,
          onSurface: Color(0xFFEDEDED), // Texto blanco hueso
        ),

        // Tipografía "Outfit"
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).apply(
          bodyColor: const Color(0xFFEDEDED),
          displayColor: Colors.white,
        ),

        // Estilo de App Bar
        appBarTheme: const AppBarTheme(
          backgroundColor: bgDark,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          iconTheme: IconThemeData(color: Colors.white),
        ),

        // Estilo de Cards
        cardTheme: CardTheme(
          color: cardBg,
          elevation: 8,
          shadowColor: primaryNeon.withOpacity(0.3), // Glow sutil por defecto
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),

        // Estilo de Inputs (Buscador y Dropdowns)
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E232F),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIconColor: Colors.grey,
        ),
      ),
      
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DataService _dataService = DataService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  final List<SteamGame> _games = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  String _statusMessage = 'Iniciando sistema...';

  bool _hasMore = true;
  int _page = 0;
  final int _limit = 20;
  String _searchQuery = '';

  // --- ESTADOS DE FILTROS ---
  String _selectedVoiceLanguage = 'Cualquiera';
  String _selectedTextLanguage = 'Cualquiera';
  String _selectedYear = 'Cualquiera';
  String _selectedGenre = 'Cualquiera';

  // Listas de Opciones (DINÁMICAS)
  List<String> _voiceLanguages = ['Cualquiera'];
  List<String> _textLanguages = ['Cualquiera'];
  List<String> _genres = ['Cualquiera'];
  List<String> _years = ['Cualquiera'];

  @override
  void initState() {
    super.initState();
    _checkAndLoadInitialData();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _resetAndReload();
    });
  }

  void _resetAndReload() {
    setState(() {
      _searchQuery = _searchController.text;
      _page = 0;
      _games.clear();
      _hasMore = true;
    });
    _loadMoreGames();
  }

  void _updateStatus(String msg) {
    if (mounted) setState(() => _statusMessage = msg);
    debugPrint(msg);
  }

  Future<void> _loadFilterOptions() async {
    try {
      final options = await _dataService.getFilterOptions();
      if (options.isNotEmpty && mounted) {
        setState(() {
          if (options.containsKey('voices')) {
            _voiceLanguages = ['Cualquiera', ...options['voices']!];
          }
          if (options.containsKey('texts')) {
            _textLanguages = ['Cualquiera', ...options['texts']!];
          }
          if (options.containsKey('genres')) {
            _genres = ['Cualquiera', ...options['genres']!];
          }
          if (options.containsKey('years')) {
            _years = ['Cualquiera', ...options['years']!];
          }
        });
      }
    } catch (e) {
      debugPrint('Error cargando filtros dinámicos: $e');
    }
  }

  Future<void> _checkAndLoadInitialData() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    setState(() => _isSyncing = true);

    try {
      _updateStatus('Conectando al Nexo...');
      bool needsUpdate = await _dataService.needsUpdate();

      if (needsUpdate) {
        _updateStatus('Sincronizando catálogo masivo...');
        await _dataService.syncGames();
        _updateStatus('Catálogo listo.');
      } else {
        _updateStatus('Cargando biblioteca local...');
      }

      await _loadFilterOptions();
      await _loadMoreGames();

    } catch (e, stackTrace) {
      _updateStatus('Error de inicialización: $e');
      debugPrint('Stacktrace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _forceSync() async {
    setState(() => _isSyncing = true);
    _games.clear();
    try {
      _updateStatus('Forzando resincronización...');
      await _dataService.syncGames();
      await _loadFilterOptions();
      _resetAndReload();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sincronización completada')),
        );
      }
    } catch (e) {
      _updateStatus('Error al actualizar: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _hardReset() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Reiniciar Sistema?'),
        content: const Text('Esto purgará la base de datos local y descargará el catálogo completo nuevamente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Purgar y Recargar', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSyncing = true);
    _games.clear();

    try {
      _updateStatus('Limpiando sectores de memoria...');
      await _dataService.clearDatabase();

      _updateStatus('Descargando flujo de datos...');
      await _dataService.syncGames();
      
      await _loadFilterOptions();

      _resetAndReload();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sistema restablecido')),
        );
      }
    } catch (e) {
      _updateStatus('Error fatal: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _loadMoreGames() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final newGames = await _dataService.getLocalGames(
        limit: _limit,
        offset: _page * _limit,
        query: _searchQuery.isNotEmpty ? _searchQuery : null,
        voiceLanguage: _selectedVoiceLanguage,
        textLanguage: _selectedTextLanguage,
        year: _selectedYear,
        genre: _selectedGenre,
      );

      if (!mounted) return;

      setState(() {
        _page++;
        _games.addAll(newGames);
        if (newGames.length < _limit) {
          _hasMore = false;
        }
        _isLoading = false;
      });

    } catch (e) {
      _updateStatus('Error cargando lista: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreGames();
    }
  }

  void _showFilterDialog() {
    String tempVoice = _selectedVoiceLanguage;
    String tempText = _selectedTextLanguage;
    String tempYear = _selectedYear;
    String tempGenre = _selectedGenre;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: const Color(0xFF151921), // Fondo oscuro para el modal
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder( 
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView( 
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Configurar Filtros', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
                      ],
                    ),
                    const SizedBox(height: 24),
                
                    _buildSearchableDropdown(
                      label: 'Idioma (Voces)',
                      value: tempVoice,
                      items: _voiceLanguages,
                      icon: Icons.mic,
                      onSelected: (val) => setModalState(() => tempVoice = val ?? 'Cualquiera'),
                    ),
                    const SizedBox(height: 16),
                
                    _buildSearchableDropdown(
                      label: 'Idioma (Texto/Subt)',
                      value: tempText,
                      items: _textLanguages,
                      icon: Icons.subtitles,
                      onSelected: (val) => setModalState(() => tempText = val ?? 'Cualquiera'),
                    ),
                    const SizedBox(height: 16),
                
                    _buildSearchableDropdown(
                      label: 'Género',
                      value: tempGenre,
                      items: _genres,
                      icon: Icons.category,
                      onSelected: (val) => setModalState(() => tempGenre = val ?? 'Cualquiera'),
                    ),
                    const SizedBox(height: 16),
                
                    _buildSearchableDropdown(
                      label: 'Año de Lanzamiento',
                      value: tempYear,
                      items: _years,
                      icon: Icons.calendar_today,
                      onSelected: (val) => setModalState(() => tempYear = val ?? 'Cualquiera'),
                    ),
                    
                    const SizedBox(height: 32),
                
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade700),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: () {
                              setModalState(() {
                                tempVoice = 'Cualquiera';
                                tempText = 'Cualquiera';
                                tempYear = 'Cualquiera';
                                tempGenre = 'Cualquiera';
                              });
                            },
                            child: const Text('Limpiar', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedVoiceLanguage = tempVoice;
                                _selectedTextLanguage = tempText;
                                _selectedYear = tempYear;
                                _selectedGenre = tempGenre;
                              });
                              Navigator.pop(context);
                              _resetAndReload();
                            },
                            child: const Text('Aplicar Filtros', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchableDropdown({
    required String label, 
    required String value, 
    required List<String> items, 
    required IconData icon,
    required Function(String?) onSelected
  }) {
    if (items.isEmpty) {
      return TextField(
        enabled: false,
        decoration: InputDecoration(
          labelText: '$label (Sin datos)',
          prefixIcon: Icon(icon),
        ),
      );
    }

    final uniqueItems = items.toSet().toList();
    final safeValue = uniqueItems.contains(value) ? value : 'Cualquiera';
    final isCualquiera = safeValue == 'Cualquiera';

    final TextEditingController controller = TextEditingController(
      text: isCualquiera ? '' : safeValue
    );

    return LayoutBuilder(builder: (context, constraints) {
      return DropdownMenu<String>(
        width: constraints.maxWidth,
        controller: controller,
        initialSelection: isCualquiera ? null : safeValue,
        enableFilter: true,
        requestFocusOnTap: true,
        label: Text(label),
        hintText: 'Cualquiera',
        leadingIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
        menuHeight: 300,
        
        textStyle: const TextStyle(color: Colors.white),
        
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: const Color(0xFF1E232F),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),

        trailingIcon: !isCualquiera
            ? IconButton(
                icon: const Icon(Icons.clear, size: 20, color: Colors.grey),
                onPressed: () {
                  controller.clear();
                  onSelected('Cualquiera');
                },
              )
            : null,
            
        onSelected: (String? newVal) {
          onSelected(newVal ?? 'Cualquiera');
        },
        
        dropdownMenuEntries: uniqueItems.map<DropdownMenuEntry<String>>((String itemValue) {
          return DropdownMenuEntry<String>(
            value: itemValue,
            label: itemValue,
            style: ButtonStyle(
              foregroundColor: MaterialStateProperty.all(Colors.white),
              textStyle: MaterialStateProperty.all(const TextStyle(fontWeight: FontWeight.w500)),
            )
          );
        }).toList(),
      );
    });
  }

  bool get _hasActiveFilters => 
    _selectedVoiceLanguage != 'Cualquiera' || 
    _selectedTextLanguage != 'Cualquiera' ||
    _selectedYear != 'Cualquiera' || 
    _selectedGenre != 'Cualquiera';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSyncing
          ? Text(_statusMessage, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal))
          : const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.gamepad, color: Color(0xFF7C4DFF)),
                SizedBox(width: 8),
                Text('VoxGamer'),
              ],
            ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'sync') _forceSync();
              if (value == 'reset') _hardReset();
            },
            color: const Color(0xFF1E232F),
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem(
                  value: 'sync',
                  child: Row(children: [Icon(Icons.sync, color: Colors.blueAccent), SizedBox(width: 8), Text('Sincronizar Rápido', style: TextStyle(color: Colors.white))]),
                ),
                const PopupMenuItem(
                  value: 'reset',
                  child: Row(children: [Icon(Icons.delete_forever, color: Colors.redAccent), SizedBox(width: 8), Text('Resetear Todo', style: TextStyle(color: Colors.white))]),
                ),
              ];
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ]
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Buscar juego...',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF7C4DFF)),
                        fillColor: const Color(0xFF1E232F),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.grey),
                                onPressed: () {
                                  _searchController.clear();
                                  _resetAndReload();
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: _isSyncing ? null : _showFilterDialog,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _hasActiveFilters 
                          ? Theme.of(context).colorScheme.primary 
                          : const Color(0xFF1E232F),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _hasActiveFilters ? Colors.transparent : Colors.grey.shade800,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _hasActiveFilters 
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.4)
                            : Colors.transparent,
                          blurRadius: 10,
                          spreadRadius: 1
                        )
                      ]
                    ),
                    child: Icon(
                      Icons.tune, // Icono más moderno para filtros
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: buildBody(),
    );
  }

  // --- COMPONENTES UI MEJORADOS ---

  Widget buildBody() {
    if (_isSyncing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildShimmerLoading(rows: 3), // Efecto Shimmer
              const SizedBox(height: 24),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_games.isEmpty && !_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videogame_asset_off, size: 80, color: Colors.grey.shade800),
              const SizedBox(height: 24),
              Text(
                'No se encontraron señales.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, color: Colors.grey.shade400, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_hasActiveFilters)
                Text(
                  'Intenta ajustar los filtros del nexo.',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary),
                )
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (_hasActiveFilters)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text('Filtros Activos: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                  if (_selectedVoiceLanguage != 'Cualquiera')
                    _buildFilterChip('Voces: $_selectedVoiceLanguage'),
                  if (_selectedTextLanguage != 'Cualquiera')
                    _buildFilterChip('Texto: $_selectedTextLanguage'),
                  if (_selectedGenre != 'Cualquiera')
                    _buildFilterChip('Género: $_selectedGenre'),
                  if (_selectedYear != 'Cualquiera')
                    _buildFilterChip('Año: $_selectedYear'),
                ],
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: _games.length + (_hasMore ? 1 : 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemBuilder: (context, index) {
              if (index == _games.length) {
                return _buildShimmerLoading(rows: 1); // Shimmer al final
              }

              final game = _games[index];
              return _buildGameCard(game);
            },
          ),
        ),
      ],
    );
  }

  // Tarjeta de Juego Estilo "Digital Arcade"
  Widget _buildGameCard(SteamGame game) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          // Glow sutil si lo deseamos, pero puede ser costoso en rendimiento en listas largas
        ]
      ),
      child: Card(
        // El tema ya define el color y shape, pero aseguramos
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => GameDetailPage(game: game)),
            );
          },
          child: Row(
            children: [
              // Imagen Izquierda (Grande)
              SizedBox(
                width: 120,
                height: 90,
                child: game.imgPrincipal.isNotEmpty
                    ? Image.network(
                        game.imgPrincipal,
                        fit: BoxFit.cover,
                        cacheWidth: 240, // Optimización memoria
                        errorBuilder: (context, error, stackTrace) =>
                            Container(color: const Color(0xFF1E232F), child: const Icon(Icons.broken_image, color: Colors.grey)),
                      )
                    : Container(color: const Color(0xFF1E232F), child: const Icon(Icons.videogame_asset, color: Colors.grey)),
              ),
              
              // Información Derecha
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        game.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            game.fechaLanzamiento.isNotEmpty ? game.fechaLanzamiento.substring(0, 4) : 'N/A',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                          ),
                          const SizedBox(width: 12),
                          if (game.metacritic != null) ...[
                            Icon(Icons.star, size: 12, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              game.metacritic.toString(),
                              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                            ),
                          ]
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 12.0),
                child: Icon(Icons.chevron_right, color: Colors.grey),
              )
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildFilterChip(String label) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        // Gradiente Neon
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
            Theme.of(context).colorScheme.secondary.withOpacity(0.6),
          ]
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
            blurRadius: 6,
          )
        ]
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  // Efecto de carga moderno (Skeleton)
  Widget _buildShimmerLoading({required int rows}) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1E232F),
      highlightColor: const Color(0xFF2A3040),
      child: Column(
        children: List.generate(rows, (index) => Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 120,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16)
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: double.infinity, height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 8),
                    Container(width: 100, height: 12, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              )
            ],
          ),
        )),
      ),
    );
  }
}
