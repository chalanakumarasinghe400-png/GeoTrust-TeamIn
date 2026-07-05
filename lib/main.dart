import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'supabase_config.dart';
import 'firebase_options.dart';
import 'models/models.dart';
import 'widgets/empty_state.dart';
import 'db_repository.dart';
import 'supabase_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Request FCM Permissions for push notifications
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();

  runApp(const GeoTrustApp());
}

// =============================================================================
// --- DATA MODELS ---
// =============================================================================

// =============================================================================
// --- STATE MANAGEMENT ---
// =============================================================================

class LedgerService extends ChangeNotifier {
  // --- NEW INVENTORY LOGIC ---
  final DbRepository _repo;
  double yardInventoryCubes = 40.0; // What they currently have in stock
  final double maxYardCapacity =
      100.0; // The max GSMB limit they are allowed to hold

  double currentInventoryCubes = 0.0;
  double currentMaxCapacity = 100.0;

  List<Map<String, dynamic>> userLocations = [];
  Map<String, String> locationIdToName = {};

  List<TransportPermit> mineTransactionHistory = [];
  List<TransportPermit> hardwareTransactionHistory = [];

  double hardwareInventoryCubes = 20.0; // Hardware store inventory

  final List<TransportPermit> _permits = [];

  String? currentLocationId; // Tracks the ID of the user's specific location
  AppUser? currentUser;
  String currentUsername = "";
  UserRole? currentUserRole;
  String? profilePicBase64;
  bool isOffline = false;

  TransportPermit? currentDriverPermit; // Used exclusively for Driver Flow

  List<TransportPermit> get permits => List.unmodifiable(_permits);

  StreamSubscription? _permitSubscription;
  StreamSubscription? _inventorySubscription;
  StreamSubscription? _connectivitySubscription;

  LedgerService({DbRepository? repository})
    : _repo = repository ?? SupabaseRepository() {
    Connectivity().checkConnectivity().then((result) {
      isOffline = result == ConnectivityResult.none;
      notifyListeners();
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      result,
    ) {
      bool offline = result == ConnectivityResult.none;
      if (isOffline != offline) {
        isOffline = offline;
        notifyListeners();
      }
      if (!isOffline) {
        syncOfflineUnloads();
      }
    });
  }

  void subscribeToPermitChanges() {
    if (currentLocationId == null) return;
    _permitSubscription?.cancel();
    _permitSubscription = _repo
        .streamTable(
          'permits',
          primaryKey: 'id',
          eq: {'origin_location_id': currentLocationId!},
        )
        .listen(
          (data) {
            _permits.clear();
            _permits.addAll(
              data.map((row) => TransportPermit.fromJson(row)).toList(),
            );
            _permits.sort((a, b) => b.transportDate.compareTo(a.transportDate));
            notifyListeners();
          },
          onError: (error) {
            print('Permit stream error: $error');
          },
        );
  }

  void subscribeToInventory() {
    if (currentLocationId == null) return;
    _inventorySubscription?.cancel();
    _inventorySubscription = _repo
        .streamTable(
          'locations',
          primaryKey: 'id',
          eq: {'id': currentLocationId!},
        )
        .listen(
          (data) {
            if (data.isNotEmpty) {
              double cubes = (data.first['inventory_cubes'] as num).toDouble();
              if (currentUser?.isMineOwner == true) {
                yardInventoryCubes = cubes;
              } else if (currentUser?.isHardwareOwner == true) {
                hardwareInventoryCubes = cubes;
              }
              currentInventoryCubes = cubes;
              currentMaxCapacity =
                  (data.first['max_capacity'] as num?)?.toDouble() ?? 100.0;
              notifyListeners();
            }
          },
          onError: (error) {
            print('Inventory stream error: $error');
          },
        );
  }

  Future<void> refreshData() async {
    subscribeToPermitChanges();
    subscribeToInventory();
    await syncOfflineUnloads();
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  void dispose() {
    _permitSubscription?.cancel();
    _inventorySubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<bool> loadUserProfile(String userId) async {
    try {
      final profile = await _repo.selectOne('profiles', 'id', userId);

      final locs = await _repo.select(
        'locations',
        filters: {'owner_id': userId},
      );

      // Cache data locally for offline auto-login support
      final prefs = await SharedPreferences.getInstance();
      if (profile != null) {
        await prefs.setString('cached_profile_$userId', jsonEncode(profile));
      }
      if (locs != null) {
        await prefs.setString('cached_locs_$userId', jsonEncode(locs));
      }

      return _applyUserProfile(userId, profile, locs);
    } catch (e) {
      print("Profile Load Error: $e");
      // Fallback to locally cached memory if internet is unavailable
      final prefs = await SharedPreferences.getInstance();
      final cachedProfileStr = prefs.getString('cached_profile_$userId');
      final cachedLocsStr = prefs.getString('cached_locs_$userId');

      if (cachedProfileStr != null && cachedLocsStr != null) {
        try {
          final profile = jsonDecode(cachedProfileStr);
          final locs = jsonDecode(cachedLocsStr);
          return _applyUserProfile(userId, profile, locs);
        } catch (decodeErr) {
          return false;
        }
      }
      return false;
    }
  }

  bool _applyUserProfile(String userId, dynamic profile, dynamic locs) {
    if (profile == null) return false;

    userLocations = List<Map<String, dynamic>>.from(locs ?? []);
    locationIdToName = {
      for (var loc in userLocations)
        loc['id']: loc['name'] ?? 'Unnamed Location',
    };
    if (userLocations.isNotEmpty) {
      currentLocationId = userLocations.first['id'];
    }

    currentUser = AppUser(
      id: userId,
      name: profile['full_name'] ?? 'Unknown',
      isMineOwner: userLocations.any(
        (l) =>
            l['location_type'] == 'MINE' || l['location_type'] == 'MINE_OWNER',
      ),
      isHardwareOwner: userLocations.any(
        (l) =>
            l['location_type'] == 'HARDWARE' ||
            l['location_type'] == 'HARDWARE_OWNER',
      ),
    );

    currentUsername = profile['full_name'] ?? 'Unknown';
    // Load profile photo from the database record
    profilePicBase64 = profile['profile_photo'];

    notifyListeners();
    return true;
  }

  Future<void> updateProfilePicture(String path) async {
    if (currentUser == null) return;

    try {
      final bytes = await File(path).readAsBytes();
      final base64String = base64Encode(bytes);
      profilePicBase64 = base64String;
      notifyListeners();

      // Save to DB via repository
      await _repo.update(
        'profiles',
        {'profile_photo': base64String},
        eqColumn: 'id',
        eqValue: currentUser!.id,
      );

      // Update local cache
      final prefs = await SharedPreferences.getInstance();
      final cachedProfileStr = prefs.getString(
        'cached_profile_${currentUser!.id}',
      );
      if (cachedProfileStr != null) {
        final profile = jsonDecode(cachedProfileStr);
        profile['profile_photo'] = base64String;
        await prefs.setString(
          'cached_profile_${currentUser!.id}',
          jsonEncode(profile),
        );
      }
    } catch (e) {
      print("Error updating profile picture: $e");
    }
  }

  Future<void> removeProfilePicture() async {
    if (currentUser == null) return;
    profilePicBase64 = null;
    notifyListeners();

    try {
      await _repo.update(
        'profiles',
        {'profile_photo': null},
        eqColumn: 'id',
        eqValue: currentUser!.id,
      );
    } catch (e) {
      print("Error removing profile picture: $e");
    }
  }

  Future<bool> loginWithCredentials(String email, String password) async {
    try {
      // Bypassing Supabase Auth: Checking profiles table directly
      final response = await _repo.selectWhereSingle('profiles', {
        'email': email,
        'password': password,
      });

      if (response == null) return false;

      // Save session locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('loggedInUserId', response['id']);

      return await loadUserProfile(response['id']);
    } catch (e) {
      print("Login Error: $e");
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('loggedInUserId');
    await prefs.remove('savedDriverPermit');
    currentUser = null;
    currentLocationId = null;
    currentUserRole = null;
    currentDriverPermit = null;
    notifyListeners();
  }

  // Instantly updates UI values using local cache while waiting for stream latency
  void setLocationAndPreload(String locId, UserRole role) {
    currentLocationId = locId;
    currentUserRole = role;

    final locData = userLocations.firstWhere(
      (l) => l['id'] == locId,
      orElse: () => {},
    );
    if (locData.isNotEmpty) {
      currentInventoryCubes =
          (locData['inventory_cubes'] as num?)?.toDouble() ?? 0.0;
      currentMaxCapacity =
          (locData['max_capacity'] as num?)?.toDouble() ?? 100.0;
    }

    subscribeToPermitChanges();
    subscribeToInventory();
  }

  // --- UPDATED TO RETURN BOOLEAN FOR INVENTORY CHECK ---
  Future<bool> issueNewPermit(
    String vehicle,
    double requestedQty,
    DateTime transportDate,
  ) async {
    if (requestedQty > currentInventoryCubes) {
      return false; // Transaction Failed
    }

    String newPermitId = _generateUuidV4();

    final newPermit = TransportPermit(
      id: newPermitId,
      truckNumber: vehicle,
      volumeCubes: requestedQty,
      transportDate: transportDate,
      expirationDate: transportDate.add(const Duration(days: 14)),
    );

    try {
      await _repo.insert(
        'permits',
        newPermit.toJson()..addAll({'origin_location_id': currentLocationId}),
      );
      await _repo.update(
        'locations',
        {'inventory_cubes': currentInventoryCubes - requestedQty},
        eqColumn: 'id',
        eqValue: currentLocationId!,
      );
      return true; // Transaction Success
    } catch (e) {
      print("Error issuing permit: $e");
      return false;
    }
  }

  // --- MINE OWNER: DONE LOADING (Generates Code) ---
  Future<void> activatePermitAndGenerateCode(String permitId) async {
    final String generatedCode = (100000 + Random().nextInt(900000)).toString();
    try {
      await _repo.update(
        'permits',
        {
          'status': PermitStatus.active.name.toUpperCase(),
          'permit_code': generatedCode,
        },
        eqColumn: 'id',
        eqValue: permitId,
      );
    } catch (e) {
      print("Error activating permit: $e");
    }
  }

  Future<void> fetchTransactionHistory() async {
    if (currentUser == null) return;

    mineTransactionHistory.clear();
    hardwareTransactionHistory.clear();

    final locationIds = userLocations
        .map((loc) => loc['id'] as String)
        .toList();
    if (locationIds.isEmpty) {
      notifyListeners();
      return;
    }

    try {
      // Corrected PostgREST OR filter formatting
      final allHistory = (await _repo.getPermitsByOriginIdsAndStatus(
        locationIds,
        'COMPLETED',
      )).map((json) => TransportPermit.fromJson(json)).toList();

      for (final permit in allHistory) {
        final location = userLocations.firstWhere(
          (loc) => loc['id'] == permit.originLocationId,
          orElse: () => {},
        );
        if (location.isNotEmpty) {
          final type = location['location_type'];
          if (type == 'MINE' || type == 'MINE_OWNER') {
            mineTransactionHistory.add(permit);
          } else {
            hardwareTransactionHistory.add(permit);
          }
        }
      }

      mineTransactionHistory.sort(
        (a, b) => b.transportDate.compareTo(a.transportDate),
      );
      hardwareTransactionHistory.sort(
        (a, b) => b.transportDate.compareTo(a.transportDate),
      );
      notifyListeners();
    } catch (e) {
      print("Error fetching transaction history: $e");
    }
  }

  // --- DRIVER HANDSHAKE LOGIC ---
  Future<void> driverLoginWithCode(String code) async {
    try {
      final response = await _repo.selectWhereSingle('permits', {
        'permit_code': code,
      });

      if (response == null) throw Exception("Invalid Code.");

      final permit = TransportPermit.fromJson(response);

      if (permit.status == PermitStatus.cancelled) {
        throw Exception("This permit has been cancelled.");
      }

      Position position = await _determinePosition();
      print("Driver Origin GPS: ${position.latitude}, ${position.longitude}");

      final originLocation = await _repo.selectOne(
        'locations',
        'id',
        permit.originLocationId!,
        columns: ['latitude', 'longitude'],
      );

      if (originLocation != null &&
          originLocation['latitude'] != null &&
          originLocation['longitude'] != null) {
        final double mineLat = (originLocation['latitude'] as num).toDouble();
        final double mineLng = (originLocation['longitude'] as num).toDouble();

        double distanceInMeters = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          mineLat,
          mineLng,
        );

        // 500 meters is the standard permissible range for industrial quarry applications
        if (distanceInMeters > 500) {
          throw Exception(
            "Location verification failed. You are not at the origin mine (Distance: ${distanceInMeters.toStringAsFixed(0)}m).",
          );
        }
      } else {
        throw Exception("Origin location GPS coordinates not found.");
      }

      // Update expiration to exactly 12 hours from now for the active journey
      final newExpiry = DateTime.now().add(const Duration(hours: 12));
      permit.expirationDate = newExpiry;

      await _repo.update(
        'permits',
        {'expiration_date': newExpiry.toIso8601String()},
        eqColumn: 'id',
        eqValue: permit.id,
      );

      currentDriverPermit = permit;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'savedDriverPermit',
        jsonEncode(currentDriverPermit!.toJson()),
      );

      currentUserRole = UserRole.driver;
      notifyListeners();
    } catch (e) {
      print("Driver Login Error: $e");
      rethrow;
    }
  }

  Future<void> cancelExpiredDriverPermit() async {
    if (currentDriverPermit != null) {
      try {
        await _repo.update(
          'permits',
          {'status': PermitStatus.cancelled.name.toUpperCase()},
          eqColumn: 'id',
          eqValue: currentDriverPermit!.id,
        );
      } catch (e) {
        print("Failed to cancel permit on server: $e");
      }
      currentDriverPermit = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('savedDriverPermit');
      notifyListeners();
    }
  }

  Future<void> driverUnloadDestination(XFile photoFile) async {
    if (currentDriverPermit == null) return;

    try {
      Position position = await _determinePosition();
      print(
        "Driver Destination GPS captured: ${position.latitude}, ${position.longitude}",
      );

      String photoUrl = "";
      try {
        final bytes = await photoFile.readAsBytes();
        final path =
            'audits/${currentDriverPermit!.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _repo.uploadBinary(
          'verifications',
          path,
          bytes,
          contentType: 'image/jpeg',
        );
        photoUrl = _repo.getPublicUrl('verifications', path);
      } catch (e) {
        print("Photo upload skipped (offline or bucket missing): $e");
      }

      final payload = <String, dynamic>{
        'status': PermitStatus.completed.name.toUpperCase(),
        'unload_latitude': position.latitude,
        'unload_longitude': position.longitude,
        'unloaded_at': DateTime.now().toIso8601String(),
      };

      if (photoUrl.isNotEmpty) {
        payload['photo_url'] = photoUrl;
      }

      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        // OFFLINE QUEUE
        final prefs = await SharedPreferences.getInstance();
        List<String> offlineQueue =
            (prefs.getStringList('offline_unloads') ?? []).toList();
        offlineQueue.add(
          jsonEncode({'permit_id': currentDriverPermit!.id, ...payload}),
        );
        await prefs.setStringList('offline_unloads', offlineQueue);
      } else {
        // ONLINE SYNC
        await _repo.update(
          'permits',
          payload,
          eqColumn: 'id',
          eqValue: currentDriverPermit!.id,
        );

        // Detect if unloaded at a known Hardware Store (within ~1km radius)
        final hardwares = await _repo.getLocationsByType('HARDWARE_OWNER');
        for (var hw in hardwares) {
          final double hwLat = (hw['latitude'] as num).toDouble();
          final double hwLng = (hw['longitude'] as num).toDouble();

          if ((hwLat - position.latitude).abs() < 0.05 &&
              (hwLng - position.longitude).abs() < 0.05) {
            await _repo.update(
              'locations',
              {
                'inventory_cubes':
                    hw['inventory_cubes'] + currentDriverPermit!.volumeCubes,
              },
              eqColumn: 'id',
              eqValue: hw['id'],
            );
            break;
          }
        }
      }

      currentDriverPermit = null;
      final prefs2 = await SharedPreferences.getInstance();
      await prefs2.remove('savedDriverPermit');
      notifyListeners();
    } catch (e) {
      print("Error completing journey: $e");
    }
  }

  Future<void> syncOfflineUnloads() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> offlineQueue = prefs.getStringList('offline_unloads') ?? [];
    if (offlineQueue.isEmpty) return;

    List<String> pendingQueue = [];
    for (String data in offlineQueue) {
      try {
        // Safely cast dynamic JSON to a Map
        final Map<String, dynamic> payload = Map<String, dynamic>.from(
          jsonDecode(data) as Map,
        );
        final permitId = payload.remove('permit_id');
        await _repo.update(
          'permits',
          payload,
          eqColumn: 'id',
          eqValue: permitId,
        );
      } catch (e) {
        pendingQueue.add(data);
      }
    }
    await prefs.setStringList('offline_unloads', pendingQueue);
  }

  // --- HARDWARE OWNER: MINI PERMIT LOGIC ---
  Future<bool> issueMiniPermit(
    String vehicle,
    double requestedQty,
    DateTime transportDate,
  ) async {
    if (requestedQty >= 5.0 || requestedQty > currentInventoryCubes) {
      return false;
    }

    String newPermitId = _generateUuidV4();

    final newPermit = TransportPermit(
      id: newPermitId,
      truckNumber: vehicle,
      volumeCubes: requestedQty,
      transportDate: transportDate,
      expirationDate: transportDate.add(const Duration(days: 14)),
    );

    try {
      await _repo.insert(
        'permits',
        newPermit.toJson()..addAll({'origin_location_id': currentLocationId}),
      );
      await _repo.update(
        'locations',
        {'inventory_cubes': currentInventoryCubes - requestedQty},
        eqColumn: 'id',
        eqValue: currentLocationId!,
      );
      notifyListeners();
      return true;
    } catch (e) {
      print("Error issuing mini permit: $e");
      return false;
    }
  }

  // Helper for GPS
  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Fallback or error
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    }

    return await Geolocator.getCurrentPosition();
  }

  // Helper to generate UUIDs for the new permits table
  String _generateUuidV4() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant 1
    final chars = bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .toList();
    return '${chars.sublist(0, 4).join()}-${chars.sublist(4, 6).join()}-${chars.sublist(6, 8).join()}-${chars.sublist(8, 10).join()}-${chars.sublist(10, 16).join()}';
  }
}

// =============================================================================
// --- FLUTTER UI LAYER ---
// =============================================================================

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDark') ?? false;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', isDark);
    notifyListeners();
  }
}

class GeoTrustApp extends StatelessWidget {
  const GeoTrustApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LedgerService()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'GeoTrust Transport',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.teal,
                brightness: Brightness.light,
              ),
              listTileTheme: ListTileThemeData(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.teal,
                brightness: Brightness.dark,
              ),
              listTileTheme: ListTileThemeData(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            home: const LoginScreen(),
            builder: (context, child) {
              final isOffline = context.watch<LedgerService>().isOffline;
              return Stack(
                children: [
                  if (child != null) child,
                  if (isOffline)
                    Positioned(
                      top: 0,
                      right: 60,
                      child: SafeArea(
                        child: Material(
                          color: Colors.transparent,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.wifi_off,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _driverCodeController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final savedUserId = prefs.getString('loggedInUserId');
    final savedPermitStr = prefs.getString('savedDriverPermit');

    final ledger = context.read<LedgerService>();

    if (savedUserId != null) {
      bool success = await ledger.loadUserProfile(savedUserId);
      if (success && mounted) {
        ledger.subscribeToPermitChanges();
        if (ledger.currentUser?.isMineOwner == true ||
            ledger.currentUser?.isHardwareOwner == true) {
          ledger.subscribeToInventory();
        }
        ledger.syncOfflineUnloads();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RolePortalScreen()),
        );
        return;
      }
    } else if (savedPermitStr != null) {
      try {
        ledger.currentDriverPermit = TransportPermit.fromJson(
          jsonDecode(savedPermitStr),
        );
        ledger.currentUserRole = UserRole.driver;
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DriverScreen()),
          );
          return;
        }
      } catch (e) {
        print("Failed to load saved permit: $e");
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final ledger = context.read<LedgerService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 40, bottom: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [Colors.teal.shade900, Colors.teal.shade700]
                      : [Colors.teal.shade700, Colors.teal.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.route, size: 48, color: Colors.white),
                    const SizedBox(height: 8),
                    const Text(
                      "GeoTrust Transport",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const TabBar(
                      indicatorColor: Colors.white,
                      indicatorWeight: 3,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white60,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      tabs: [
                        Tab(text: "Owner Login", icon: Icon(Icons.business)),
                        Tab(
                          text: "Driver Access",
                          icon: Icon(Icons.local_shipping),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // TAB 1: OWNER LOGIN
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 450),
                        child: Card(
                          elevation: 6,
                          shadowColor: Colors.black26,
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.admin_panel_settings,
                                  size: 56,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  "Owner Portal",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 24,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Enter your credentials to manage inventory and logistics.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                TextField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    labelText: 'Email Address',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    prefixIcon: const Icon(Icons.email),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    prefixIcon: const Icon(Icons.lock),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                if (_isLoading)
                                  const SizedBox(
                                    height: 56,
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                else
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: FilledButton(
                                      style: FilledButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      onPressed: () async {
                                        setState(() => _isLoading = true);
                                        bool success = await ledger
                                            .loginWithCredentials(
                                              _emailController.text,
                                              _passwordController.text,
                                            );
                                        if (mounted)
                                          setState(() => _isLoading = false);
                                        if (success && mounted) {
                                          ledger.subscribeToPermitChanges();
                                          if (ledger.currentUser?.isMineOwner ==
                                                  true ||
                                              ledger
                                                      .currentUser
                                                      ?.isHardwareOwner ==
                                                  true) {
                                            ledger.subscribeToInventory();
                                          }
                                          ledger.syncOfflineUnloads();
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const RolePortalScreen(),
                                            ),
                                          );
                                        } else if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                "Invalid Email or Password.",
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      },
                                      child: const Text(
                                        "LOGIN",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // TAB 2: DRIVER ACCESS
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 450),
                        child: Card(
                          elevation: 6,
                          shadowColor: Colors.black26,
                          color: isDark
                              ? Colors.blue.shade900.withOpacity(0.3)
                              : Colors.blue.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.local_shipping,
                                  size: 56,
                                  color: Colors.blue,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  "Active Transport Duty",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 24,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Enter your dispatch code to begin the journey.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                TextField(
                                  controller: _driverCodeController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Enter 6-Digit Permit Code',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    prefixIcon: const Icon(Icons.qr_code),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.blue.shade700,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: () async {
                                      setState(() => _isLoading = true);
                                      try {
                                        await ledger.driverLoginWithCode(
                                          _driverCodeController.text,
                                        );
                                        if (mounted)
                                          setState(() => _isLoading = false);
                                        if (mounted) {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const DriverScreen(),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted)
                                          setState(() => _isLoading = false);
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                e.toString().replaceAll(
                                                  'Exception: ',
                                                  '',
                                                ),
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.location_on),
                                    label: const Text(
                                      "VERIFY GPS & ENTER",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RolePortalScreen extends StatefulWidget {
  const RolePortalScreen({super.key});

  @override
  State<RolePortalScreen> createState() => _RolePortalScreenState();
}

class _RolePortalScreenState extends State<RolePortalScreen> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerService>();
    final user = ledger.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Not Logged In")));
    }

    var mines = ledger.userLocations
        .where(
          (loc) =>
              loc['location_type'] == 'MINE' ||
              loc['location_type'] == 'MINE_OWNER',
        )
        .toList();
    var hardwares = ledger.userLocations
        .where(
          (loc) =>
              loc['location_type'] != 'MINE' &&
              loc['location_type'] != 'MINE_OWNER',
        )
        .toList();

    if (_searchQuery.isNotEmpty) {
      mines = mines
          .where(
            (m) => (m['name'] ?? 'Mine').toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ),
          )
          .toList();
      hardwares = hardwares
          .where(
            (h) => (h['name'] ?? 'Hardware').toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ),
          )
          .toList();
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 75,
          title: Text(
            "Welcome ${user.name}!",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  blurRadius: 1.0,
                  color: Colors.black38,
                  offset: Offset(0.5, 0.5),
                ),
              ],
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(110),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: "Search locations...",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black26
                          : Colors.white.withOpacity(0.8),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                ),
                const TabBar(
                  tabs: [
                    Tab(text: "Mines", icon: Icon(Icons.landscape)),
                    Tab(text: "Hardwares", icon: Icon(Icons.store)),
                  ],
                ),
              ],
            ),
          ),
        ),
        drawer: const AppDrawer(),
        body: TabBarView(
          children: [
            _buildLocationList(context, ledger, mines, true),
            _buildLocationList(context, ledger, hardwares, false),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationList(
    BuildContext context,
    LedgerService ledger,
    List<Map<String, dynamic>> locations,
    bool isMine,
  ) {
    if (locations.isEmpty) {
      return EmptyState(
        icon: isMine ? Icons.landscape_outlined : Icons.store_outlined,
        message: isMine
            ? "No mines assigned to your account."
            : "No hardware stores assigned to your account.",
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: locations.length,
      itemBuilder: (context, index) {
        final loc = locations[index];
        final title =
            loc['name'] ??
            (isMine ? "Yard Manager (Mine)" : "Hardware Store (Buyer)");
        final double inventory =
            (loc['inventory_cubes'] as num?)?.toDouble() ?? 0.0;
        final bool isQuotaOver = isMine && inventory <= 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _buildPortalCard(
            context: context,
            ledger: ledger,
            title: title,
            icon: isMine ? Icons.landscape : Icons.store,
            color: isMine ? Colors.orange : Colors.purple,
            destination: isMine
                ? MineOwnerScreen(locationName: title)
                : HardwareOwnerScreen(locationName: title),
            role: isMine ? UserRole.mineOwner : UserRole.hardwareOwner,
            locationId: loc['id'],
            showRedDot: isQuotaOver,
          ),
        );
      },
    );
  }

  Widget _buildPortalCard({
    required BuildContext context,
    required LedgerService ledger,
    required String title,
    required IconData icon,
    required MaterialColor color,
    required Widget destination,
    required UserRole role,
    required String locationId,
    required bool showRedDot,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: isDark ? 0 : 6,
      shadowColor: isDark ? Colors.transparent : color.withOpacity(0.4),
      color: isDark ? color.withOpacity(0.15) : color.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: isDark
            ? BorderSide(color: color.shade400.withOpacity(0.6), width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          ledger.setLocationAndPreload(locationId, role);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => destination),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: isDark ? color.shade400 : color,
                    child: Icon(icon, color: Colors.white, size: 48),
                  ),
                  if (showRedDot)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: isDark ? Colors.white : color.shade900,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Tap to manage location",
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? color.shade200 : color.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 1. YARD MANAGER (MINE OWNER) ---
class MineOwnerScreen extends StatelessWidget {
  final String locationName;
  const MineOwnerScreen({super.key, required this.locationName});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(locationName),
          actions: [
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const RolePortalScreen()),
                (route) => false,
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: "Remaining", icon: Icon(Icons.inventory)),
              Tab(text: "On going", icon: Icon(Icons.local_shipping)),
            ],
          ),
        ),
        drawer: const AppDrawer(),
        body: const TabBarView(children: [_RemainingPanel(), _OngoingPanel()]),
      ),
    );
  }
}

class _RemainingPanel extends StatefulWidget {
  const _RemainingPanel();

  @override
  State<_RemainingPanel> createState() => _RemainingPanelState();
}

class _RemainingPanelState extends State<_RemainingPanel> {
  final vehicleCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;

  @override
  void dispose() {
    vehicleCtrl.dispose();
    qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerService>();
    final ongoingPermits = ledger.permits
        .where((p) => p.status != PermitStatus.completed)
        .toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RefreshIndicator(
      onRefresh: ledger.refreshData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    "Mine Inventory Status",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value:
                        ledger.currentInventoryCubes /
                        ledger.currentMaxCapacity,
                    minHeight: 12,
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor: Colors.grey.shade300,
                    color: ledger.currentInventoryCubes < 10
                        ? Colors.red
                        : Colors.green, // Turns red if low
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${ledger.currentInventoryCubes} / ${ledger.currentMaxCapacity} Cubes Available",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: ledger.currentInventoryCubes < 10
                          ? (isDark ? Colors.red.shade300 : Colors.red.shade700)
                          : Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Draft New License",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  _buildLicenseForm(ledger),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLicenseForm(LedgerService ledger) {
    return Column(
      children: [
        TextField(
          controller: vehicleCtrl,
          decoration: InputDecoration(
            labelText: "Transport Truck No. (e.g. WP LA-1234)",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            prefixIcon: const Icon(Icons.local_shipping),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: qtyCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: "Number of Cubes",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            prefixIcon: const Icon(Icons.layers),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                "Transport Date: ${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}",
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final initial = _selectedDate.isBefore(today)
                    ? today
                    : _selectedDate;

                final picked = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: today,
                  lastDate: today.add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
              icon: const Icon(Icons.calendar_today),
              label: const Text("Change"),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isSubmitting
                ? null
                : () async {
                    if (vehicleCtrl.text.trim().isEmpty ||
                        qtyCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Please enter vehicle number and quantity.",
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    double qty = double.tryParse(qtyCtrl.text) ?? 0.0;
                    if (qty <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Quantity must be greater than zero."),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    setState(() => _isSubmitting = true);
                    bool success = await ledger.issueNewPermit(
                      vehicleCtrl.text,
                      qty,
                      _selectedDate,
                    );
                    if (mounted) setState(() => _isSubmitting = false);
                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Draft Permit Created!"),
                          backgroundColor: Colors.green,
                        ),
                      );
                      vehicleCtrl.clear();
                      qtyCtrl.clear();
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("ERROR: Insufficient Quota!"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
            icon: const Icon(Icons.save),
            label: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text("SAVE DRAFT LICENSE"),
          ),
        ),
      ],
    );
  }
}

class _OngoingPanel extends StatelessWidget {
  const _OngoingPanel();

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ongoingPermits = ledger.permits
        .where((p) => p.status != PermitStatus.completed)
        .toList();

    if (ongoingPermits.isEmpty) {
      return const EmptyState(
        icon: Icons.local_shipping_outlined,
        message: "No active or draft permits.",
      );
    }

    return RefreshIndicator(
      onRefresh: ledger.refreshData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Active & Draft Permits",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...ongoingPermits.map(
            (permit) => _buildManagerCard(context, ledger, permit),
          ),
        ],
      ),
    );
  }

  Widget _buildManagerCard(
    BuildContext context,
    LedgerService ledger,
    TransportPermit permit,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "ID: ${permit.id.length >= 8 ? permit.id.substring(0, 8).toUpperCase() : permit.id.toUpperCase()}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                _buildStatusChip(permit.status),
              ],
            ),
            const Divider(),
            Text(
              "Vehicle: ${permit.truckNumber} | ${permit.volumeCubes} Cubes",
            ),
            if (permit.permitCode != null)
              Text(
                "Driver Access Code: ${permit.permitCode}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            const SizedBox(height: 8),
            if (permit.status == PermitStatus.pending)
              FilledButton.icon(
                onPressed: () {
                  ledger.activatePermitAndGenerateCode(permit.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Truck Dispatched! Give code to driver."),
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle),
                label: const Text("DONE LOADING (DISPATCH)"),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- 2. TRANSPORTER (DRIVER) ---
class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key});

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  bool _isUnloading = false;
  Timer? _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ledger = context.read<LedgerService>();
      final permit = ledger.currentDriverPermit;
      if (permit != null) {
        _updateTimeLeft(permit.expirationDate);
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          _updateTimeLeft(permit.expirationDate);
        });
      }
    });
  }

  void _updateTimeLeft(DateTime expiry) {
    final now = DateTime.now();
    if (now.isAfter(expiry)) {
      _timer?.cancel();
      _cancelPermit();
    } else {
      if (mounted) {
        setState(() {
          _timeLeft = expiry.difference(now);
        });
      }
    }
  }

  Future<void> _cancelPermit() async {
    final ledger = context.read<LedgerService>();
    await ledger.cancelExpiredDriverPermit();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Permit Expired and Cancelled!"),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerService>();
    final activePermit = ledger.currentDriverPermit;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Transporter Dashboard"),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (activePermit != null) ...[
              const Text(
                "ACTIVE JOURNEY",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade400, width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer, color: Colors.red, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      "EXPIRES IN: ${_timeLeft.inHours.toString().padLeft(2, '0')}:${(_timeLeft.inMinutes % 60).toString().padLeft(2, '0')}:${(_timeLeft.inSeconds % 60).toString().padLeft(2, '0')}",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(child: PermitCard(permit: activePermit, isLarge: true)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isUnloading
                    ? null
                    : () async {
                        setState(() => _isUnloading = true);
                        final picker = ImagePicker();
                        // Compress image to save bandwidth and storage
                        final photo = await picker.pickImage(
                          source: ImageSource.camera,
                          imageQuality: 60,
                          maxWidth: 1080,
                        );
                        if (photo != null) {
                          await ledger.driverUnloadDestination(photo);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Unloaded! Photo & GPS Logged."),
                              ),
                            );
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          }
                        }
                        if (mounted) setState(() => _isUnloading = false);
                      },
                icon: const Icon(Icons.download, size: 28),
                label: _isUnloading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          "UNLOAD AT DESTINATION",
                          style: TextStyle(fontSize: 15),
                        ),
                      ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blue.shade800,
                ),
              ),
            ],

            if (activePermit == null)
              Column(
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 100,
                    color: Colors.green,
                  ),
                  const Text(
                    "Journey Completed.",
                    style: TextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                    child: const Text("Return to Home"),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// --- 3. HARDWARE OWNER (BUYER) ---
class HardwareOwnerScreen extends StatelessWidget {
  final String locationName;
  const HardwareOwnerScreen({super.key, required this.locationName});

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(locationName),
          backgroundColor: isDark
              ? Colors.purple.shade900
              : UserRole.hardwareOwner.color,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const RolePortalScreen()),
                (route) => false,
              ),
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "Inventory", icon: Icon(Icons.inventory_2)),
              Tab(text: "Transports", icon: Icon(Icons.local_shipping)),
            ],
          ),
        ),
        drawer: const AppDrawer(),
        body: const TabBarView(
          children: [_HardwareInventoryPanel(), _HardwareOngoingPanel()],
        ),
      ),
    );
  }
}

class _HardwareInventoryPanel extends StatelessWidget {
  const _HardwareInventoryPanel();
  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RefreshIndicator(
      onRefresh: ledger.refreshData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: isDark ? Colors.purple.shade800 : Colors.purple,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Icon(Icons.inventory_2, size: 56, color: Colors.white),
                  const SizedBox(height: 8),
                  const Text(
                    "Current Sand Inventory",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    "${ledger.currentInventoryCubes} Cubes",
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showAssignMiniPermit(context, ledger),
            icon: const Icon(Icons.home_work),
            label: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("ASSIGN TRANSPORTATION TO HOME (< 5 CUBES)"),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.purple.shade800,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showAssignMiniPermit(BuildContext screenContext, LedgerService ledger) {
    final vehicleCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    showDialog(
      context: screenContext,
      builder: (dialogContext) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (stateContext, setState) {
            return AlertDialog(
              title: const Text("Mini-Permit Assignment"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: vehicleCtrl,
                    decoration: InputDecoration(
                      labelText: "Truck Registration",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Quantity (< 5)",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                  ),
                ],
              ),
              actions: [
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (vehicleCtrl.text.trim().isEmpty ||
                              qtyCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text("Please fill all fields."),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }
                          double qty = double.tryParse(qtyCtrl.text) ?? 0.0;
                          if (qty <= 0) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Quantity must be greater than zero.",
                                ),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }
                          setState(() => isSubmitting = true);
                          bool success = await ledger.issueMiniPermit(
                            vehicleCtrl.text,
                            qty,
                            DateTime.now(),
                          );
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          if (success && screenContext.mounted) {
                            ScaffoldMessenger.of(screenContext).showSnackBar(
                              const SnackBar(
                                content: Text("Mini Permit Issued!"),
                              ),
                            );
                          } else if (screenContext.mounted) {
                            ScaffoldMessenger.of(screenContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Error: Must be < 5 cubes & within inventory!",
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("ISSUE"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _HardwareOngoingPanel extends StatelessWidget {
  const _HardwareOngoingPanel();

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerService>();
    final ongoingPermits = ledger.permits
        .where((p) => p.status != PermitStatus.completed)
        .toList();

    if (ongoingPermits.isEmpty) {
      return const EmptyState(
        icon: Icons.fire_truck_outlined,
        message: "No ongoing mini-permits.",
      );
    }

    return RefreshIndicator(
      onRefresh: ledger.refreshData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Ongoing Mini-Permits",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...ongoingPermits.map(
            (permit) => _buildHardwareManagerCard(context, ledger, permit),
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareManagerCard(
    BuildContext context,
    LedgerService ledger,
    TransportPermit permit,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "ID: ${permit.id.length >= 8 ? permit.id.substring(0, 8).toUpperCase() : permit.id.toUpperCase()}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                _buildStatusChip(permit.status),
              ],
            ),
            const Divider(),
            Text(
              "Vehicle: ${permit.truckNumber} | ${permit.volumeCubes} Cubes",
            ),
            if (permit.permitCode != null)
              Text(
                "Driver Access Code: ${permit.permitCode}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
            const SizedBox(height: 8),
            if (permit.status == PermitStatus.pending)
              FilledButton.icon(
                onPressed: () {
                  ledger.activatePermitAndGenerateCode(permit.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Transport Dispatched!")),
                  );
                },
                icon: const Icon(Icons.local_shipping),
                label: const Text("DISPATCH TO BUYER"),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.purple.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- REUSABLE WIDGETS ---
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});
  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerService>();
    final themeProvider = context.watch<ThemeProvider>();
    final role = ledger.currentUserRole;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + 24,
              16,
              24,
            ),
            decoration: BoxDecoration(
              color: role != null
                  ? (Theme.of(context).brightness == Brightness.dark
                        ? role.color.shade800
                        : role.color)
                  : (Theme.of(context).brightness == Brightness.dark
                        ? Colors.teal.shade800
                        : Colors.teal),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Profile Photo"),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.photo_library),
                              title: const Text("Change Photo"),
                              onTap: () async {
                                Navigator.pop(ctx);
                                final picker = ImagePicker();
                                final photo = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality:
                                      30, // Compressed to fit nicely in DB
                                  maxWidth: 400,
                                );
                                if (photo != null) {
                                  ledger.updateProfilePicture(photo.path);
                                }
                              },
                            ),
                            ListTile(
                              leading: const Icon(
                                Icons.delete,
                                color: Colors.red,
                              ),
                              title: const Text(
                                "Remove Photo",
                                style: TextStyle(color: Colors.red),
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                ledger.removeProfilePicture();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: ledger.profilePicBase64 != null
                      ? CircleAvatar(
                          radius: 40,
                          backgroundImage: MemoryImage(
                            base64Decode(ledger.profilePicBase64!),
                          ),
                        )
                      : const Icon(
                          Icons.account_circle,
                          size: 80,
                          color: Colors.white,
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  ledger.currentUsername.isEmpty
                      ? "Guest"
                      : ledger.currentUsername,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    color: Colors.white,
                  ),
                ),
                if (role != null)
                  Text(
                    role.displayName,
                    style: const TextStyle(color: Colors.white70),
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
            child: Text(
              "FAST DASHBOARD SWITCH",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (ledger.userLocations.isNotEmpty)
            ...ledger.userLocations.map((loc) {
              bool isMine =
                  loc['location_type'] == 'MINE' ||
                  loc['location_type'] == 'MINE_OWNER';
              final title = loc['name'] ?? (isMine ? "Mine" : "Hardware");
              return _buildSwitchTile(
                context,
                ledger,
                title,
                isMine ? UserRole.mineOwner : UserRole.hardwareOwner,
                isMine
                    ? MineOwnerScreen(locationName: title)
                    : HardwareOwnerScreen(locationName: title),
                loc['id'],
              );
            }),
          const Divider(),
          if (ledger.currentUser?.isMineOwner == true ||
              ledger.currentUser?.isHardwareOwner == true)
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text("Transaction History"),
              onTap: () {
                Navigator.pop(context); // Close Drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                );
              },
            ),
          SwitchListTile(
            title: const Text("Dark Mode"),
            secondary: const Icon(Icons.dark_mode),
            value: themeProvider.themeMode == ThemeMode.dark,
            onChanged: (val) => themeProvider.toggleTheme(val),
          ),
          ListTile(
            leading: const Icon(Icons.password),
            title: const Text("Change Password"),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text("About GeoTrust"),
            onTap: () => _showAboutDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.contact_support),
            title: const Text("Contact Support"),
            onTap: () => _showContactDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              "Logout User",
              style: TextStyle(color: Colors.red),
            ),
            onTap: () {
              ledger.logout(); // Erase the saved login state
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (r) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context,
    LedgerService ledger,
    String title,
    UserRole targetRole,
    Widget destination,
    String locationId,
  ) {
    final isActive = ledger.currentLocationId == locationId;
    return ListTile(
      leading: Icon(
        targetRole.icon,
        color: isActive ? targetRole.color : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          color: isActive ? targetRole.color : null,
        ),
      ),
      trailing: isActive
          ? const Icon(Icons.check_circle, color: Colors.green, size: 16)
          : null,
      onTap: () {
        if (!isActive) {
          ledger.setLocationAndPreload(locationId, targetRole);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => destination),
          );
        } else {
          Navigator.pop(context);
        }
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.route, color: Colors.green),
            SizedBox(width: 8),
            Text("About GeoTrust"),
          ],
        ),
        content: const Text(
          "GeoTrust Transport is a modern double-handshake logistics system designed to facilitate material transport using GPS technologies.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CLOSE"),
          ),
        ],
      ),
    );
  }

  void _showContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Contact Support"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Email: support@geotrust.com"),
            SizedBox(height: 8),
            Text("Phone: +94 77 123 4567"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CLOSE"),
          ),
        ],
      ),
    );
  }
}

// --- 5. HISTORY SCREEN ---
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch history when the screen is first loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LedgerService>().fetchTransactionHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LedgerService>(
      builder: (context, ledger, child) {
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text("Transaction History"),
              bottom: const TabBar(
                tabs: [
                  Tab(text: "From Mines", icon: Icon(Icons.landscape)),
                  Tab(text: "From Hardwares", icon: Icon(Icons.store)),
                ],
              ),
            ),
            body: RefreshIndicator(
              onRefresh: ledger.fetchTransactionHistory,
              child: TabBarView(
                children: [
                  _buildHistoryList(
                    ledger,
                    ledger.mineTransactionHistory,
                    "No completed transactions from mines.",
                  ),
                  _buildHistoryList(
                    ledger,
                    ledger.hardwareTransactionHistory,
                    "No completed transactions from hardware stores.",
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryList(
    LedgerService ledger,
    List<TransportPermit> history,
    String emptyMessage,
  ) {
    if (history.isEmpty) {
      return EmptyState(icon: Icons.history_edu, message: emptyMessage);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final permit = history[index];
        final locationName =
            ledger.locationIdToName[permit.originLocationId] ??
            'Unknown Location';
        return PermitCard(permit: permit, locationName: locationName);
      },
    );
  }
}

class PermitCard extends StatelessWidget {
  final TransportPermit permit;
  final bool isLarge;
  final String? locationName;
  const PermitCard({
    super.key,
    required this.permit,
    this.isLarge = false,
    this.locationName,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _getColor(permit.status), width: 2),
      ),
      child: Padding(
        padding: EdgeInsets.all(isLarge ? 24.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: isLarge
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    "PERMIT ID: ${permit.id.length >= 8 ? permit.id.substring(0, 8).toUpperCase() : permit.id.toUpperCase()}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isLarge ? 24 : 18,
                    ),
                  ),
                ),
                _buildStatusChip(permit.status, isLarge: isLarge),
              ],
            ),
            if (isLarge) const SizedBox(height: 24) else const Divider(),
            if (locationName != null) ...[
              Text(
                "From: $locationName",
                style: TextStyle(
                  fontSize: isLarge ? 18 : 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              "Vehicle: ${permit.truckNumber} | ${permit.volumeCubes} Cubes",
              style: TextStyle(fontSize: isLarge ? 22 : 14),
            ),
            if (isLarge) const SizedBox(height: 24) else const Divider(),
            Text(
              "Expires: ${permit.expirationDate.year}-${permit.expirationDate.month.toString().padLeft(2, '0')}-${permit.expirationDate.day.toString().padLeft(2, '0')} ${permit.expirationDate.hour.toString().padLeft(2, '0')}:${permit.expirationDate.minute.toString().padLeft(2, '0')}",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: isLarge ? 20 : 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getColor(PermitStatus status) {
    switch (status) {
      case PermitStatus.pending:
        return Colors.orange;
      case PermitStatus.active:
        return Colors.green;
      case PermitStatus.completed:
        return Colors.grey;
      case PermitStatus.cancelled:
        return Colors.red;
    }
  }
}

Widget _buildStatusChip(PermitStatus status, {bool isLarge = false}) {
  String text = "";
  Color color = Colors.grey;
  if (status == PermitStatus.pending) {
    text = "DRAFT";
    color = Colors.amber;
  } else if (status == PermitStatus.active) {
    text = "ACTIVE";
    color = Colors.green;
  } else if (status == PermitStatus.completed) {
    text = "COMPLETED";
    color = Colors.grey;
  } else if (status == PermitStatus.cancelled) {
    text = "CANCELLED";
    color = Colors.red;
  }

  return Chip(
    label: Text(
      text,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: isLarge ? 16 : 12,
      ),
    ),
    backgroundColor: color,
    padding: isLarge
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
        : EdgeInsets.zero,
  );
}

// --- 6. CHANGE PASSWORD SCREEN ---
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _isUpdating = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerService>();

    return Scaffold(
      appBar: AppBar(title: const Text("Change Password")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _currentPasswordCtrl,
              obscureText: _obscureCurrent,
              decoration: InputDecoration(
                labelText: "Current Password",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureCurrent ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPasswordCtrl,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: "New Password",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNew ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordCtrl,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: "Confirm New Password",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                prefixIcon: const Icon(Icons.lock_reset),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isUpdating
                  ? null
                  : () async {
                      if (_currentPasswordCtrl.text.isEmpty ||
                          _newPasswordCtrl.text.isEmpty ||
                          _confirmPasswordCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Please fill all fields."),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      if (_newPasswordCtrl.text != _confirmPasswordCtrl.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("New passwords do not match."),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      if (_newPasswordCtrl.text.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Password must be at least 6 characters.",
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setState(() => _isUpdating = true);
                      try {
                        final response = await Supabase.instance.client
                            .from('profiles')
                            .select('password')
                            .eq('id', ledger.currentUser!.id)
                            .maybeSingle();
                        if (response == null ||
                            response['password'] != _currentPasswordCtrl.text) {
                          if (mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Current password is incorrect."),
                                backgroundColor: Colors.red,
                              ),
                            );
                          setState(() => _isUpdating = false);
                          return;
                        }
                        await Supabase.instance.client
                            .from('profiles')
                            .update({'password': _newPasswordCtrl.text})
                            .eq('id', ledger.currentUser!.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Password updated successfully!"),
                              backgroundColor: Colors.green,
                            ),
                          );
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Error: $e"),
                              backgroundColor: Colors.red,
                            ),
                          );
                          setState(() => _isUpdating = false);
                        }
                      }
                    },
              child: _isUpdating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text("UPDATE PASSWORD"),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
