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
  
  // Estado del Filtro
  String _selectedVoiceLanguage = 'Cualquiera';
  final List<String> _voiceLanguages = [
    'Cualquiera',
    'English',
    'Spanish',
    'Japanese',
    'French',
    'German',
    'Italian',
    'Russian',
    'Portuguese'
  ];

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

  Future<void> _checkAndLoadInitialData() async {
    await Future.delayed(Duration.zero);
    
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
        content: const Text('Esto recargará el catálogo desde cero.'),
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
        voiceLanguage: _selectedVoiceLanguage, // Pasamos el filtro
      );

      setState(() {
        _page++;
        _games.addAll(newGames);
        if (newGames.length < _limit) {
          _hasMore = false;
        }
      });
      
      if (_games.isEmpty && _page == 1) {
        _updateStatus('No se encontraron juegos con estos filtros.');
      }

    } catch (e) {
      debugPrint("Error loading games: $e");
      _updateStatus('Error cargando lista: $e');
    } finally {
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
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filtrar por Voces', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: _voiceLanguages.map((lang) {
                  return ChoiceChip(
                    label: Text(lang),
                    selected: _selectedVoiceLanguage == lang,
                    onSelected: (selected) {
                      setState(() {
                        _selectedVoiceLanguage = lang;
                      });
                      Navigator.pop(context);
                      _resetAndReload(); // Recargar al aplicar filtro
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Título modificado
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
                // Botón de Filtro
                InkWell(
                  onTap: _isSyncing ? null : _showFilterDialog,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _selectedVoiceLanguage == 'Cualquiera' 
                          ? Colors.white 
                          : Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.filter_list, 
                      color: _selectedVoiceLanguage == 'Cualquiera' 
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
              if (_selectedVoiceLanguage != 'Cualquiera')
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Filtro activo: $_selectedVoiceLanguage',
                    style: const TextStyle(color: Colors.deepPurple),
                  ),
                )
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (_selectedVoiceLanguage != 'Cualquiera')
          Container(
            width: double.infinity,
            color: Colors.deepPurple.shade50,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            child: Text(
              'Mostrando juegos con voces en: $_selectedVoiceLanguage',
              style: TextStyle(fontSize: 12, color: Colors.deepPurple.shade800),
              textAlign: TextAlign.center,
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
                  leading: game.headerImage != null
                      ? Image.network(
                          game.headerImage!,
                          width: 80,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image),
                        )
                      : const Icon(Icons.videogame_asset),
                  title: Text(
                    game.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                      game.releaseDate ?? 'Fecha desconocida'),
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
}
