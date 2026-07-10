part of '../app.dart';

class LedgerService extends ChangeNotifier {
  final DbRepository _repo;

  double currentInventoryCubes = 0.0;
  double currentMaxCapacity = 100.0;

  List<Map<String, dynamic>> userLocations = [];
  Map<String, String> locationIdToName = {};

  List<TransportPermit> mineTransactionHistory = [];
  List<TransportPermit> hardwareTransactionHistory = [];

  final List<TransportPermit> _permits = [];

  String? currentLocationId;
  AppUser? currentUser;
  String currentUsername = '';
  UserRole? currentUserRole;
  String? profilePicBase64;
  bool isOffline = false;

  TransportPermit? currentDriverPermit;

  List<TransportPermit> get permits => List.unmodifiable(_permits);

  StreamSubscription? _permitSubscription;
  StreamSubscription? _inventorySubscription;

  LedgerService({DbRepository? repository}) : _repo = repository ?? SupabaseRepository();

  // --- 1. NEW DATA FETCHING LOGIC (8 Tables) ---

  Future<bool> loadUserProfile(String userId) async {
    try {
      // 1. Fetch User
      final userRow = await _repo.selectOne('user_accounts', 'user_id', userId);
      if (userRow == null) return false;

      // 2. Fetch Mines & Hardwares explicitly for this user
      final mineRows = await _repo.select('mines', filters: {'user_id': userId});
      final hardwareRows = await _repo.select('hardwares', filters: {'user_id': userId});

      userLocations.clear();
      locationIdToName.clear();

      // Normalize Mines into UI list
      for (var m in mineRows) {
        userLocations.add({
          'id': m['mine_id'],
          'name': m['mine_name'],
          'location_type': 'MINE', // Pseudo-type for UI switches
          'inventory_cubes': m['current_cubes'],
          'max_capacity': m['maximum_cubes'],
        });
      }
      
      // Normalize Hardwares into UI list
      for (var h in hardwareRows) {
        userLocations.add({
          'id': h['hardware_id'],
          'name': h['hardware_name'],
          'location_type': 'HARDWARE',
          'inventory_cubes': h['current_cubes'],
          'max_capacity': h['maximum_cubes'],
        });
      }

      for (var loc in userLocations) {
        locationIdToName[loc['id']] = loc['name'];
      }

      if (userLocations.isNotEmpty) {
        currentLocationId = userLocations.first['id'];
      }

      currentUser = AppUser.fromJson(userRow);
      currentUsername = currentUser!.name;
      profilePicBase64 = currentUser!.profilePicture;

      notifyListeners();
      return true;
    } catch (e) {
      print('Load Profile Error: $e');
      return false;
    }
  }

  Future<bool> loginWithCredentials(String email, String password) async {
    try {
      final response = await _repo.selectWhereSingle('user_accounts', {
        'email': email,
        'password_hashed': password, // Match the exact SQL column
      });

      if (response == null) return false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('loggedInUserId', response['user_id']);

      return await loadUserProfile(response['user_id']);
    } catch (e) {
      print('Login Error: $e');
      return false;
    }
  }

  // --- 2. UPDATED STREAM LOGIC ---

  void subscribeToPermitChanges() {
    if (currentLocationId == null || currentUserRole == null) return;
    _permitSubscription?.cancel();
    
    // Choose table based on active role
    String table = currentUserRole == UserRole.mineOwner ? 'mine_permits' : 'hardware_permits';
    String column = currentUserRole == UserRole.mineOwner ? 'mine_id' : 'hardware_id';

    _permitSubscription = _repo.streamTable(
      table,
      primaryKey: 'permit_id',
      eq: {column: currentLocationId!},
    ).listen((data) {
      _permits.clear();
      _permits.addAll(data.map((row) => TransportPermit.fromJson(row)).toList());
      _permits.sort((a, b) => b.startedDate.compareTo(a.startedDate));
      notifyListeners();
    });
  }

  void subscribeToInventory() {
    if (currentLocationId == null || currentUserRole == null) return;
    _inventorySubscription?.cancel();

    // Choose table based on active role
    String table = currentUserRole == UserRole.mineOwner ? 'mines' : 'hardwares';
    String column = currentUserRole == UserRole.mineOwner ? 'mine_id' : 'hardware_id';

    _inventorySubscription = _repo.streamTable(
      table,
      primaryKey: column,
      eq: {column: currentLocationId!},
    ).listen((data) {
      if (data.isNotEmpty) {
        currentInventoryCubes = (data.first['current_cubes'] as num).toDouble();
        currentMaxCapacity = (data.first['maximum_cubes'] as num).toDouble();
        notifyListeners();
      }
    });
  }

  // --- 3. PERMIT CREATION LOGIC ---

  Future<bool> issueNewPermit(String vehicle, double requestedQty, DateTime transportDate) async {
    if (requestedQty > currentInventoryCubes) return false;

    String table = currentUserRole == UserRole.mineOwner ? 'mine_permits' : 'hardware_permits';
    String colId = currentUserRole == UserRole.mineOwner ? 'mine_id' : 'hardware_id';
    String locTable = currentUserRole == UserRole.mineOwner ? 'mines' : 'hardwares';

    final newPermit = TransportPermit(
      id: _generateUuidV4(),
      truckNumberPlate: vehicle,
      noOfCubes: requestedQty,
      startedDate: transportDate,
      expiryDate: transportDate.add(const Duration(days: 14)),
    );

    try {
      final payload = newPermit.toJson();
      payload[colId] = currentLocationId; // attach the FK relation

      await _repo.insert(table, payload);
      await _repo.update(locTable, {'current_cubes': currentInventoryCubes - requestedQty}, eqColumn: colId, eqValue: currentLocationId);
      return true;
    } catch (e) {
      print('Issue Permit Error: $e');
      return false;
    }
  }

  Future<void> activatePermitAndGenerateCode(String permitId) async {
    String table = currentUserRole == UserRole.mineOwner ? 'mine_permits' : 'hardware_permits';
    final generatedCode = (100000 + Random().nextInt(900000)).toString();
    try {
      await _repo.update(table, {
        'status': PermitStatus.active.name.toUpperCase(),
        'permit_code': generatedCode,
      }, eqColumn: 'permit_id', eqValue: permitId);
    } catch (e) {}
  }

  // --- 4. DRIVER LOGIC (Dual-table checker) ---

  Future<void> driverLoginWithCode(String code) async {
    try {
      // First, check if code exists in Mine Permits
      var response = await _repo.selectWhereSingle('mine_permits', {'permit_code': code});
      
      // If not, check Hardware Permits
      if (response == null) {
        response = await _repo.selectWhereSingle('hardware_permits', {'permit_code': code});
      }

      if (response == null) throw Exception('Invalid Code.');
      
      final permit = TransportPermit.fromJson(response);
      currentDriverPermit = permit;
      currentUserRole = UserRole.driver;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('savedDriverPermit', jsonEncode(currentDriverPermit!.toJson()));
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> driverUnloadDestination(XFile photoFile) async {
    if (currentDriverPermit == null) return;
    
    // Determine which tables to target based on where the permit originated
    final isMinePermit = currentDriverPermit!.mineId != null;
    final permitTable = isMinePermit ? 'mine_permits' : 'hardware_permits';
    final unloadTable = isMinePermit ? 'mine_unloads' : 'hardware_unloads';

    try {
      // 1. Mark Permit as Completed
      await _repo.update(permitTable, {'status': 'COMPLETED'}, eqColumn: 'permit_id', eqValue: currentDriverPermit!.id);
      
      // 2. Insert into the correct Unloads log table
      await _repo.insert(unloadTable, {
        'permit_id': currentDriverPermit!.id,
        'unloaded_latitude': 0.0, // Replace with GPS plugin data if desired
        'unloaded_longitude': 0.0,
        'unloaded_date': DateTime.now().toIso8601String().substring(0, 10),
        'unloaded_time': "${DateTime.now().hour}:${DateTime.now().minute}:00",
      });

      currentDriverPermit = null;
      notifyListeners();
    } catch (e) {
      print('Driver Unload Error: $e');
    }
  }

  // Utilities
  String _generateUuidV4() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final chars = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();
    return '${chars.sublist(0, 4).join()}-${chars.sublist(4, 6).join()}-${chars.sublist(6, 8).join()}-${chars.sublist(8, 10).join()}-${chars.sublist(10, 16).join()}';
  }

  Future<void> refreshData() async {}
  void setLocationAndPreload(String locId, UserRole role) {
    currentLocationId = locId;
    currentUserRole = role;
    subscribeToPermitChanges();
    subscribeToInventory();
  }
  void logout() {}
  Future<void> fetchTransactionHistory() async {}
  Future<void> syncOfflineUnloads() async {}
}