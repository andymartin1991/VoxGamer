import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:io'; 
import 'dart:ui'; 
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:app_links/app_links.dart'; 
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'models/game.dart';
import 'services/data_service.dart';
import 'services/database_helper.dart'; 
import 'services/background_service.dart';
import 'screens/game_detail_page.dart';
import 'widgets/minigame_overlay.dart'; 
import 'widgets/pegi_badge.dart'; 

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
  
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  if (!kIsWeb) {
    try {
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
          backgroundColor: bgDark, 
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        tabBarTheme: TabBarTheme(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            gradient: LinearGradient(
              colors: [primaryNeon, primaryNeon.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryNeon.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          dividerColor: Colors.transparent, 
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
        cardTheme: CardTheme(
          color: cardBg,
          elevation: 8,
          shadowColor: primaryNeon.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E232F),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
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
  final ScrollController _nestedScrollController = ScrollController(); 
  
  late TabController _tabController;
  
  final GlobalKey<GameListTabState> _gamesTabKey = GlobalKey();
  final GlobalKey<GameListTabState> _dlcsTabKey = GlobalKey();
  final GlobalKey<UpcomingGamesTabState> _upcomingTabKey = GlobalKey();

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  Uri? _pendingDeepLink; 

  Timer? _debounce;
  Timer? _autoShowTimer; 
  bool _isSyncing = false;
  double _syncProgress = 0.0;
  String _statusMessage = '';
  
  bool _isInitDataLoaded = false;
  bool _isReadyForDeepLinks = false; 

  StreamSubscription? _progressSub;
  StreamSubscription? _successSub;
  StreamSubscription? _errorSub;

  List<String> _selectedVoiceLanguages = [];
  List<String> _selectedTextLanguages = [];
  List<String> _selectedYears = [];
  List<String> _selectedGenres = [];
  List<String> _selectedPlatforms = []; 
  String _selectedSort = 'date'; 

  // Control Visual Premium
  bool _isHeaderExpanded = true;
  final double _topSectionHeight = 100.0; 
  final double _tabBarHeight = 50.0;
  final double _spacingHeight = 8.0; 

  List<String> _voiceLanguages = [];
  List<String> _textLanguages = [];
  List<String> _genres = [];
  List<String> _years = [];
  List<String> _platforms = []; 

  List<String> get selectedVoiceLanguages => _selectedVoiceLanguages;
  List<String> get selectedTextLanguages => _selectedTextLanguages;
  List<String> get selectedYears => _selectedYears;
  List<String> get selectedGenres => _selectedGenres;
  List<String> get selectedPlatforms => _selectedPlatforms;
  String get selectedSort => _selectedSort;
  TextEditingController get searchController => _searchController;
  bool get isSyncing => _isSyncing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
    
    // Eliminamos la llamada directa aquí para secuenciarla mejor
    // _requestNotificationPermissions(); 
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAppSequence();
    });
    
    _searchController.addListener(_onSearchChanged);
  }

  // Nueva función para orquestar la inicialización secuencial
  Future<void> _initAppSequence() async {
    // 1. Pedir permisos de notificación PRIMERO
    await _requestNotificationPermissions();
    
    // 2. Comprobar edad (si es necesario)
    if (mounted) {
      await _checkAdultStatus();
    }
    
    // 3. Inicializar Deep Links y Datos
    if (mounted) {
      _initDeepLinks();
      
      // La carga de datos se movió de didChangeDependencies a aquí o se revisa
      if (!_isInitDataLoaded) {
        _isInitDataLoaded = true;
        _checkAndLoadInitialData();
      }
    }
  }

  void _handleTabSelection() {
    _autoShowTimer?.cancel();
    if (!_isHeaderExpanded) {
      setState(() => _isHeaderExpanded = true);
    }

    if (_tabController.indexIsChanging) {
      _refreshActiveTabOnly();
    }
  }

  Future<void> _checkAdultStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isAdult = prefs.getBool('is_adult');
    final l10n = AppLocalizations.of(context)!;

    if (isAdult == null) {
      if (!mounted) return;
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(l10n.ageVerificationTitle),
            content: Text(l10n.ageVerificationContent),
            actions: [
              TextButton(
                onPressed: () async {
                  await prefs.setBool('is_adult', false);
                  Navigator.pop(context);
                  _refreshLists();
                },
                child: Text(l10n.btnNo),
              ),
              FilledButton(
                onPressed: () async {
                  await prefs.setBool('is_adult', true);
                  Navigator.pop(context);
                  _refreshLists();
                },
                child: Text(l10n.btnYesAdult),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _toggleAdultContent() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getBool('is_adult') ?? false;
    final l10n = AppLocalizations.of(context)!;

    if (!current) {
        bool? confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.dialogAdultTitle),
            content: Text(l10n.dialogAdultContent),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
              TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.confirm)),
            ],
          ),
        );
        if (confirm != true) return;
    }

    await prefs.setBool('is_adult', !current);
    _refreshLists();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(!current ? l10n.msgAdultEnabled : l10n.msgAdultDisabled)),
      );
    }
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();
    try {
      final Uri? initialUri = await _appLinks.getInitialAppLink();
      if (initialUri != null) {
        _processOrQueueLink(initialUri);
      }
    } catch (e) {
      debugPrint("Info: $e");
    }

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _processOrQueueLink(uri);
    }, onError: (err) {
      debugPrint("Error: $err");
    });
  }

  void _processOrQueueLink(Uri uri) {
    if (_isReadyForDeepLinks) {
      _handleDeepLink(uri);
    } else {
      _pendingDeepLink = uri;
    }
  }

  void _handleDeepLink(Uri uri) async {
    bool isGitHubLink = uri.host.contains('github.io') && uri.path.contains('/game/');
    bool isCustomScheme = uri.scheme == 'voxgamer' && uri.host == 'game';

    if (isGitHubLink || isCustomScheme) {
      if (uri.pathSegments.isNotEmpty) {
        final slug = uri.pathSegments.last;
        final year = uri.queryParameters['year'];

        if (!_isReadyForDeepLinks) await Future.delayed(const Duration(milliseconds: 500));

        final game = await _dataService.getGameBySlug(slug, year: year);

        if (!mounted) return;

        if (game != null) {
           Navigator.push(
             context,
             MaterialPageRoute(builder: (context) => GameDetailPage(game: game)),
           );
        } else {
           if (!_isSyncing) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(
                 content: Text('Juego no encontrado'),
                 duration: Duration(seconds: 3),
               ),
             );
           }
        }
      }
    }
  }

  // Modificado: Se elimina la carga aquí para centralizarla en _initAppSequence
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // La carga inicial ahora se maneja en _initAppSequence tras los permisos
  }

  Future<bool> _wasSyncInterrupted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_syncing') ?? false;
  }

  Future<void> _checkAndLoadInitialData() async {
      final l10n = AppLocalizations.of(context)!;
      final dbHasData = (await _dataService.countLocalGames()) > 0;

      if (dbHasData) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_syncing', false);

          final service = FlutterBackgroundService();
          if (await service.isRunning()) {
              service.invoke('stopService');
          }
          await _loadFilterOptions();
          _refreshLists();

          _markReadyForLinks();
          return;
      }

      bool interrupted = await _wasSyncInterrupted();

      if (interrupted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text(l10n.msgSyncInterrupted), duration: const Duration(seconds: 4)),
            );
          }
          _updateCatalog(force: true, forceDownload: false);
      } else {
          _updateCatalog(force: true, forceDownload: true);
      }
  }

  void _markReadyForLinks() {
    setState(() => _isReadyForDeepLinks = true);
    if (_pendingDeepLink != null) {
      Future.delayed(const Duration(milliseconds: 100), () {
         _handleDeepLink(_pendingDeepLink!);
         _pendingDeepLink = null;
      });
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
      _isReadyForDeepLinks = false;
    });
    WakelockPlus.enable();
    _setupServiceListeners();
    final service = FlutterBackgroundService();
    if (!(await service.isRunning())) {
      await service.startService();
    }
    await Future.delayed(const Duration(milliseconds: 500));
    service.invoke('startSync', {'forceDownload': forceDownload});
  }

  void _finishSync({bool success = true}) async {
    final l10n = AppLocalizations.of(context)!;
    WakelockPlus.disable();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_syncing', false);
    if (mounted) {
      setState(() => _isSyncing = false);
      if (success) {
        await _loadFilterOptions();
        _refreshLists();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.msgUpdateComplete)));
        _markReadyForLinks();
      }
    }
  }

  void _setupServiceListeners() {
    final l10n = AppLocalizations.of(context)!;
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
            _statusMessage = '${l10n.msgProcessing} $percent%';
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
        _updateStatus('Error: ${event?['message']}');
        _finishSync(success: false);
      }
    });
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
    _autoShowTimer?.cancel();
    _progressSub?.cancel();
    _successSub?.cancel();
    _errorSub?.cancel();
    _linkSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkServiceStatus();
    }
  }

  Future<void> _checkServiceStatus() async {
    if (kIsWeb) return;
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (isRunning) {
       if (!_isSyncing) {
         setState(() => _isSyncing = true);
         _setupServiceListeners();
       }
    } else {
       if (_isSyncing) {
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
    _refreshActiveTabOnly();
  }

  void _refreshActiveTabOnly() {
    switch (_tabController.index) {
      case 0:
        _gamesTabKey.currentState?.reload();
        break;
      case 1:
        _dlcsTabKey.currentState?.reload();
        break;
      case 2:
        _upcomingTabKey.currentState?.reload();
        break;
    }
  }

  void _triggerUpcomingSync() {
    _upcomingTabKey.currentState?.syncUpcoming();
  }

  void _updateStatus(String msg) {
    if (mounted) setState(() => _statusMessage = msg);
  }

  Future<void> _loadFilterOptions() async {
    final options = await _dataService.getFilterOptions();
      if (options.isNotEmpty && mounted) {
        setState(() {
          if (options.containsKey('voices')) {
            _voiceLanguages = options['voices']!;
          }
          if (options.containsKey('texts')) {
            _textLanguages = options['texts']!;
          }
          if (options.containsKey('genres')) {
            _genres = options['genres']!;
          }
          if (options.containsKey('years')) {
            _years = options['years']!;
          }
          if (options.containsKey('platforms')) {
            _platforms = options['platforms']!;
          }
        });
      }
  }

  bool hasActiveFilters() =>
    _selectedVoiceLanguages.isNotEmpty ||
    _selectedTextLanguages.isNotEmpty ||
    _selectedYears.isNotEmpty ||
    _selectedGenres.isNotEmpty ||
    _selectedPlatforms.isNotEmpty ||
    _selectedSort != 'date';

  void removeFilter(String filterType, [String? value]) {
    setState(() {
      switch (filterType) {
        case 'sort': _selectedSort = 'date'; break;
        case 'platform':
          if (value != null) _selectedPlatforms.remove(value);
          else _selectedPlatforms.clear();
          break;
        case 'genre':
          if (value != null) _selectedGenres.remove(value);
          else _selectedGenres.clear();
          break;
        case 'year':
          if (value != null) _selectedYears.remove(value);
          else _selectedYears.clear();
          break;
        case 'voice':
          if (value != null) _selectedVoiceLanguages.remove(value);
          else _selectedVoiceLanguages.clear();
          break;
        case 'text':
          if (value != null) _selectedTextLanguages.remove(value);
          else _selectedTextLanguages.clear();
          break;
      }
    });
    _refreshLists();
  }

  // --- NUEVA IMPLEMENTACIÓN DE MENÚ PREMIUM ---
  void _showSettingsModal() async {
    final l10n = AppLocalizations.of(context)!;
    final prefs = await SharedPreferences.getInstance();
    bool isAdult = prefs.getBool('is_adult') ?? false;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1218).withOpacity(0.95),
                    border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          margin: const EdgeInsets.only(top: 12, bottom: 20),
                          decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: Text(l10n.filtersConfig.replaceAll('Filtros', 'Ajustes'), // Usando string existente o default
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),

                      const SizedBox(height: 12),
                      
                      // BLOQUE DE DATOS
                      _buildSettingsTile(
                        icon: Icons.cloud_sync_outlined,
                        color: Colors.blueAccent,
                        title: l10n.syncQuick,
                        subtitle: "Actualizar base de datos local",
                        onTap: () { Navigator.pop(context); _updateCatalog(); },
                      ),
                      _buildSettingsTile(
                        icon: Icons.rocket_launch_outlined,
                        color: Colors.purpleAccent,
                        title: l10n.syncUpcoming,
                        subtitle: "Buscar próximos lanzamientos",
                        onTap: () { Navigator.pop(context); _triggerUpcomingSync(); },
                      ),
                      
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: Divider(color: Colors.white10),
                      ),

                      // BLOQUE DE PREFERENCIAS
                      SwitchListTile(
                        value: isAdult,
                        activeColor: Colors.redAccent,
                        inactiveThumbColor: Colors.grey,
                        inactiveTrackColor: Colors.grey.shade900,
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.explicit, color: Colors.redAccent),
                        ),
                        title: Text(l10n.filterAdult, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(isAdult ? l10n.msgAdultDisabled : l10n.msgAdultEnabled, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                        onChanged: (bool value) async {
                          await _toggleAdultContent();
                          setModalState(() => isAdult = value);
                        },
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: Divider(color: Colors.white10),
                      ),

                      // BLOQUE DE MANTENIMIENTO
                      _buildSettingsTile(
                        icon: Icons.cleaning_services_outlined,
                        color: Colors.orangeAccent,
                        title: l10n.clearCache,
                        subtitle: "Liberar espacio en disco",
                        onTap: () { Navigator.pop(context); _clearCache(context); },
                      ),
                      
                      const SizedBox(height: 30),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 30),
                        child: Text("VoxGamer v1.0.0", style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
    );
  }

  void _showFilterDialog() {
    final l10n = AppLocalizations.of(context)!;
    if (_isSyncing) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.msgWaitSync)));
      return;
    }

    List<String> tempVoices = List.from(_selectedVoiceLanguages);
    List<String> tempTexts = List.from(_selectedTextLanguages);
    List<String> tempYears = List.from(_selectedYears);
    List<String> tempGenres = List.from(_selectedGenres);
    List<String> tempPlatforms = List.from(_selectedPlatforms);
    String tempSort = _selectedSort;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              color: const Color(0xFF0F1218).withOpacity(0.9),
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setModalState) {
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40, height: 4,
                              margin: const EdgeInsets.only(bottom: 24),
                              decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(2)),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(l10n.filtersConfig, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.grey),
                                onPressed: () => Navigator.pop(context),
                                style: IconButton.styleFrom(backgroundColor: Colors.white10),
                              )
                            ],
                          ),
                          const SizedBox(height: 32),

                          _buildFilterHeader(l10n.sortBy, Icons.sort),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _buildSortChip(l10n.sortDate, 'date', tempSort, (val) => setModalState(() => tempSort = val))),
                              const SizedBox(width: 12),
                              Expanded(child: _buildSortChip(l10n.sortScore, 'score', tempSort, (val) => setModalState(() => tempSort = val))),
                            ],
                          ),
                          const SizedBox(height: 32),

                          _buildMultiSelectSection(context, l10n.platformHeader, Icons.gamepad, tempPlatforms, _platforms, (list) => setModalState(() => tempPlatforms = list)),
                          const SizedBox(height: 24),
                          _buildMultiSelectSection(context, l10n.filterGenre, Icons.category, tempGenres, _genres, (list) => setModalState(() => tempGenres = list)),
                          const SizedBox(height: 24),
                          _buildMultiSelectSection(context, l10n.filterYear, Icons.calendar_today, tempYears, _years, (list) => setModalState(() => tempYears = list)),
                          const SizedBox(height: 24),

                          Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              title: Text(l10n.languages, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              leading: const Icon(Icons.language, color: Colors.grey),
                              collapsedIconColor: Colors.grey,
                              tilePadding: EdgeInsets.zero,
                              children: [
                                _buildMultiSelectSection(context, l10n.filterVoice, Icons.mic, tempVoices, _voiceLanguages, (list) => setModalState(() => tempVoices = list)),
                                const SizedBox(height: 16),
                                _buildMultiSelectSection(context, l10n.filterText, Icons.subtitles, tempTexts, _textLanguages, (list) => setModalState(() => tempTexts = list)),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18), foregroundColor: Colors.grey.shade400),
                                  onPressed: () {
                                    setModalState(() { tempVoices.clear(); tempTexts.clear(); tempYears.clear(); tempGenres.clear(); tempPlatforms.clear(); tempSort = 'date'; });
                                  },
                                  child: Text(l10n.btnClear)
                                )
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: Theme.of(context).colorScheme.primary,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                        blurRadius: 20,
                                        offset: const Offset(0, 4)
                                      )
                                    ]
                                  ),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _selectedVoiceLanguages = tempVoices;
                                        _selectedTextLanguages = tempTexts;
                                        _selectedYears = tempYears;
                                        _selectedGenres = tempGenres;
                                        _selectedPlatforms = tempPlatforms;
                                        _selectedSort = tempSort;
                                      });
                                      Navigator.pop(context);
                                      _refreshLists();
                                    },
                                    child: Text(l10n.btnApply.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2))
                                  ),
                                )
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
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMultiSelectSection(BuildContext context, String title, IconData icon, List<String> currentSelection, List<String> allOptions, Function(List<String>) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFilterHeader(title, icon),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...currentSelection.map((item) => _buildActiveFilterTag(context, item, () {
                final newList = List<String>.from(currentSelection)..remove(item);
                onChanged(newList);
            })),

            InkWell(
              onTap: () {
                _showMultiSelectSheet(context, title, allOptions, currentSelection, onChanged);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24, style: BorderStyle.solid),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.add, size: 14, color: Colors.white70),
                    SizedBox(width: 4),
                    Text("Añadir", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActiveFilterTag(BuildContext context, String label, VoidCallback onDelete) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          InkWell(
            onTap: onDelete,
            child: Icon(Icons.close, size: 14, color: primaryColor),
          )
        ],
      ),
    );
  }

  void _showMultiSelectSheet(BuildContext context, String title, List<String> options, List<String> selected, Function(List<String>) onConfirm) {
    List<String> tempSelected = List.from(selected);
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredOptions = searchQuery.isEmpty
                ? options
                : options.where((op) => op.toLowerCase().contains(searchQuery.toLowerCase())).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: const Color(0xFF0A0E14),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.white10)),
                      color: Color(0xFF151921),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24))
                    ),
                    child: Column(
                      children: [
                        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                autofocus: false,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Buscar $title...',
                                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                                  filled: true,
                                  fillColor: const Color(0xFF0A0E14),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                ),
                                onChanged: (val) => setSheetState(() => searchQuery = val),
                              ),
                            ),
                            const SizedBox(width: 12),
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Listo", style: TextStyle(fontWeight: FontWeight.bold)))
                          ],
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 160,
                        childAspectRatio: 2.8,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: filteredOptions.length,
                      itemBuilder: (context, index) {
                        final option = filteredOptions[index];
                        final isSelected = tempSelected.contains(option);
                        final primaryColor = Theme.of(context).colorScheme.primary;

                        return InkWell(
                          onTap: () {
                            setSheetState(() {
                              if (isSelected) tempSelected.remove(option);
                              else tempSelected.add(option);
                            });
                            onConfirm(tempSelected);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: isSelected ? primaryColor.withOpacity(0.2) : const Color(0xFF1E232F),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? primaryColor : Colors.white.withOpacity(0.05),
                                width: isSelected ? 1.5 : 1
                              ),
                              boxShadow: isSelected ? [BoxShadow(color: primaryColor.withOpacity(0.2), blurRadius: 8)] : null,
                            ),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              option,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey.shade400,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildFilterHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(width: 4, height: 16, color: Theme.of(context).colorScheme.secondary, margin: const EdgeInsets.only(right: 8)),
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
      ],
    );
  }

  Widget _buildSortChip(String label, String value, String groupValue, Function(String) onSelected) {
    final isSelected = value == groupValue;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: () => onSelected(value),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.2) : const Color(0xFF1E232F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? primaryColor : Colors.white10, width: isSelected ? 1.5 : 1),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade400,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
          ),
        ),
      ),
    );
  }

  Widget buildActiveFiltersRow(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final parent = this;
    final activeFilters = <Widget>[];

    void addFilterChip(String label, String filterType, [String? value]) {
      activeFilters.add(_buildDismissibleFilterChip(
        context,
        label,
        () => parent.removeFilter(filterType, value),
      ));
    }

    if (parent.selectedSort != 'date') addFilterChip('${l10n.sortBy}: ${parent.selectedSort == 'score' ? l10n.sortScore : l10n.sortDate}', 'sort');

    for (var p in parent.selectedPlatforms) addFilterChip(p, 'platform', p);
    for (var g in parent.selectedGenres) addFilterChip(g, 'genre', g);
    for (var y in parent.selectedYears) addFilterChip(y, 'year', y);
    for (var v in parent.selectedVoiceLanguages) addFilterChip('${l10n.filterVoice}: $v', 'voice', v);
    for (var t in parent.selectedTextLanguages) addFilterChip('${l10n.filterText}: $t', 'text', t);

    if (activeFilters.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: activeFilters),
      ),
    );
  }

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

  void _clearCache(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await DefaultCacheManager().emptyCache();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.msgCacheCleared)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.msgCacheError}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final topPadding = MediaQuery.of(context).padding.top;
    final totalHeaderHeight = topPadding + _topSectionHeight + _spacingHeight + _tabBarHeight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis == Axis.vertical) {
            _autoShowTimer?.cancel();

            // ELIMINADO EL UMBRAL DE 50PX PARA QUE SEA FLUIDO SIEMPRE

            if (notification.direction == ScrollDirection.forward) {
               // SCROLL HACIA ABAJO (Visualmente contenido sube) -> OCULTAR
               if (_isHeaderExpanded) setState(() => _isHeaderExpanded = false);
            } else if (notification.direction == ScrollDirection.reverse) {
               // SCROLL HACIA ARRIBA (Visualmente contenido baja) -> OCULTAR (Modo inmersivo)
               // El usuario pidió "al scrolear para abajo TAMBIEN se oculte", implicando que al subir ya se ocultaba.
               if (_isHeaderExpanded) setState(() => _isHeaderExpanded = false);
            } else if (notification.direction == ScrollDirection.idle) {
               // PARADA -> MOSTRAR (Show on Stop)
               _autoShowTimer = Timer(const Duration(milliseconds: 100), () { 
                if (mounted && !_isHeaderExpanded) {
                  setState(() => _isHeaderExpanded = true);
                }
              });
            }
          }
          return false;
        },
        child: Stack(
          children: [
            // CAPA 1: LISTAS (Contenido)
            Padding(
              padding: EdgeInsets.zero,
              child: TabBarView(
                controller: _tabController,
                children: [
                  GameListTab(
                    key: _gamesTabKey,
                    tipo: 'game',
                    dataService: _dataService,
                    parent: this,
                    topPadding: 0, 
                  ),
                  GameListTab(
                    key: _dlcsTabKey,
                    tipo: 'dlc',
                    dataService: _dataService,
                    parent: this,
                    topPadding: 0,
                  ),
                  UpcomingGamesTab(
                    key: _upcomingTabKey,
                    topPadding: 0,
                    dataService: _dataService,
                    parent: this, 
                  ), 
                ],
              ),
            ),

            // CAPA 2: HEADER ANIMADO (Stack)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              top: _isHeaderExpanded ? 0 : -(_topSectionHeight + _spacingHeight), 
              left: 0,
              right: 0,
              height: totalHeaderHeight, 
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF0A0E14).withOpacity(0.8), 
                          const Color(0xFF0A0E14).withOpacity(0.6),
                        ],
                      ),
                      border: Border(
                        bottom: BorderSide(color: Colors.white.withOpacity(0.05), width: 1)
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))
                      ]
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        children: [
                          // 1. TOP SECTION -> ANIMATED OPACITY
                          Expanded(
                            child: AnimatedOpacity(
                              opacity: _isHeaderExpanded ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 200), // Fade más rápido que el slide
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Logo Row
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Image.asset('assets/icon/app_logo.png', width: 28, height: 28),
                                            const SizedBox(width: 8),
                                            Text(l10n?.appTitle ?? 'VoxGamer', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                                          ],
                                        ),
                                        
                                        // --- REEMPLAZO MENU PREMIUM ---
                                        IconButton(
                                          icon: const Icon(Icons.settings_rounded, color: Colors.white70),
                                          onPressed: _showSettingsModal,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Search Row
                                  if (!_isSyncing)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Container(
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF1E232F).withOpacity(0.5), 
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: TextField(
                                                controller: _searchController,
                                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                                decoration: InputDecoration(
                                                  hintText: l10n?.searchHint ?? '...',
                                                  hintStyle: TextStyle(color: Colors.grey.shade500),
                                                  prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF7C4DFF)),
                                                  border: InputBorder.none,
                                                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                                  suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 18, color: Colors.grey), onPressed: () { _searchController.clear(); _refreshLists(); }) : null,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          InkWell(
                                            onTap: _showFilterDialog,
                                            borderRadius: BorderRadius.circular(12),
                                            child: Container(
                                              width: 40, height: 40,
                                              decoration: BoxDecoration(
                                                color: hasActiveFilters() ? Theme.of(context).colorScheme.primary : const Color(0xFF1E232F).withOpacity(0.5),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: hasActiveFilters() ? Colors.transparent : Colors.grey.shade800),
                                              ),
                                              child: const Icon(Icons.tune, size: 20, color: Colors.white),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          // 2. BOTTOM SECTION (TabBar)
                          SizedBox(height: _spacingHeight), // Espacio dinámico que se oculta al subir
                          SizedBox(
                            height: _tabBarHeight,
                            child: TabBar(
                              controller: _tabController,
                              isScrollable: true,
                              tabAlignment: TabAlignment.center, 
                              labelPadding: const EdgeInsets.symmetric(horizontal: 24),
                              indicatorColor: Theme.of(context).colorScheme.primary,
                              labelColor: Colors.white,
                              unselectedLabelColor: Colors.grey,
                              tabs: [
                                Tab(text: l10n?.tabGames ?? "JUEGOS"),
                                Tab(text: l10n?.tabDlcs ?? "DLCs"),
                                Tab(text: l10n?.tabUpcoming ?? "PRÓXIMOS"), 
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            if (_isSyncing)
               MinigameOverlay(progress: _syncProgress),
          ],
        ),
      ),
    );
  }
}

class UpcomingGamesTab extends StatefulWidget {
  final double topPadding; 
  final DataService dataService;
  final HomePageState parent; 

  const UpcomingGamesTab({super.key, required this.topPadding, required this.dataService, required this.parent});

  @override
  State<UpcomingGamesTab> createState() => UpcomingGamesTabState();
}

class UpcomingGamesTabState extends State<UpcomingGamesTab> with AutomaticKeepAliveClientMixin {
  bool _isLoading = true; 
  List<Game> _games = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  void reload() {
    _loadGames();
  }

  Future<void> _loadGames() async {
    if (mounted) setState(() => _isLoading = true);

    final games = await widget.dataService.getUpcomingGames(
      query: widget.parent.searchController.text.isNotEmpty ? widget.parent.searchController.text : null,
      voiceLanguages: widget.parent.selectedVoiceLanguages, 
      textLanguages: widget.parent.selectedTextLanguages,
      years: widget.parent.selectedYears,
      genres: widget.parent.selectedGenres,
      platforms: widget.parent.selectedPlatforms,
      sortBy: widget.parent.selectedSort,
      fastMode: true, 
    );
    if (mounted) {
      setState(() {
        _games = games;
        _isLoading = false; 
      });
    }
  }

  Future<void> syncUpcoming() async {
    setState(() => _isLoading = true);
    await widget.dataService.syncUpcomingGames();
    await _loadGames();
    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.msgUpcomingUpdated)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;
    
    // Actualizamos el padding total para que la lista empiece en el sitio correcto
    final listTopPadding = MediaQuery.of(context).padding.top + 100.0 + 50.0 + 8.0 + 8.0; // Ajustado a nueva altura

    if (_isLoading && _games.isEmpty) {
       return Padding(
         padding: EdgeInsets.only(top: listTopPadding),
         child: const Center(child: CircularProgressIndicator()),
       );
    }
    
    if (_games.isEmpty && !_isLoading) {
      if (widget.parent.hasActiveFilters()) {
         return Center(child: Text(l10n.noSignals, style: const TextStyle(color: Colors.grey)));
      }

      return Center(
        child: Padding(
          padding: EdgeInsets.only(top: listTopPadding, left: 32, right: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.rocket_launch, size: 80, color: Colors.grey.shade800),
              const SizedBox(height: 24),
              Text(l10n.msgUpcomingEmpty, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: syncUpcoming, 
                icon: const Icon(Icons.refresh),
                label: Text(l10n.btnDownloadNow),
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
              )
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (_isLoading)
          Padding(
            padding: EdgeInsets.only(top: listTopPadding, bottom: 10),
            child: const LinearProgressIndicator(minHeight: 2, color: Colors.purpleAccent),
          ),
        
        Expanded(
          child: ListView.builder(
            // Padding superior ajustado para que empiece DEBAJO del header expandido
            padding: EdgeInsets.fromLTRB(12, (_isLoading ? 0 : listTopPadding), 12, 8),
            itemCount: _games.length + (widget.parent.hasActiveFilters() ? 1 : 0),
            itemBuilder: (context, index) {
              int gameIndex = index;
              if (widget.parent.hasActiveFilters()) {
                if (index == 0) return widget.parent.buildActiveFiltersRow(context);
                gameIndex = index - 1;
              }
              return _buildUpcomingCard(context, _games[gameIndex]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingCard(BuildContext context, Game game) {
    final l10n = AppLocalizations.of(context)!;
    
    Widget buildPlatforms() {
      if (game.plataformas.isEmpty) return const SizedBox.shrink();
      
      const int maxVisible = 3;
      final visiblePlatforms = game.plataformas.take(maxVisible).toList();
      final remainingCount = game.plataformas.length - maxVisible;

      return Row(
        children: [
          Icon(Icons.gamepad, size: 12, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              visiblePlatforms.join(', ') + (remainingCount > 0 ? ' +$remainingCount' : ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ),
        ],
      );
    }
    
    Widget _buildTypeLabel(String tipo) {
       if (tipo.toLowerCase() == 'dlc') {
         return Container(
           margin: const EdgeInsets.only(bottom: 6),
           padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
           decoration: BoxDecoration(
             color: Colors.orangeAccent.withOpacity(0.2),
             borderRadius: BorderRadius.circular(4),
             border: Border.all(color: Colors.orangeAccent.withOpacity(0.5), width: 1),
           ),
           child: const Text('DLC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
         );
       }
       if (tipo.toLowerCase() == 'game' || tipo.toLowerCase() == 'upcoming') {
          return Container(
           margin: const EdgeInsets.only(bottom: 6),
           padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
           decoration: BoxDecoration(
             color: Colors.greenAccent.withOpacity(0.2),
             borderRadius: BorderRadius.circular(4),
             border: Border.all(color: Colors.greenAccent.withOpacity(0.5), width: 1),
           ),
           child: const Text('GAME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
         );
       }
       return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2A203B), 
            const Color(0xFF151921),
          ],
        ),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.15), width: 1),
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
                  child: ClipRRect( 
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                    child: game.imgPrincipal.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: game.imgPrincipal,
                            fit: BoxFit.cover,
                            memCacheWidth: 400,
                            errorWidget: (context, url, error) => Container(color: const Color(0xFF151921), child: const Icon(Icons.broken_image, color: Colors.grey)),
                            placeholder: (context, url) => Container(color: const Color(0xFF151921)),
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
                          Icon(Icons.calendar_month, size: 12, color: Colors.purpleAccent.shade100),
                          const SizedBox(width: 4),
                          Text(
                            game.fechaLanzamiento.isNotEmpty ? game.fechaLanzamiento : 'TBA',
                            style: TextStyle(fontSize: 12, color: Colors.purpleAccent.shade100, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          // --- PEGI EN LISTA ---
                          if (game.edadRecomendada != null)
                             Padding(
                               padding: const EdgeInsets.only(right: 8.0),
                               child: PegiBadge(age: game.edadRecomendada!, size: 24, showLabel: false),
                             ),
                          _buildTypeLabel(game.tipo),
                        ],
                      ),
                      const SizedBox(height: 6),
                      buildPlatforms(),
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

class GameListTab extends StatefulWidget {
  final String tipo;
  final DataService dataService;
  final HomePageState parent;
  final double topPadding; // No usado en Stack pero mantenemos firma

  const GameListTab({super.key, required this.tipo, required this.dataService, required this.parent, required this.topPadding});

  @override
  State<GameListTab> createState() => GameListTabState();
}

class GameListTabState extends State<GameListTab> with AutomaticKeepAliveClientMixin {
  final List<Game> _games = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 0;
  final int _limit = 50; 

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
    setState(() { _games.clear(); _page = 0; _hasMore = true; });
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
        voiceLanguages: widget.parent.selectedVoiceLanguages, 
        textLanguages: widget.parent.selectedTextLanguages,
        years: widget.parent.selectedYears,
        genres: widget.parent.selectedGenres,
        platforms: widget.parent.selectedPlatforms,
        tipo: widget.tipo, 
        sortBy: widget.parent.selectedSort,
        fastMode: true, 
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
    final listTopPadding = MediaQuery.of(context).padding.top + 100.0 + 50.0 + 8.0 + 8.0; // Ajustado a nueva altura + gap
    
    if (_games.isEmpty && !_isLoading) {
      if (widget.parent.isSyncing) return const SizedBox(); 
      
      return Center(
        child: Padding(
          padding: EdgeInsets.only(top: listTopPadding, left: 32, right: 32),
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
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(12, listTopPadding, 12, 8),
            itemCount: _games.length + (_hasMore ? 1 : 0) + (widget.parent.hasActiveFilters() ? 1 : 0),
            itemBuilder: (context, index) {
              int gameIndex = index;
              if (widget.parent.hasActiveFilters()) {
                if (index == 0) return widget.parent.buildActiveFiltersRow(context);
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
    
    // LÓGICA DE PLATAFORMAS CONSOLIDADA
    Widget buildPlatforms() {
      if (game.plataformas.isEmpty) return const SizedBox.shrink();
      
      const int maxVisible = 3;
      final visiblePlatforms = game.plataformas.take(maxVisible).toList();
      final remainingCount = game.plataformas.length - maxVisible;

      return Row(
        children: [
          Icon(Icons.gamepad, size: 12, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              visiblePlatforms.join(', ') + (remainingCount > 0 ? ' +$remainingCount' : ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF232936),
            const Color(0xFF151921),
          ],
          stops: const [0.0, 1.0],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.07), width: 1),
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
                  child: ClipRRect( 
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                    child: game.imgPrincipal.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: game.imgPrincipal,
                            fit: BoxFit.cover,
                            memCacheWidth: 400, // Optimización de memoria
                            errorWidget: (context, url, error) => Container(color: const Color(0xFF151921), child: const Icon(Icons.broken_image, color: Colors.grey)),
                            placeholder: (context, url) => Container(color: const Color(0xFF151921)),
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
                          // --- PEGI EN LISTA ---
                          if (game.edadRecomendada != null)
                             Padding(
                               padding: const EdgeInsets.only(right: 8.0),
                               child: PegiBadge(age: game.edadRecomendada!, size: 20, showLabel: false),
                             ),
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
                        buildPlatforms(),
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
