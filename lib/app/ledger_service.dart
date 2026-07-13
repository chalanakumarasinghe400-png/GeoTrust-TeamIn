part of '../app.dart';

class LedgerService extends ChangeNotifier {
  final DbRepository _repo;
  double yardInventoryCubes = 40.0;
  final double maxYardCapacity = 100.0;

  double currentInventoryCubes = 0.0;
  double currentMaxCapacity = 100.0;

  List<Map<String, dynamic>> userLocations = [];
  List<Map<String, dynamic>> userTrucks = [];
  Map<String, String> locationIdToName = {};

  List<TransportPermit> mineTransactionHistory = [];
  List<TransportPermit> hardwareTransactionHistory = [];

  double hardwareInventoryCubes = 20.0;

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
  StreamSubscription? _connectivitySubscription;

  LedgerService({DbRepository? repository}) : _repo = repository ?? SupabaseRepository() {
    Connectivity().checkConnectivity().then((result) {
      isOffline = result == ConnectivityResult.none;
      notifyListeners();
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      final offline = result == ConnectivityResult.none;
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
    if (currentLocationId == null || currentUserRole == null) return;
    _permitSubscription?.cancel();
    
    final isMine = currentUserRole == UserRole.mineOwner;
    final table = isMine ? 'mine_permits' : 'hardware_permits';
    final fk = isMine ? 'mine_id' : 'hardware_id';

    _permitSubscription = _repo
        .streamTable(
          table,
          primaryKey: 'permit_id',
          eq: {fk: currentLocationId!},
        )
        .listen(
          (data) {
            _permits.clear();
            _permits.addAll(data.map((row) => TransportPermit.fromJson(row)).toList());
            _permits.sort((a, b) => b.startedDate.compareTo(a.startedDate));
            notifyListeners();
          },
          onError: (error) {
            print('Permit stream error: $error');
          },
        );
  }

  void subscribeToInventory() {
    if (currentLocationId == null || currentUserRole == null) return;
    _inventorySubscription?.cancel();

    final isMine = currentUserRole == UserRole.mineOwner;
    final table = isMine ? 'mines' : 'hardwares';
    final pk = isMine ? 'mine_id' : 'hardware_id';

    _inventorySubscription = _repo
        .streamTable(
          table,
          primaryKey: pk,
          eq: {pk: currentLocationId!},
        )
        .listen(
          (data) {
            if (data.isNotEmpty) {
              final cubes = (data.first['current_cubes'] as num).toDouble();
              if (currentUserRole == UserRole.mineOwner) {
                yardInventoryCubes = cubes;
              } else if (currentUserRole == UserRole.hardwareOwner) {
                hardwareInventoryCubes = cubes;
              }
              currentInventoryCubes = cubes;
              currentMaxCapacity = (data.first['maximum_cubes'] as num?)?.toDouble() ?? 100.0;
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
      final profile = await _repo.selectOne('user_accounts', 'user_id', userId);
      
      final mines = await _repo.select('mines', filters: {'user_id': userId});
      final hardwares = await _repo.select('hardwares', filters: {'user_id': userId});
      final trucks = await _repo.select('trucks', filters: {'user_id': userId});
      
      final locs = [
        ...mines.map((m) => {...m, 'id': m['mine_id'], 'name': m['mine_name'], 'location_type': 'MINE', 'inventory_cubes': m['current_cubes'], 'max_capacity': m['maximum_cubes'], 'latitude': m['latitude'], 'longitude': m['longitude']}),
        ...hardwares.map((h) => {...h, 'id': h['hardware_id'], 'name': h['hardware_name'], 'location_type': 'HARDWARE', 'inventory_cubes': h['current_cubes'], 'max_capacity': h['maximum_cubes'], 'latitude': h['latitude'], 'longitude': h['longitude']})
      ];

      final mappedTrucks = trucks.map((t) => {
        ...t,
        'id': t['number_plate'],
        'name': t['number_plate'],
        'capacity': (t['capacity'] as num?)?.toDouble() ?? 10.0,
        'chassis_number': t['chassis_number'] ?? '',
      }).toList();

      final prefs = await SharedPreferences.getInstance();
      if (profile != null) {
        await prefs.setString('cached_profile_$userId', jsonEncode(profile));
      }
      await prefs.setString('cached_locs_$userId', jsonEncode(locs));
      await prefs.setString('cached_trucks_$userId', jsonEncode(mappedTrucks));

      return _applyUserProfile(userId, profile, locs, mappedTrucks);
    } catch (e) {
      print('Profile Load Error: $e');
      final prefs = await SharedPreferences.getInstance();
      final cachedProfileStr = prefs.getString('cached_profile_$userId');
      final cachedLocsStr = prefs.getString('cached_locs_$userId');
      final cachedTrucksStr = prefs.getString('cached_trucks_$userId');

      if (cachedProfileStr != null && cachedLocsStr != null) {
        try {
          final profile = jsonDecode(cachedProfileStr);
          final locs = jsonDecode(cachedLocsStr);
          final trucks = cachedTrucksStr != null ? jsonDecode(cachedTrucksStr) : [];
          return _applyUserProfile(userId, profile, locs, trucks);
        } catch (decodeErr) {
          return false;
        }
      }
      return false;
    }
  }

  bool _applyUserProfile(String userId, dynamic profile, dynamic locs, [dynamic trucks]) {
    if (profile == null) return false;

    userLocations = List<Map<String, dynamic>>.from(locs ?? []);
    userTrucks = List<Map<String, dynamic>>.from(trucks ?? []);
    locationIdToName = {
      for (final loc in userLocations) loc['id']: loc['name'] ?? 'Unnamed Location',
    };
    if (userLocations.isNotEmpty) {
      currentLocationId = userLocations.first['id'];
    }

    currentUser = AppUser(
      id: userId,
      name: profile['name'] ?? 'Unknown',
      nic: profile['nic'] ?? '',
      email: profile['email'] ?? '',
      profilePicture: profile['profile_picture'],
    );

    currentUsername = profile['name'] ?? 'Unknown';
    profilePicBase64 = profile['profile_picture'];

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

      await _repo.update(
        'user_accounts',
        {'profile_picture': base64String},
        eqColumn: 'user_id',
        eqValue: currentUser!.id,
      );

      final prefs = await SharedPreferences.getInstance();
      final cachedProfileStr = prefs.getString('cached_profile_${currentUser!.id}');
      if (cachedProfileStr != null) {
        final profile = jsonDecode(cachedProfileStr);
        profile['profile_picture'] = base64String;
        await prefs.setString('cached_profile_${currentUser!.id}', jsonEncode(profile));
      }
    } catch (e) {
      print('Error updating profile picture: $e');
    }
  }

  Future<void> removeProfilePicture() async {
    if (currentUser == null) return;
    profilePicBase64 = null;
    notifyListeners();

    try {
      await _repo.update(
        'user_accounts',
        {'profile_picture': null},
        eqColumn: 'user_id',
        eqValue: currentUser!.id,
      );
    } catch (e) {
      print('Error removing profile picture: $e');
    }
  }

  Future<bool> loginWithCredentials(String email, String password) async {
    try {
      final response = await _repo.selectWhereSingle('user_accounts', {
        'email': email,
        'password_hashed': password,
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

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('loggedInUserId');
    await prefs.remove('savedDriverPermit');
    currentUser = null;
    currentLocationId = null;
    currentUserRole = null;
    currentDriverPermit = null;
    userLocations = [];
    userTrucks = [];
    notifyListeners();
  }

  void setLocationAndPreload(String locId, UserRole role) {
    currentLocationId = locId;
    currentUserRole = role;

    final locData = userLocations.firstWhere(
      (l) => l['id'] == locId,
      orElse: () => {},
    );
    if (locData.isNotEmpty) {
      currentInventoryCubes = (locData['inventory_cubes'] as num?)?.toDouble() ?? 0.0;
      currentMaxCapacity = (locData['max_capacity'] as num?)?.toDouble() ?? 100.0;
    }

    subscribeToPermitChanges();
    subscribeToInventory();
  }

  Future<String?> issueNewPermit(String vehicle, double requestedQty, DateTime transportDate) async {
    // 1. Check if truck is registered in the system
    try {
      final truck = await _repo.selectOne('trucks', 'number_plate', vehicle);
      if (truck == null) {
        return 'ERROR: Truck is not registered in the system.';
      }
      
      // 2. Check if quota is less than or equal to the capacity of the truck
      final capacity = (truck['capacity'] as num?)?.toDouble() ?? 0.0;
      if (requestedQty > capacity) {
        return 'ERROR: Requested quantity ($requestedQty cubes) exceeds the truck capacity of $capacity cubes.';
      }
    } catch (e) {
      print('Error verifying truck registration: $e');
      return 'ERROR: Failed to verify truck registration. Please check connection.';
    }

    // 3. Check inventory quota
    if (requestedQty > currentInventoryCubes) {
      return 'ERROR: Insufficient Quota! Remaining: $currentInventoryCubes cubes.';
    }

    final newPermitId = _generateUuidV4();
    // Provide a temporary draft code to satisfy the NOT NULL constraint.
    // It gets replaced with a real 6-digit code upon activation.
    final draftCode = 'DRAFT-${newPermitId.replaceAll('-', '').substring(0, 8).toUpperCase()}';
    final newPermit = TransportPermit(
      id: newPermitId,
      permitCode: draftCode,
      truckNumberPlate: vehicle,
      noOfCubes: requestedQty,
      startedDate: transportDate,
      expiryDate: transportDate.add(const Duration(days: 14)),
      mineId: currentUserRole == UserRole.mineOwner ? currentLocationId : null,
      hardwareId: currentUserRole == UserRole.hardwareOwner ? currentLocationId : null,
      status: PermitStatus.pending,
    );

    try {
      final isMine = currentUserRole == UserRole.mineOwner;
      final targetTable = isMine ? 'mine_permits' : 'hardware_permits';
      final locationTable = isMine ? 'mines' : 'hardwares';
      final locationPk = isMine ? 'mine_id' : 'hardware_id';

      await _repo.insert(targetTable, newPermit.toJson());
      await _repo.update(
        locationTable,
        {'current_cubes': currentInventoryCubes - requestedQty},
        eqColumn: locationPk,
        eqValue: currentLocationId!,
      );

      // Immediately update local state so UI refreshes without waiting for stream
      _permits.add(newPermit);
      _permits.sort((a, b) => b.startedDate.compareTo(a.startedDate));
      currentInventoryCubes -= requestedQty;
      notifyListeners();

      return null; // success
    } catch (e) {
      print('Error issuing permit: $e');
      return 'ERROR: Failed to issue permit. ${e.toString()}';
    }
  }

  Future<void> activatePermitAndGenerateCode(String permitId) async {
    final generatedCode = (100000 + Random().nextInt(900000)).toString();
    try {
      final isMine = currentUserRole == UserRole.mineOwner;
      final targetTable = isMine ? 'mine_permits' : 'hardware_permits';
      await _repo.update(
        targetTable,
        {
          'status': PermitStatus.active.name.toUpperCase(),
          'permit_code': generatedCode,
        },
        eqColumn: 'permit_id',
        eqValue: permitId,
      );

      // Immediately update local state so UI shows code without navigating away
      final idx = _permits.indexWhere((p) => p.id == permitId);
      if (idx != -1) {
        _permits[idx].status = PermitStatus.active;
        _permits[idx].permitCode = generatedCode;
        notifyListeners();
      }
    } catch (e) {
      print('Error activating permit: $e');
    }
  }

  Future<void> fetchTransactionHistory() async {
    if (currentUser == null) return;

    mineTransactionHistory.clear();
    hardwareTransactionHistory.clear();

    if (userLocations.isEmpty) {
      notifyListeners();
      return;
    }

    final mineIds = userLocations
        .where((loc) => loc['location_type'] == 'MINE' || loc['location_type'] == 'MINE_OWNER')
        .map((loc) => loc['id'] as String)
        .toList();
    final hardwareIds = userLocations
        .where((loc) => loc['location_type'] == 'HARDWARE' || loc['location_type'] == 'HARDWARE_OWNER')
        .map((loc) => loc['id'] as String)
        .toList();

    try {
      if (mineIds.isNotEmpty) {
        final mineHistory = (await _repo.getMinePermitsByMineIdsAndStatus(mineIds, 'COMPLETED'))
            .map((json) => TransportPermit.fromJson(json))
            .toList();
        mineTransactionHistory.addAll(mineHistory);
      }

      if (hardwareIds.isNotEmpty) {
        final hardwareHistory = (await _repo.getHardwarePermitsByHardwareIdsAndStatus(hardwareIds, 'COMPLETED'))
            .map((json) => TransportPermit.fromJson(json))
            .toList();
        hardwareTransactionHistory.addAll(hardwareHistory);
      }

      mineTransactionHistory.sort((a, b) => b.startedDate.compareTo(a.startedDate));
      hardwareTransactionHistory.sort((a, b) => b.startedDate.compareTo(a.startedDate));
      notifyListeners();
    } catch (e) {
      print('Error fetching transaction history: $e');
    }
  }

  Future<void> driverLoginWithCode(String code) async {
    try {
      Map<String, dynamic>? response = await _repo.selectWhereSingle('mine_permits', {'permit_code': code});
      bool isMine = true;
      if (response == null) {
        response = await _repo.selectWhereSingle('hardware_permits', {'permit_code': code});
        isMine = false;
      }
      if (response == null) throw Exception('Invalid Code.');

      final permit = TransportPermit.fromJson(response);

      if (permit.status == PermitStatus.cancelled) {
        throw Exception('This permit has been cancelled.');
      }

      final position = await _determinePosition();
      print('Driver Origin GPS: ${position.latitude}, ${position.longitude}');

      final targetLocationTable = isMine ? 'mines' : 'hardwares';
      final targetLocationPk = isMine ? 'mine_id' : 'hardware_id';
      final originLocation = await _repo.selectOne(
        targetLocationTable,
        targetLocationPk,
        permit.mineId ?? permit.hardwareId ?? '',
        columns: ['latitude', 'longitude'],
      );

      if (originLocation != null && originLocation['latitude'] != null && originLocation['longitude'] != null) {
        final mineLat = (originLocation['latitude'] as num).toDouble();
        final mineLng = (originLocation['longitude'] as num).toDouble();

        final distanceInMeters = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          mineLat,
          mineLng,
        );

        if (distanceInMeters > 500) {
          throw Exception(
            'Location verification failed. You are not at the origin mine (Distance: ${distanceInMeters.toStringAsFixed(0)}m).',
          );
        }
      } else {
        throw Exception('Origin location GPS coordinates not found.');
      }

      final newExpiry = DateTime.now().add(const Duration(hours: 12));
      permit.expiryDate = newExpiry;

      await _repo.update(
        isMine ? 'mine_permits' : 'hardware_permits',
        {'expiry_date': newExpiry.toIso8601String().substring(0, 10)},
        eqColumn: 'permit_id',
        eqValue: permit.id,
      );

      currentDriverPermit = permit;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('savedDriverPermit', jsonEncode(currentDriverPermit!.toJson()));

      currentUserRole = UserRole.driver;
      notifyListeners();
    } catch (e) {
      print('Driver Login Error: $e');
      rethrow;
    }
  }

  Future<void> cancelExpiredDriverPermit() async {
    if (currentDriverPermit != null) {
      try {
        final isMine = currentDriverPermit!.mineId != null;
        await _repo.update(
          isMine ? 'mine_permits' : 'hardware_permits',
          {'status': PermitStatus.cancelled.name.toUpperCase()},
          eqColumn: 'permit_id',
          eqValue: currentDriverPermit!.id,
        );
      } catch (e) {
        print('Failed to cancel permit on server: $e');
      }
      currentDriverPermit = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('savedDriverPermit');
      notifyListeners();
    }
  }

  Future<void> _executeUnloadOnServer({
    required bool isMine,
    required String permitId,
    required double lat,
    required double lng,
    required String photoUrl,
    required String date,
    required String time,
  }) async {
    final permitTable = isMine ? 'mine_permits' : 'hardware_permits';
    final unloadTable = isMine ? 'mine_unloads' : 'hardware_unloads';

    await _repo.update(
      permitTable,
      {'status': PermitStatus.completed.name.toUpperCase()},
      eqColumn: 'permit_id',
      eqValue: permitId,
    );

    final unloadPayload = {
      'permit_id': permitId,
      'unloaded_latitude': lat,
      'unloaded_longitude': lng,
      if (photoUrl.isNotEmpty) 'photo_url': photoUrl,
      'unloaded_date': date,
      'unloaded_time': time,
    };
    await _repo.insert(unloadTable, unloadPayload);
  }

  Future<void> driverUnloadDestination(XFile photoFile) async {
    if (currentDriverPermit == null) return;

    try {
      final position = await _determinePosition();
      print('Driver Destination GPS captured: ${position.latitude}, ${position.longitude}');

      String photoUrl = '';
      try {
        final bytes = await photoFile.readAsBytes();
        final path = 'audits/${currentDriverPermit!.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _repo.uploadBinary('verifications', path, bytes, contentType: 'image/jpeg');
        photoUrl = _repo.getPublicUrl('verifications', path);
      } catch (e) {
        print('Photo upload skipped (offline or bucket missing): $e');
      }

      final isMine = currentDriverPermit!.mineId != null;
      final now = DateTime.now();
      final dateStr = now.toIso8601String().substring(0, 10);
      final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        final prefs = await SharedPreferences.getInstance();
        final offlineQueue = (prefs.getStringList('offline_unloads') ?? []).toList();
        offlineQueue.add(jsonEncode({
          'is_mine': isMine,
          'permit_id': currentDriverPermit!.id,
          'unload_latitude': position.latitude,
          'unload_longitude': position.longitude,
          'photo_url': photoUrl,
          'unloaded_date': dateStr,
          'unloaded_time': timeStr,
        }));
        await prefs.setStringList('offline_unloads', offlineQueue);
      } else {
        await _executeUnloadOnServer(
          isMine: isMine,
          permitId: currentDriverPermit!.id,
          lat: position.latitude,
          lng: position.longitude,
          photoUrl: photoUrl,
          date: dateStr,
          time: timeStr,
        );

        final hardwares = await _repo.select('hardwares');
        for (final hw in hardwares) {
          final hwLat = (hw['latitude'] as num).toDouble();
          final hwLng = (hw['longitude'] as num).toDouble();

          if ((hwLat - position.latitude).abs() < 0.05 && (hwLng - position.longitude).abs() < 0.05) {
            await _repo.update(
              'hardwares',
              {
                'current_cubes': (hw['current_cubes'] as num).toDouble() + currentDriverPermit!.noOfCubes,
              },
              eqColumn: 'hardware_id',
              eqValue: hw['hardware_id'],
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
      print('Error completing journey: $e');
    }
  }

  Future<void> syncOfflineUnloads() async {
    final prefs = await SharedPreferences.getInstance();
    final offlineQueue = prefs.getStringList('offline_unloads') ?? [];
    if (offlineQueue.isEmpty) return;

    final pendingQueue = <String>[];
    for (final data in offlineQueue) {
      try {
        final payload = Map<String, dynamic>.from(jsonDecode(data) as Map);
        final isMine = payload['is_mine'] as bool;
        final permitId = payload['permit_id'] as String;
        final lat = (payload['unload_latitude'] as num).toDouble();
        final lng = (payload['unload_longitude'] as num).toDouble();
        final photoUrl = payload['photo_url'] as String;
        final date = payload['unloaded_date'] as String;
        final time = payload['unloaded_time'] as String;

        await _executeUnloadOnServer(
          isMine: isMine,
          permitId: permitId,
          lat: lat,
          lng: lng,
          photoUrl: photoUrl,
          date: date,
          time: time,
        );
      } catch (e) {
        pendingQueue.add(data);
      }
    }
    await prefs.setStringList('offline_unloads', pendingQueue);
  }

  Future<String?> issueMiniPermit(String vehicle, double requestedQty, DateTime transportDate) async {
    // 1. Check quantity limit
    if (requestedQty >= 5.0) {
      return 'ERROR: Mini-permit quantity must be less than 5 cubes.';
    }

    // 2. Check if truck is registered in the system
    try {
      final truck = await _repo.selectOne('trucks', 'number_plate', vehicle);
      if (truck == null) {
        return 'ERROR: Truck is not registered in the system.';
      }
      
      // 3. Check if quota is less than or equal to the capacity of the truck
      final capacity = (truck['capacity'] as num?)?.toDouble() ?? 0.0;
      if (requestedQty > capacity) {
        return 'ERROR: Requested quantity ($requestedQty cubes) exceeds the truck capacity of $capacity cubes.';
      }
    } catch (e) {
      print('Error verifying truck registration: $e');
      return 'ERROR: Failed to verify truck registration. Please check connection.';
    }

    // 4. Check inventory quota
    if (requestedQty > currentInventoryCubes) {
      return 'ERROR: Insufficient Quota! Remaining: $currentInventoryCubes cubes.';
    }

    final newPermitId = _generateUuidV4();
    final draftCode = 'DRAFT-${newPermitId.replaceAll('-', '').substring(0, 8).toUpperCase()}';
    final newPermit = TransportPermit(
      id: newPermitId,
      permitCode: draftCode,
      truckNumberPlate: vehicle,
      noOfCubes: requestedQty,
      startedDate: transportDate,
      expiryDate: transportDate.add(const Duration(days: 14)),
      mineId: currentUserRole == UserRole.mineOwner ? currentLocationId : null,
      hardwareId: currentUserRole == UserRole.hardwareOwner ? currentLocationId : null,
      status: PermitStatus.pending,
    );

    try {
      final isMine = currentUserRole == UserRole.mineOwner;
      final targetTable = isMine ? 'mine_permits' : 'hardware_permits';
      final locationTable = isMine ? 'mines' : 'hardwares';
      final locationPk = isMine ? 'mine_id' : 'hardware_id';

      await _repo.insert(targetTable, newPermit.toJson());
      await _repo.update(
        locationTable,
        {'current_cubes': currentInventoryCubes - requestedQty},
        eqColumn: locationPk,
        eqValue: currentLocationId!,
      );

      // Immediately update local state so UI refreshes without waiting for stream
      _permits.add(newPermit);
      _permits.sort((a, b) => b.startedDate.compareTo(a.startedDate));
      currentInventoryCubes -= requestedQty;
      notifyListeners();

      return null; // success
    } catch (e) {
      print('Error issuing mini permit: $e');
      return 'ERROR: Failed to issue mini permit. ${e.toString()}';
    }
  }

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
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    }

    return Geolocator.getCurrentPosition();
  }

  String _generateUuidV4() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final chars = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();
    return '${chars.sublist(0, 4).join()}-${chars.sublist(4, 6).join()}-${chars.sublist(6, 8).join()}-${chars.sublist(8, 10).join()}-${chars.sublist(10, 16).join()}';
  }

  Future<List<TransportPermit>> getPermitsForTruck(String numberPlate) async {
    try {
      final minePermits = await _repo.select('mine_permits', filters: {'truck_number_plate': numberPlate});
      final hwPermits = await _repo.select('hardware_permits', filters: {'truck_number_plate': numberPlate});
      
      final list = [
        ...minePermits.map((p) => TransportPermit.fromJson(p)),
        ...hwPermits.map((p) => TransportPermit.fromJson(p)),
      ];
      list.sort((a, b) => b.startedDate.compareTo(a.startedDate));
      return list;
    } catch (e) {
      print('Error getting permits for truck: $e');
      return [];
    }
  }
}