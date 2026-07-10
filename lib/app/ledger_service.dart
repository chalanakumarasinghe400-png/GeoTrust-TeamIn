part of '../app.dart';

class LedgerService extends ChangeNotifier {
  final DbRepository _repo;
  double yardInventoryCubes = 40.0;
  final double maxYardCapacity = 100.0;

  double currentInventoryCubes = 0.0;
  double currentMaxCapacity = 100.0;

  List<Map<String, dynamic>> userLocations = [];
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
            _permits.addAll(data.map((row) => TransportPermit.fromJson(row)).toList());
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
              final cubes = (data.first['inventory_cubes'] as num).toDouble();
              if (currentUser?.isMineOwner == true) {
                yardInventoryCubes = cubes;
              } else if (currentUser?.isHardwareOwner == true) {
                hardwareInventoryCubes = cubes;
              }
              currentInventoryCubes = cubes;
              currentMaxCapacity = (data.first['max_capacity'] as num?)?.toDouble() ?? 100.0;
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
      final locs = await _repo.select('locations', filters: {'owner_id': userId});

      final prefs = await SharedPreferences.getInstance();
      if (profile != null) {
        await prefs.setString('cached_profile_$userId', jsonEncode(profile));
      }
      await prefs.setString('cached_locs_$userId', jsonEncode(locs));

      return _applyUserProfile(userId, profile, locs);
    } catch (e) {
      print('Profile Load Error: $e');
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
      for (final loc in userLocations) loc['id']: loc['name'] ?? 'Unnamed Location',
    };
    if (userLocations.isNotEmpty) {
      currentLocationId = userLocations.first['id'];
    }

    currentUser = AppUser(
      id: userId,
      name: profile['full_name'] ?? 'Unknown',
      isMineOwner: userLocations.any((l) => l['location_type'] == 'MINE' || l['location_type'] == 'MINE_OWNER'),
      isHardwareOwner: userLocations.any((l) => l['location_type'] == 'HARDWARE' || l['location_type'] == 'HARDWARE_OWNER'),
    );

    currentUsername = profile['full_name'] ?? 'Unknown';
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

      await _repo.update(
        'profiles',
        {'profile_photo': base64String},
        eqColumn: 'id',
        eqValue: currentUser!.id,
      );

      final prefs = await SharedPreferences.getInstance();
      final cachedProfileStr = prefs.getString('cached_profile_${currentUser!.id}');
      if (cachedProfileStr != null) {
        final profile = jsonDecode(cachedProfileStr);
        profile['profile_photo'] = base64String;
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
        'profiles',
        {'profile_photo': null},
        eqColumn: 'id',
        eqValue: currentUser!.id,
      );
    } catch (e) {
      print('Error removing profile picture: $e');
    }
  }

  Future<bool> loginWithCredentials(String email, String password) async {
    try {
      final response = await _repo.selectWhereSingle('profiles', {
        'email': email,
        'password': password,
      });

      if (response == null) return false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('loggedInUserId', response['id']);

      return await loadUserProfile(response['id']);
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

  Future<bool> issueNewPermit(String vehicle, double requestedQty, DateTime transportDate) async {
    if (requestedQty > currentInventoryCubes) {
      return false;
    }

    final newPermitId = _generateUuidV4();
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
      return true;
    } catch (e) {
      print('Error issuing permit: $e');
      return false;
    }
  }

  Future<void> activatePermitAndGenerateCode(String permitId) async {
    final generatedCode = (100000 + Random().nextInt(900000)).toString();
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
      print('Error activating permit: $e');
    }
  }

  Future<void> fetchTransactionHistory() async {
    if (currentUser == null) return;

    mineTransactionHistory.clear();
    hardwareTransactionHistory.clear();

    final locationIds = userLocations.map((loc) => loc['id'] as String).toList();
    if (locationIds.isEmpty) {
      notifyListeners();
      return;
    }

    try {
      final allHistory = (await _repo.getPermitsByOriginIdsAndStatus(locationIds, 'COMPLETED'))
          .map((json) => TransportPermit.fromJson(json))
          .toList();

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

      mineTransactionHistory.sort((a, b) => b.transportDate.compareTo(a.transportDate));
      hardwareTransactionHistory.sort((a, b) => b.transportDate.compareTo(a.transportDate));
      notifyListeners();
    } catch (e) {
      print('Error fetching transaction history: $e');
    }
  }

  Future<void> driverLoginWithCode(String code) async {
    try {
      final response = await _repo.selectWhereSingle('permits', {'permit_code': code});
      if (response == null) throw Exception('Invalid Code.');

      final permit = TransportPermit.fromJson(response);

      if (permit.status == PermitStatus.cancelled) {
        throw Exception('This permit has been cancelled.');
      }

      final position = await _determinePosition();
      print('Driver Origin GPS: ${position.latitude}, ${position.longitude}');

      final originLocation = await _repo.selectOne(
        'locations',
        'id',
        permit.originLocationId!,
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
      permit.expirationDate = newExpiry;

      await _repo.update(
        'permits',
        {'expiration_date': newExpiry.toIso8601String()},
        eqColumn: 'id',
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
        await _repo.update(
          'permits',
          {'status': PermitStatus.cancelled.name.toUpperCase()},
          eqColumn: 'id',
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
        final prefs = await SharedPreferences.getInstance();
        final offlineQueue = (prefs.getStringList('offline_unloads') ?? []).toList();
        offlineQueue.add(jsonEncode({'permit_id': currentDriverPermit!.id, ...payload}));
        await prefs.setStringList('offline_unloads', offlineQueue);
      } else {
        await _repo.update(
          'permits',
          payload,
          eqColumn: 'id',
          eqValue: currentDriverPermit!.id,
        );

        final hardwares = await _repo.getLocationsByType('HARDWARE_OWNER');
        for (final hw in hardwares) {
          final hwLat = (hw['latitude'] as num).toDouble();
          final hwLng = (hw['longitude'] as num).toDouble();

          if ((hwLat - position.latitude).abs() < 0.05 && (hwLng - position.longitude).abs() < 0.05) {
            await _repo.update(
              'locations',
              {
                'inventory_cubes': hw['inventory_cubes'] + currentDriverPermit!.volumeCubes,
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

  Future<bool> issueMiniPermit(String vehicle, double requestedQty, DateTime transportDate) async {
    if (requestedQty >= 5.0 || requestedQty > currentInventoryCubes) {
      return false;
    }

    final newPermitId = _generateUuidV4();
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
      print('Error issuing mini permit: $e');
      return false;
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
}
