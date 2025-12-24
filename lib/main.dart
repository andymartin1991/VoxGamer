import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:io'; 
import 'dart:ui'; // Necesario para ImageFilter
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'models/game.dart';
import 'services/data_service.dart';
import 'services/database_helper.dart'; 
import 'services/background_service.dart';
import 'screens/game_detail_page.dart';
import 'widgets/minigame_overlay.dart'; 

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings();
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
  );
  
  // Inicialización de notificaciones
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  if (!kIsWeb) {
    try {
      // Intentamos inicializar el servicio con un timeout para evitar que la app se quede pegada en el logo
      // si el servicio tiene problemas al arrancar (común tras reinstalaciones o hot-restarts).
      await initializeBackgroundService().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          debugPrint("⚠️ Advertencia: initializeBackgroundService tardó demasiado. Continuando carga de UI...");
          return;
        },
      );
    } catch (e) {
      debugPrint("❌ Error inicializando background service: $e");
    }
  }

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
    const bgDark = Color(0xFF0A0E14);
    const cardBg = Color(0xFF151921);
    const primaryNeon = Color(0xFF7C4DFF);
    const secondaryNeon = Color(0xFF03DAC6);
    
    return MaterialApp(
      title: 'VoxGamer',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('es'),
      ],

      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgDark,
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: primaryNeon,
          secondary: secondaryNeon,
          surface: cardBg,
          background: bgDark,
          onSurface: Color(0xFFEDEDED),
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).apply(
          bodyColor: const Color(0xFFEDEDED),
          displayColor: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: bgDark, // Se mantendrá transparente en HomePage por configuración local
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        tabBarTheme: TabBarTheme(
          labelColor: primaryNeon,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryNeon,
          dividerColor: Colors.transparent, 
        ),
        cardTheme: CardTheme(
          color: cardBg,
          elevation: 8,
          shadowColor: primaryNeon.withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
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
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final DataService _dataService = DataService();
  final TextEditingController _searchController = TextEditingController();
  
  final GlobalKey<GameListTabState> _gamesTabKey = GlobalKey();
  final GlobalKey<GameListTabState> _dlcsTabKey = GlobalKey();

  Timer? _debounce;
  bool _isSyncing = false;
  double _syncProgress = 0.0;
  String _statusMessage = '';
  
  // Flag para evitar doble carga inicial
  bool _isInitDataLoaded = false;

  // Control de suscripciones
  StreamSubscription? _progressSub;
  StreamSubscription? _successSub;
  StreamSubscription? _errorSub;

  String _selectedVoiceLanguage = 'Cualquiera';
  String _selectedTextLanguage = 'Cualquiera';
  String _selectedYear = 'Cualquiera';
  String _selectedGenre = 'Cualquiera';
  String _selectedPlatform = 'Cualquiera'; 
  String _selectedSort = 'date'; 

  List<String> _voiceLanguages = ['Cualquiera'];
  List<String> _textLanguages = ['Cualquiera'];
  List<String> _genres = ['Cualquiera'];
  List<String> _years = ['Cualquiera'];
  List<String> _platforms = ['Cualquiera']; 

  // GETTERS PÚBLICOS
  String get selectedVoiceLanguage => _selectedVoiceLanguage;
  String get selectedTextLanguage => _selectedTextLanguage;
  String get selectedYear => _selectedYear;
  String get selectedGenre => _selectedGenre;
  String get selectedPlatform => _selectedPlatform;
  String get selectedSort => _selectedSort;
  TextEditingController get searchController => _searchController;
  bool get isSyncing => _isSyncing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); 
    _requestNotificationPermissions(); 
    _searchController.addListener(_onSearchChanged);
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitDataLoaded) {
      _isInitDataLoaded = true;
      _checkAndLoadInitialData();
    }
  }

  void _setupServiceListeners() {
    _progressSub?.cancel();
    _successSub?.cancel();
    _errorSub?.cancel();

    final service = FlutterBackgroundService();

    _progressSub = service.on('progress').listen((event) {
      if (event != null && mounted) {
        final percent = event['percent'] as int;
        if (_syncProgress != percent / 100.0) {
           setState(() {
            _isSyncing = true;
            _syncProgress = percent / 100.0;
            _statusMessage = 'Procesando... $percent%';
          });
        }
      }
    });

    _successSub = service.on('success').listen((event) {
      if (mounted) {
        _finishSync(success: true);
      }
    });
    
    _errorSub = service.on('error').listen((event) {
      if (mounted) {
        _updateStatus('Error en segundo plano: ${event?['message']}');
        _finishSync(success: false);
      }
    });
  }
  
  void _finishSync({bool success = true}) async {
    WakelockPlus.disable();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_syncing', false);

    if (mounted) {
      setState(() => _isSyncing = false); // Quitamos overlay
      
      if (success) {
        await _loadFilterOptions();
        _refreshLists();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Actualización completada!')));
      }
    }
  }

  Future<void> _requestNotificationPermissions() async {
    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _debounce?.cancel();
    
    _progressSub?.cancel();
    _successSub?.cancel();
    _errorSub?.cancel();
    
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { 
    if (state == AppLifecycleState.resumed) {
      // Al volver, verificamos si el servicio sigue vivo
      _checkServiceStatus();
    }
  }
  
  Future<void> _checkServiceStatus() async {
    if (kIsWeb) return;
    
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    
    if (isRunning) {
       // Si el servicio corre, NOSOTROS debemos mostrar sincronización,
       // independientemente de lo que diga la UI antigua.
       if (!_isSyncing) {
         setState(() => _isSyncing = true);
         _setupServiceListeners();
       }
    } else {
       // Si el servicio NO corre, pero nosotros seguimos mostrando "cargando",
       // significa que terminó (o murió) mientras no mirábamos.
       if (_isSyncing) {
          // Asumimos éxito para refrescar y quitar overlay
          _finishSync(success: true); 
       }
    }
  }
  
  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _refreshLists();
    });
  }

  void _refreshLists() {
    _gamesTabKey.currentState?.reload();
    _dlcsTabKey.currentState?.reload();
  }

  void _updateStatus(String msg) {
    if (mounted) setState(() => _statusMessage = msg);
  }

  Future<void> _loadFilterOptions() async {
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
          if (options.containsKey('platforms')) {
            _platforms = ['Cualquiera', ...options['platforms']!];
          }
        });
      }
  }

  Future<bool> _wasSyncInterrupted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_syncing') ?? false;
  }

  // --- LÓGICA DE INICIO ROBUSTA ---
  Future<void> _checkAndLoadInitialData() async {
      // Ahora es seguro usar context porque estamos llamados desde didChangeDependencies
      final l10n = AppLocalizations.of(context)!;
      final dbHasData = (await _dataService.countLocalGames()) > 0;

      // CASO 1: LA BASE DE DATOS YA TIENE DATOS.
      // Carga la app inmediatamente, sin sincronización.
      if (dbHasData) {
          debugPrint("La base de datos tiene datos. Cargando desde SQLite local.");
          
          // Limpia cualquier estado de sincronización inconsistente de un reinicio en caliente.
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_syncing', false);
          
          final service = FlutterBackgroundService();
          if (await service.isRunning()) {
              service.invoke('stopService');
          }
          
          await _loadFilterOptions();
          _refreshLists();
          return;
      }

      // CASO 2: LA BASE DE DATOS ESTÁ VACÍA.
      // Esto significa que es una instalación limpia o se borraron los datos. Se debe sincronizar.
      
      bool interrupted = await _wasSyncInterrupted();
      
      if (interrupted) {
          // Si se interrumpió, intenta usar el archivo .json.gz ya descargado.
          debugPrint("BBDD vacía pero la sincronización fue interrumpida. Reintentando desde archivo local.");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text(l10n.msgSyncInterrupted), duration: const Duration(seconds: 4)),
            );
          }
          _updateCatalog(force: true, forceDownload: false);
      } else {
          // Si no, es una instalación 100% limpia. Descarga y procesa.
          debugPrint("BBDD vacía. Empezando sincronización inicial completa.");
          _updateCatalog(force: true, forceDownload: true);
      }
  }

  Future<void> _updateCatalog({bool force = false, bool forceDownload = true}) async {
    final l10n = AppLocalizations.of(context)!;
    
    if (!force) {
      bool? confirm = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.syncQuick), 
          content: Text(l10n.dialogUpdateContent),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.btnApply, style: const TextStyle(color: Colors.blueAccent))),
          ],
        ),
      );
      if (confirm != true) return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_syncing', true);

    setState(() {
      _isSyncing = true;
      _syncProgress = 0.0;
    });

    WakelockPlus.enable();
    _setupServiceListeners(); // Enganchamos listeners antes de arrancar

    final service = FlutterBackgroundService();
    if (!(await service.isRunning())) {
      await service.startService();
    }
    // Pequeño delay para asegurar que el servicio arrancó y está escuchando
    await Future.delayed(const Duration(milliseconds: 500));
    service.invoke('startSync', {'forceDownload': forceDownload});
  }

  // MÉTODO PÚBLICO
  bool hasActiveFilters() => 
    _selectedVoiceLanguage != 'Cualquiera' || 
    _selectedTextLanguage != 'Cualquiera' ||
    _selectedYear != 'Cualquiera' || 
    _selectedGenre != 'Cualquiera' ||
    _selectedPlatform != 'Cualquiera' ||
    _selectedSort != 'date';

  // NUEVO MÉTODO PÚBLICO PARA ELIMINAR FILTROS
  void removeFilter(String filterType) {
    setState(() {
      switch (filterType) {
        case 'sort': _selectedSort = 'date'; break;
        case 'platform': _selectedPlatform = 'Cualquiera'; break;
        case 'genre': _selectedGenre = 'Cualquiera'; break;
        case 'year': _selectedYear = 'Cualquiera'; break;
        case 'voice': _selectedVoiceLanguage = 'Cualquiera'; break;
        case 'text': _selectedTextLanguage = 'Cualquiera'; break;
      }
    });
    _refreshLists();
  }

  void _showFilterDialog() {
    final l10n = AppLocalizations.of(context)!;
    
    if (_isSyncing) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.msgWaitSync)));
      return;
    }

    String tempVoice = _selectedVoiceLanguage;
    String tempText = _selectedTextLanguage;
    String tempYear = _selectedYear;
    String tempGenre = _selectedGenre;
    String tempPlatform = _selectedPlatform;
    String tempSort = _selectedSort;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: const Color(0xFF151921),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder( 
          builder: (BuildContext context, StateSetter setModalState) {
            return FutureBuilder<List<String>>(
              future: _dataService.getTopPlatforms(5), 
              builder: (context, snapshot) {
                final topPlatforms = snapshot.data ?? []; 

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
                            Text(l10n.filtersConfig, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
                          ],
                        ),
                        const SizedBox(height: 24),

                        const Text("ORDENAR POR", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _buildSortChip("Fecha Lanzamiento", 'date', tempSort, (val) => setModalState(() => tempSort = val))),
                            const SizedBox(width: 8),
                            Expanded(child: _buildSortChip("Mejor Valorados", 'score', tempSort, (val) => setModalState(() => tempSort = val))),
                          ],
                        ),
                        const SizedBox(height: 24),

                        const Text("PLATAFORMA", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        
                        if (snapshot.connectionState == ConnectionState.waiting)
                           const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())),
                        
                        if (snapshot.hasData)
                          Wrap(
                            spacing: 8,
                            children: [
                              _buildPlatformChip("Cualquiera", tempPlatform, (val) => setModalState(() => tempPlatform = val)),
                              ...topPlatforms.map((p) => _buildPlatformChip(p, tempPlatform, (val) => setModalState(() => tempPlatform = val))).toList(),
                            ],
                          ),
                        
                        if (!topPlatforms.contains(tempPlatform) && tempPlatform != 'Cualquiera') ...[
                           const SizedBox(height: 8),
                            _buildSearchableDropdown(label: "Otra plataforma...", value: tempPlatform, items: _platforms, icon: Icons.gamepad, onSelected: (val) => setModalState(() => tempPlatform = val ?? 'Cualquiera'), context: context),
                        ] else ...[
                           const SizedBox(height: 8),
                           TextButton.icon(
                             onPressed: () {}, 
                             icon: const Icon(Icons.search, size: 16),
                             label: const Text("Buscar otra plataforma...", style: TextStyle(fontSize: 13)),
                           ),
                           _buildSearchableDropdown(label: "Buscar plataforma...", value: '', items: _platforms, icon: Icons.gamepad, onSelected: (val) => setModalState(() => tempPlatform = val ?? 'Cualquiera'), context: context),
                        ],

                        const SizedBox(height: 24),
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 16),

                        _buildSearchableDropdown(label: l10n.filterGenre, value: tempGenre, items: _genres, icon: Icons.category, onSelected: (val) => setModalState(() => tempGenre = val ?? 'Cualquiera'), context: context),
                        const SizedBox(height: 16),
                        _buildSearchableDropdown(label: l10n.filterYear, value: tempYear, items: _years, icon: Icons.calendar_today, onSelected: (val) => setModalState(() => tempYear = val ?? 'Cualquiera'), context: context),
                        const SizedBox(height: 16),
                        
                        Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            title: Text(l10n.languages, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            leading: const Icon(Icons.language, color: Colors.grey),
                            collapsedIconColor: Colors.grey,
                            children: [
                              _buildSearchableDropdown(label: l10n.filterVoice, value: tempVoice, items: _voiceLanguages, icon: Icons.mic, onSelected: (val) => setModalState(() => tempVoice = val ?? 'Cualquiera'), context: context),
                              const SizedBox(height: 12),
                              _buildSearchableDropdown(label: l10n.filterText, value: tempText, items: _textLanguages, icon: Icons.subtitles, onSelected: (val) => setModalState(() => tempText = val ?? 'Cualquiera'), context: context),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.grey.shade700), padding: const EdgeInsets.symmetric(vertical: 16)), onPressed: () { setModalState(() { tempVoice = 'Cualquiera'; tempText = 'Cualquiera'; tempYear = 'Cualquiera'; tempGenre = 'Cualquiera'; tempPlatform = 'Cualquiera'; tempSort = 'date'; }); }, child: Text(l10n.btnClear, style: const TextStyle(color: Colors.white)))),
                            const SizedBox(width: 16),
                            Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, padding: const EdgeInsets.symmetric(vertical: 16)), onPressed: () { 
                              setState(() { 
                                _selectedVoiceLanguage = tempVoice; 
                                _selectedTextLanguage = tempText; 
                                _selectedYear = tempYear; 
                                _selectedGenre = tempGenre; 
                                _selectedPlatform = tempPlatform; 
                                _selectedSort = tempSort;
                              }); 
                              Navigator.pop(context); 
                              _refreshLists(); 
                            }, child: Text(l10n.btnApply, style: const TextStyle(fontWeight: FontWeight.bold)))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom)),
                      ],
                    ),
                  ),
                );
              }
            );
          },
        );
      },
    );
  }

  Widget _buildSortChip(String label, String value, String groupValue, Function(String) onSelected) {
    final isSelected = value == groupValue;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) => onSelected(value),
      selectedColor: Theme.of(context).colorScheme.primary,
      backgroundColor: const Color(0xFF1E232F),
      labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildPlatformChip(String platform, String groupValue, Function(String) onSelected) {
    final isSelected = platform == groupValue;
    return ChoiceChip(
      label: Text(platform),
      selected: isSelected,
      onSelected: (selected) => onSelected(platform),
      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.8),
      backgroundColor: const Color(0xFF2A3040),
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade400, fontSize: 12),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildSearchableDropdown({required String label, required String value, required List<String> items, required IconData icon, required Function(String?) onSelected, required BuildContext context}) {
    final l10n = AppLocalizations.of(context)!;
    final uniqueItems = items.toSet().toList();
    final safeValue = uniqueItems.contains(value) ? value : 'Cualquiera';
    final isCualquiera = safeValue == 'Cualquiera';

    return LayoutBuilder(builder: (context, constraints) {
        return Autocomplete<String>(
          key: ValueKey(safeValue),
          initialValue: TextEditingValue(text: isCualquiera ? '' : safeValue),
          optionsBuilder: (TextEditingValue v) {
            if (v.text.isEmpty) return uniqueItems;
            return uniqueItems.where((op) => op.toLowerCase().contains(v.text.toLowerCase()));
          },
          onSelected: onSelected,
          fieldViewBuilder: (ctx, controller, focusNode, onSubmitted) {
            return TextField(
              controller: controller, focusNode: focusNode,
              decoration: InputDecoration(
                labelText: label, hintText: l10n.any,
                prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
                suffixIcon: controller.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 20, color: Colors.grey), onPressed: () { controller.clear(); onSelected('Cualquiera'); }) : null,
              ),
              style: const TextStyle(color: Colors.white),
            );
          },
          optionsViewBuilder: (ctx, onSelected, options) {
            return Align(alignment: Alignment.topLeft, child: Material(elevation: 4.0, color: const Color(0xFF1E232F),
                child: Container(width: constraints.maxWidth, constraints: const BoxConstraints(maxHeight: 250),
                  child: ListView.builder(padding: EdgeInsets.zero, shrinkWrap: true, itemCount: options.length, itemBuilder: (ctx, i) {
                      final op = options.elementAt(i);
                      return ListTile(title: Text(op == 'Cualquiera' ? l10n.any : op, style: const TextStyle(color: Colors.white)), onTap: () => onSelected(op));
                  }),
            )));
          },
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    // CALCULAR EL PADDING SUPERIOR EXACTO
    final double topPadding = MediaQuery.of(context).padding.top + kToolbarHeight + 120;
    
    return DefaultTabController(
      length: 3, 
      child: Scaffold(
        extendBodyBehindAppBar: true, 
        appBar: AppBar(
          backgroundColor: const Color(0xFF0A0E14).withOpacity(0.85), 
          flexibleSpace: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), 
              child: Container(color: Colors.transparent),
            ),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/icon/app_logo.png', width: 32, height: 32),
              const SizedBox(width: 8),
              Text(l10n?.appTitle ?? 'VoxGamer'),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) { if (value == 'update') _updateCatalog(); },
              color: const Color(0xFF1E232F),
              itemBuilder: (context) => [PopupMenuItem(value: 'update', child: Row(children: [const Icon(Icons.cloud_sync, color: Colors.blueAccent), const SizedBox(width: 8), Text(l10n?.syncQuick ?? "Actualizar", style: const TextStyle(color: Colors.white))]))],
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(120), 
            child: Column(
              children: [
                if (!_isSyncing)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))]),
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: l10n?.searchHint ?? '...',
                                hintStyle: TextStyle(color: Colors.grey.shade500),
                                prefixIcon: const Icon(Icons.search, color: Color(0xFF7C4DFF)),
                                fillColor: const Color(0xFF1E232F),
                                suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () { _searchController.clear(); _refreshLists(); }) : null,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: _showFilterDialog,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: hasActiveFilters() ? Theme.of(context).colorScheme.primary : const Color(0xFF1E232F),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: hasActiveFilters() ? Colors.transparent : Colors.grey.shade800),
                              boxShadow: [BoxShadow(color: hasActiveFilters() ? Theme.of(context).colorScheme.primary.withOpacity(0.4) : Colors.transparent, blurRadius: 10, spreadRadius: 1)]
                            ),
                            child: const Icon(Icons.tune, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                TabBar(
                  isScrollable: true, 
                  tabAlignment: TabAlignment.center, 
                  tabs: [
                    Tab(text: l10n?.tabGames ?? "JUEGOS", icon: const Icon(Icons.sports_esports)),
                    Tab(text: l10n?.tabDlcs ?? "DLCs", icon: const Icon(Icons.extension)),
                    // CAMBIO A TEXTO MÁS CORTO
                    Tab(text: "PRÓXIMOS", icon: const Icon(Icons.rocket_launch)), 
                  ],
                ),
              ],
            ),
          ),
        ),
        body: Stack(
          children: [
            // ELIMINADO EL PADDING DEL PADRE PARA PERMITIR SCROLL UNDER
            TabBarView(
              children: [
                GameListTab(
                  key: _gamesTabKey,
                  tipo: 'game',
                  dataService: _dataService,
                  parent: this,
                  topPadding: topPadding, // PASAMOS PADDING
                ),
                GameListTab(
                  key: _dlcsTabKey,
                  tipo: 'dlc',
                  dataService: _dataService,
                  parent: this,
                  topPadding: topPadding, // PASAMOS PADDING
                ),
                UpcomingGamesPlaceholder(topPadding: topPadding), // PASAMOS PADDING
              ],
            ),
            if (_isSyncing)
               MinigameOverlay(progress: _syncProgress),
          ],
        ),
      ),
    );
  }
}

// Widget Placeholder para Próximos Lanzamientos
class UpcomingGamesPlaceholder extends StatelessWidget {
  final double topPadding; // ACEPTAR PADDING
  const UpcomingGamesPlaceholder({super.key, this.topPadding = 0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding), // APLICAR PADDING
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rocket_launch, size: 80, color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
            const SizedBox(height: 24),
            const Text(
              "Próximos Lanzamientos",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Estamos preparando el motor de ignición.\nPronto verás aquí los estrenos más esperados.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade400, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget Reutilizable para las listas
class GameListTab extends StatefulWidget {
  final String tipo;
  final DataService dataService;
  final HomePageState parent;
  final double topPadding; // NUEVO PARÁMETRO

  const GameListTab({
    super.key,
    required this.tipo,
    required this.dataService,
    required this.parent,
    required this.topPadding,
  });

  @override
  State<GameListTab> createState() => GameListTabState();
}

class GameListTabState extends State<GameListTab> with AutomaticKeepAliveClientMixin {
  final List<Game> _games = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 0;
  final int _limit = 20;

  @override
  bool get wantKeepAlive => true; 

  @override
  void initState() {
    super.initState();
    _loadMoreGames();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void clear() {
    setState(() {
      _games.clear();
      _page = 0;
      _hasMore = true;
    });
  }

  void reload() {
    clear();
    _loadMoreGames();
  }

  Future<void> _loadMoreGames() async {
    if (_isLoading) return;
    if (!_hasMore && !widget.parent.isSyncing) return;

    setState(() => _isLoading = true);

    try {
      final newGames = await widget.dataService.getLocalGames(
        limit: _limit,
        offset: _page * _limit,
        query: widget.parent.searchController.text.isNotEmpty ? widget.parent.searchController.text : null,
        voiceLanguage: widget.parent.selectedVoiceLanguage,
        textLanguage: widget.parent.selectedTextLanguage,
        year: widget.parent.selectedYear,
        genre: widget.parent.selectedGenre,
        platform: widget.parent.selectedPlatform,
        tipo: widget.tipo, 
        sortBy: widget.parent.selectedSort,
      );

      if (!mounted) return;

      setState(() {
        _page++;
        _games.addAll(newGames);
        if (!widget.parent.isSyncing && newGames.length < _limit) {
          _hasMore = false;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreGames();
    }
  }

  Color _getScoreColor(int score) {
    if (score >= 75) return const Color(0xFF66CC33); 
    if (score >= 50) return const Color(0xFFFFCC33); 
    return const Color(0xFFFF0000); 
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    
    if (_games.isEmpty && !_isLoading) {
      if (widget.parent.isSyncing) return const SizedBox(); 
      
      return Center(
        child: Padding(
          padding: EdgeInsets.only(top: widget.topPadding + 32, left: 32, right: 32), // PADDING AJUSTADO
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.tipo == 'game' ? Icons.videogame_asset_off : Icons.extension_off, size: 80, color: Colors.grey.shade800),
              const SizedBox(height: 24),
              Text(l10n?.noSignals ?? "No hay datos", textAlign: TextAlign.center, style: TextStyle(fontSize: 20, color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // ELIMINADO EL WIDGET DE FILTROS DEL HEADER FIJO Y MOVIDO DENTRO DEL SCROLLVIEW SI ES POSIBLE
        // O MANTENERLO PERO CON PADDING CORRECTO
        // _buildActiveFiltersRow ahora debe renderizarse dentro del espacio visible o superpuesto
        // Para simplificar y mantener el efecto, lo ponemos como primer item del ListView o Stackeado.
        // Stackeado debajo del Header es complejo porque el header es transparente.
        // Mejor opción: Primer item de la lista es el filtro activo.
        
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            // AQUÍ ESTÁ LA CLAVE: PADDING INTERNO DEL LISTVIEW
            padding: EdgeInsets.fromLTRB(12, widget.topPadding + 10, 12, 8),
            itemCount: _games.length + (_hasMore ? 1 : 0) + (widget.parent.hasActiveFilters() ? 1 : 0),
            itemBuilder: (context, index) {
              // Ajuste de índice si hay filtros
              int gameIndex = index;
              if (widget.parent.hasActiveFilters()) {
                if (index == 0) return _buildActiveFiltersRow(context);
                gameIndex = index - 1;
              }

              if (gameIndex == _games.length) {
                return _buildShimmerLoading(rows: 1);
              }
              return _buildGameCard(context, _games[gameIndex]);
            },
          ),
        ),
      ],
    );
  }

  // WIDGET ADAPTADO PARA NO TENER PADDING FIJO EXCESIVO
  Widget _buildActiveFiltersRow(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final parent = widget.parent;
    final activeFilters = <Widget>[];

    void addFilterChip(String label, String filterType) {
      activeFilters.add(_buildDismissibleFilterChip(
        context,
        label,
        () => parent.removeFilter(filterType),
      ));
    }

    if (parent.selectedSort != 'date') addFilterChip('Orden: ${parent.selectedSort == 'score' ? 'Mejor valorados' : 'Fecha'}', 'sort');
    if (parent.selectedPlatform != 'Cualquiera') addFilterChip('Plataforma: ${parent.selectedPlatform}', 'platform');
    if (parent.selectedGenre != 'Cualquiera') addFilterChip('${l10n.filterGenre}: ${parent.selectedGenre}', 'genre');
    if (parent.selectedYear != 'Cualquiera') addFilterChip('${l10n.filterYear}: ${parent.selectedYear}', 'year');
    if (parent.selectedVoiceLanguage != 'Cualquiera') addFilterChip('${l10n.filterVoice}: ${parent.selectedVoiceLanguage}', 'voice');
    if (parent.selectedTextLanguage != 'Cualquiera') addFilterChip('${l10n.filterText}: ${parent.selectedTextLanguage}', 'text');
    
    // Si no hay filtros, devolvemos espacio vacío (aunque el itemCount ya lo maneja)
    if (activeFilters.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 8), // Margen inferior para separar de la lista
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: activeFilters),
      ),
    );
  }

  // NUEVO WIDGET PARA CREAR UN CHIP DE FILTRO INDIVIDUAL Y ELIMINABLE
  Widget _buildDismissibleFilterChip(BuildContext context, String label, VoidCallback onDeleted) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Chip(
        label: Text(label),
        onDeleted: onDeleted,
        deleteIcon: const Icon(Icons.close, size: 16),
        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
        side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
        deleteIconColor: Theme.of(context).colorScheme.primary.withOpacity(0.7),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

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
              Container(width: 120, height: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: double.infinity, height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 8),
                  Container(width: 100, height: 12, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
              ]))
            ],
          ),
        )),
      ),
    );
  }

  Widget _buildGameCard(BuildContext context, Game game) {
    Color scoreColor = Colors.grey;
    if (game.metacritic != null) {
      scoreColor = _getScoreColor(game.metacritic!);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF232936), // Un poco más claro
            const Color(0xFF151921), // Color original base
          ],
          stops: const [0.0, 1.0],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.07), width: 1), // Borde glass sutil
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6)
          ),
        ]
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => GameDetailPage(game: game)));
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 140, 
                height: 90, 
                child: Hero( 
                  tag: 'game_img_${game.slug}', 
                  child: ClipRRect( // Clip necesario por el borde redondeado del container padre
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                    child: game.imgPrincipal.isNotEmpty
                        ? Image.network(
                            game.imgPrincipal,
                            fit: BoxFit.cover,
                            cacheWidth: 300,
                            errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF151921), child: const Icon(Icons.broken_image, color: Colors.grey)),
                          )
                        : Container(color: const Color(0xFF151921), child: const Icon(Icons.videogame_asset, color: Colors.grey)),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        game.titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white, height: 1.1),
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
                          const Spacer(),
                          if (game.metacritic != null)
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                               decoration: BoxDecoration(
                                 color: scoreColor.withOpacity(0.15),
                                 borderRadius: BorderRadius.circular(6),
                                 border: Border.all(color: scoreColor.withOpacity(0.5), width: 1)
                               ),
                               child: Row(
                                 mainAxisSize: MainAxisSize.min,
                                 children: [
                                   Icon(Icons.star, size: 10, color: scoreColor),
                                   const SizedBox(width: 4),
                                   Text(
                                      game.metacritic.toString(),
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: scoreColor),
                                    ),
                                 ],
                               ),
                             ),
                        ],
                      ),
                      if (game.plataformas.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.gamepad, size: 12, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                game.plataformas.take(3).join(', '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              ),
                            ),
                          ],
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
