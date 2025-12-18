import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'models/steam_game.dart';
import 'services/data_service.dart';
import 'screens/game_detail_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VoxGamerApp());
}

class VoxGamerApp extends StatelessWidget {
  const VoxGamerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoxGamer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
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
  String _statusMessage = 'Iniciando...';

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
        debugPrint('Filtros dinámicos cargados: ${_voiceLanguages.length} voces, ${_textLanguages.length} textos, ${_genres.length} géneros, ${_years.length} años.');
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
      _updateStatus('Comprobando datos...');
      bool needsUpdate = await _dataService.needsUpdate();

      if (needsUpdate) {
        _updateStatus('Descargando catálogo...');
        await _dataService.syncGames();
        _updateStatus('Catálogo listo.');
      } else {
        _updateStatus('Cargando biblioteca...');
      }

      await _loadFilterOptions();
      await _loadMoreGames();

    } catch (e, stackTrace) {
      _updateStatus('Error inicializando: $e');
      debugPrint('Stacktrace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), duration: const Duration(seconds: 10)),
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
      _updateStatus('Sincronizando...');
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _hardReset() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Restablecer Datos?'),
        content: const Text('Esto recargará el catálogo desde cero y actualizará los filtros.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí, Recargar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSyncing = true);
    _games.clear();

    try {
      _updateStatus('Limpiando...');
      await _dataService.clearDatabase();

      _updateStatus('Descargando datos frescos...');
      await _dataService.syncGames();
      
      await _loadFilterOptions();

      _resetAndReload();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Catálogo restablecido')),
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

      if (_games.isEmpty && _page == 1) {
        _updateStatus('No se encontraron juegos con estos filtros.');
      }

    } catch (e) {
      debugPrint("Error loading games: $e");
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                    const Text('Filtros', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
                
                    // Botones
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                tempVoice = 'Cualquiera';
                                tempText = 'Cualquiera';
                                tempYear = 'Cualquiera';
                                tempGenre = 'Cualquiera';
                              });
                            },
                            child: const Text('Limpiar'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton(
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
                            child: const Text('Aplicar'),
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
    return LayoutBuilder(builder: (context, constraints) {
      return DropdownMenu<String>(
        width: constraints.maxWidth, 
        initialSelection: items.contains(value) ? value : null,
        enableFilter: true, 
        requestFocusOnTap: true, 
        label: Text(label),
        leadingIcon: Icon(icon),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
        onSelected: onSelected,
        dropdownMenuEntries: items.map<DropdownMenuEntry<String>>((String value) {
          return DropdownMenuEntry<String>(
            value: value,
            label: value,
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
          ? const Text('Sincronizando...', style: TextStyle(fontSize: 16))
          : const Text('VoxGamer'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'sync') _forceSync();
              if (value == 'reset') _hardReset();
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem(
                  value: 'sync',
                  child: Row(children: [Icon(Icons.sync, color: Colors.blue), SizedBox(width: 8), Text('Sincronizar Rápido')]),
                ),
                const PopupMenuItem(
                  value: 'reset',
                  child: Row(children: [Icon(Icons.delete_forever, color: Colors.red), SizedBox(width: 8), Text('Restablecer Todo')]),
                ),
              ];
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar juego...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _resetAndReload();
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _isSyncing ? null : _showFilterDialog,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: !_hasActiveFilters 
                          ? Colors.white 
                          : Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.filter_list,
                      color: !_hasActiveFilters 
                          ? Colors.grey[700] 
                          : Colors.white
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

  // --- MÉTODO buildBody AÑADIDO ---
  Widget buildBody() {
    if (_isSyncing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (_games.isEmpty && !_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                _statusMessage.isNotEmpty && !_statusMessage.startsWith('Iniciando')
                  ? _statusMessage
                  : 'No se encontraron juegos.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: Colors.grey),
              ),
              if (_hasActiveFilters)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Prueba a limpiar los filtros.',
                    style: TextStyle(color: Theme.of(context).primaryColor),
                  ),
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
            color: Colors.deepPurple.shade50,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text('Filtros: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
            itemBuilder: (context, index) {
              if (index == _games.length) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final game = _games[index];
              return Card(
                margin: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: game.imgPrincipal.isNotEmpty
                      ? Image.network(
                          game.imgPrincipal,
                          width: 80,
                          height: 50,
                          fit: BoxFit.cover,
                          cacheWidth: 160, 
                          errorBuilder:
                              (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image),
                        )
                      : const Icon(Icons.videogame_asset),
                  title: Text(
                    game.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                      game.fechaLanzamiento.isNotEmpty ? game.fechaLanzamiento : 'Fecha desconocida'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            GameDetailPage(game: game),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildFilterChip(String label) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: Colors.deepPurple.shade900)),
    );
  }
}
