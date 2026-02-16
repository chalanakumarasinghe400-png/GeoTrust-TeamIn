import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const GeoTrustApp(),
    ),
  );
}

// --- DATA MODELS ---

// The specific steps of a sand transportation trip
enum TripStatus {
  assigned, // Driver assigned, on way to mine
  atMine, // Driver arrived at mine
  loading, // Mine owner is loading sand
  loaded, // Loading done, ready for license
  onTrip, // License Issued! Driving to hardware
  atHardware, // Arrived at destination
  completed, // Unloaded, license expired
}

// The available user roles
enum UserRole { driver, mineOwner, hardwareOwner, truckOwner }

// Extension to get pretty names for roles
extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.driver:
        return "Truck Driver";
      case UserRole.mineOwner:
        return "Mine Owner";
      case UserRole.hardwareOwner:
        return "Hardware Owner";
      case UserRole.truckOwner:
        return "Truck Owner";
    }
  }

  IconData get icon {
    switch (this) {
      case UserRole.driver:
        return Icons.local_shipping_outlined;
      case UserRole.mineOwner:
        return Icons.engineering_outlined;
      case UserRole.hardwareOwner:
        return Icons.storefront_outlined;
      case UserRole.truckOwner:
        return Icons.garage_outlined;
    }
  }

  Color get color {
    switch (this) {
      case UserRole.driver:
        return Colors.blue;
      case UserRole.mineOwner:
        return Colors.orange;
      case UserRole.hardwareOwner:
        return Colors.purple;
      case UserRole.truckOwner:
        return Colors.indigo;
    }
  }
}

class Truck {
  final String model;
  final String plate;
  final int capacity;

  const Truck({
    required this.model,
    required this.plate,
    required this.capacity,
  });

  @override
  String toString() => "$model ($plate) - ${capacity}m³";
}

class Trip {
  final String id;
  TripStatus status;
  final Truck truck;
  final String driverName;
  String licenseKey;

  Trip({
    required this.id,
    required this.status,
    required this.truck,
    required this.driverName,
    this.licenseKey = "PENDING",
  });
}

// --- GLOBAL STATE (MOCKED) ---
class MockDatabase {
  static List<Trip> trips = [
    Trip(
      id: "T-DEMO-001",
      status: TripStatus.assigned,
      truck: const Truck(model: "Volvo FH16", plate: "LP-9988", capacity: 20),
      driverName: "Saman Perera",
    ),
  ];
  static int mineQuota = 50;
  static int truckOwnerQuota = 30;
  static int hardwareQuota = 30;

  // User Session State
  static List<UserRole> currentUserRoles = [];
  static String username = "User";
  static Color profileColor = Colors.blue; // For profile photo

  // Truck Owner Data
  static List<Truck> dummyTrucks = [
    const Truck(model: "Volvo FH16", plate: "LP-9988", capacity: 20),
    const Truck(model: "Scania R500", plate: "LP-1122", capacity: 15),
    const Truck(model: "Benz Actros", plate: "LP-3344", capacity: 25),
  ];
  static List<String> dummyDrivers = [
    "Saman Perera",
    "Kamal Silva",
    "Nimal Fernando",
  ];

  static bool isTruckBusy(Truck truck) {
    return trips.any(
      (t) => t.truck == truck && t.status != TripStatus.completed,
    );
  }

  static bool isDriverBusy(String driver) {
    return trips.any(
      (t) => t.driverName == driver && t.status != TripStatus.completed,
    );
  }
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}

// --- MAIN APP ---
class GeoTrustApp extends StatelessWidget {
  const GeoTrustApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeProvider>().themeMode;
    return MaterialApp(
      title: 'GeoTrust 1.0',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      // Light Theme (Material 3)
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006C50), // Teal base
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFFDFDFD),
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      // Dark Theme (Material 3)
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006C50),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      home: const LoginScreen(),
    );
  }
}

// --- SCREEN 1: LOGIN & ROLE SELECTION ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Track selected roles
  final Set<UserRole> _selectedRoles = {};
  final TextEditingController _userController = TextEditingController(
    text: "Saman Perera",
  );
  final TextEditingController _passwordController = TextEditingController(
    text: "Saman@123",
  );
  bool _isPasswordVisible = false;

  void _handleLogin() {
    if (_selectedRoles.isEmpty ||
        _userController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Username, Password and Role are required"),
        ),
      );
      return;
    }

    // Password Strength Check
    // At least 8 chars, 1 uppercase, 1 number, 1 special char
    final passwordRegex = RegExp(
      r'^(?=.*?[A-Z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$',
    );
    if (!passwordRegex.hasMatch(_passwordController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Password too weak. Use 8+ chars, 1 Upper, 1 Number, 1 Special.",
          ),
        ),
      );
      return;
    }

    MockDatabase.currentUserRoles = _selectedRoles.toList();
    MockDatabase.username = _userController.text.isNotEmpty
        ? _userController.text
        : "User";

    // Navigation Logic:
    // If 1 Role -> Go directly to that dashboard
    // If >1 Role -> Go to Role Switcher
    if (_selectedRoles.length == 1) {
      _navigateToDashboard(context, _selectedRoles.first);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const RoleSwitcherScreen()),
      );
    }
  }

  void _navigateToDashboard(BuildContext context, UserRole role) {
    Widget screen;
    switch (role) {
      case UserRole.driver:
        screen = const DriverScreen();
        break;
      case UserRole.mineOwner:
        screen = const MineOwnerScreen();
        break;
      case UserRole.hardwareOwner:
        screen = const HardwareOwnerScreen();
        break;
      case UserRole.truckOwner:
        screen = const TruckOwnerScreen();
        break;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              const SizedBox(height: 40),
              Icon(
                Icons.verified_user_rounded,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                "Welcome to GeoTrust",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Secure Sand Transportation Ledger",
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 40),

              // Inputs
              TextField(
                controller: _userController,
                decoration: const InputDecoration(
                  labelText: "Username",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: "Password",
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() => _isPasswordVisible = !_isPasswordVisible);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                "Select Your Roles:",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),

              // Vertical Colorful Role Selection
              Column(
                children: UserRole.values.map((role) {
                  final isSelected = _selectedRoles.contains(role);
                  return _buildRoleCard(role, isSelected);
                }).toList(),
              ),

              const SizedBox(height: 40),

              // Login Button
              FilledButton.icon(
                onPressed: _handleLogin,
                icon: const Icon(Icons.login),
                label: const Text("LOGIN"),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

              const SizedBox(height: 20),

              // Dark Mode Toggle for Demo
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.light_mode, size: 16),
                  Switch(
                    value: isDark,
                    onChanged: (val) =>
                        context.read<ThemeProvider>().toggleTheme(val),
                  ),
                  const Icon(Icons.dark_mode, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(UserRole role, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedRoles.remove(role);
            } else {
              _selectedRoles.add(role);
            }
          });
        },
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? role.color : role.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: role.color, width: 2),
          ),
          child: Row(
            children: [
              Icon(
                role.icon,
                color: isSelected ? Colors.white : role.color,
                size: 28,
              ),
              const SizedBox(width: 16),
              Text(
                role.displayName,
                style: TextStyle(
                  color: isSelected ? Colors.white : role.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (isSelected)
                const Icon(Icons.check_circle, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

// --- SCREEN 1.5: ROLE SWITCHER (For Multi-Role Users) ---
class RoleSwitcherScreen extends StatelessWidget {
  const RoleSwitcherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Dashboard")),
      drawer: const AppDrawer(), // Available here too
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            "You are logged in as multiple roles.\nSelect which dashboard to view:",
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ...MockDatabase.currentUserRoles
              .map(
                (role) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: role.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: role.color, width: 1),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: role.color,
                        child: Icon(role.icon, color: Colors.white),
                      ),
                      title: Text(
                        role.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text("Tap to enter dashboard"),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Widget page;
                        switch (role) {
                          case UserRole.driver:
                            page = const DriverScreen();
                            break;
                          case UserRole.mineOwner:
                            page = const MineOwnerScreen();
                            break;
                          case UserRole.hardwareOwner:
                            page = const HardwareOwnerScreen();
                            break;
                          case UserRole.truckOwner:
                            page = const TruckOwnerScreen();
                            break;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => page),
                        );
                      },
                    ),
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }
}

// --- COMMON DRAWER (HAMBURGER MENU) ---
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: colors.primaryContainer),
            accountName: Text(
              MockDatabase.username,
              style: TextStyle(
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            accountEmail: Text(
              "Roles: ${MockDatabase.currentUserRoles.length}",
              style: TextStyle(color: colors.onPrimaryContainer),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: colors.primary,
              child: Text(
                MockDatabase.username.isNotEmpty
                    ? MockDatabase.username[0].toUpperCase()
                    : "U",
                style: TextStyle(fontSize: 24, color: colors.onPrimary),
              ),
            ),
          ),
          // Navigation
          if (MockDatabase.currentUserRoles.length > 1)
            ListTile(
              leading: const Icon(Icons.dashboard_customize),
              title: const Text("Switch Role"),
              onTap: () {
                // Return to switcher, remove all routes until switcher
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const RoleSwitcherScreen()),
                  (route) => false,
                );
              },
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text("Profile"),
            onTap: () {
              Navigator.pop(context); // Close drawer
              // Navigate to profile if it existed, or just show settings
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text("Settings"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text("Dark Mode"),
            trailing: Switch(
              value: Theme.of(context).brightness == Brightness.dark,
              onChanged: (val) =>
                  context.read<ThemeProvider>().toggleTheme(val),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("About Us"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.contact_support_outlined),
            title: const Text("Contact Us"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ContactScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text("User Agreement"),
            onTap: () {}, // Placeholder
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: () {
              // Reset and go to login
              MockDatabase.currentUserRoles = [];
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const GeoTrustApp()),
                (r) => false,
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// --- SCREEN 2: DRIVER DASHBOARD ---
class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key});
  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    // Find active trip for this driver (matching username)
    // For demo purposes, if username doesn't match a driver, we might show nothing or the first unassigned one.
    // Here we assume the logged in user IS the driver name.
    final myTrips = MockDatabase.trips
        .where(
          (t) =>
              t.driverName == MockDatabase.username &&
              t.status != TripStatus.completed,
        )
        .toList();
    final Trip? currentTrip = myTrips.isNotEmpty ? myTrips.first : null;

    return Scaffold(
      appBar: AppBar(title: const Text("Driver Dashboard")),
      drawer: const AppDrawer(),
      body: currentTrip == null
          ? const Center(
              child: Text(
                "No active trips assigned to you.",
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TripStatusCard(trip: currentTrip, role: UserRole.driver),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "Trip ID: ${currentTrip.id}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  if (currentTrip.truck.model.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        "Driving: ${currentTrip.truck}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),

                  const Spacer(),

                  // Contextual Actions
                  if (currentTrip.status == TripStatus.assigned)
                    ActionSlider(
                      label: "Slide to Confirm Arrival",
                      icon: Icons.location_on,
                      color: Colors.orange,
                      onConfirmed: () {
                        currentTrip.status = TripStatus.atMine;
                        _refresh();
                      },
                    ),

                  if (currentTrip.status == TripStatus.atMine)
                    const InfoBanner(
                      text: "Waiting for loading...",
                      icon: Icons.hourglass_top,
                    ),

                  if (currentTrip.status == TripStatus.loading)
                    const InfoBanner(
                      text: "Loading in progress...",
                      icon: Icons.downloading,
                    ),

                  if (currentTrip.status == TripStatus.loaded)
                    ActionSlider(
                      label: "Start Trip (Get License)",
                      icon: Icons.vpn_key,
                      color: Colors.green,
                      onConfirmed: () {
                        currentTrip.status = TripStatus.onTrip;
                        MockDatabase.mineQuota -= currentTrip.truck.capacity;
                        MockDatabase.truckOwnerQuota -=
                            currentTrip.truck.capacity;
                        currentTrip.licenseKey =
                            "LIC-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}";
                        _refresh();
                      },
                    ),

                  if (currentTrip.status == TripStatus.onTrip)
                    ActionSlider(
                      label: "Arrive Destination",
                      icon: Icons.flag,
                      color: Colors.purple,
                      onConfirmed: () {
                        currentTrip.status = TripStatus.atHardware;
                        _refresh();
                      },
                    ),

                  if (currentTrip.status == TripStatus.atHardware)
                    const InfoBanner(
                      text: "Waiting for buyer confirmation...",
                      icon: Icons.verified_user_outlined,
                    ),

                  if (currentTrip.status == TripStatus.completed)
                    const InfoBanner(
                      text: "Trip Completed. Good Job!",
                      icon: Icons.check_circle,
                      isSuccess: true,
                    ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}

// --- SCREEN 2.5: TRUCK OWNER DASHBOARD ---
class TruckOwnerScreen extends StatefulWidget {
  const TruckOwnerScreen({super.key});

  @override
  State<TruckOwnerScreen> createState() => _TruckOwnerScreenState();
}

class _TruckOwnerScreenState extends State<TruckOwnerScreen> {
  Truck? _selectedTruck;
  String? _selectedDriver;

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    // Filter available resources
    final availableTrucks = MockDatabase.dummyTrucks
        .where((t) => !MockDatabase.isTruckBusy(t))
        .toList();
    final availableDrivers = MockDatabase.dummyDrivers
        .where((d) => !MockDatabase.isDriverBusy(d))
        .toList();

    final activeTrips = MockDatabase.trips
        .where((t) => t.status != TripStatus.completed)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Truck Owner")),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Quota Card
            Card(
              color: Colors.indigo.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "TRANSPORT QUOTA",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                    Text(
                      "${MockDatabase.truckOwnerQuota} m³",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              "Active Trips",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (activeTrips.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  "No active trips.",
                  style: TextStyle(color: Colors.grey),
                ),
              ),

            ...activeTrips.map(
              (trip) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: TripStatusCard(trip: trip, role: UserRole.truckOwner),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              "Assign Resources",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Truck Selector
            DropdownButtonFormField<Truck>(
              decoration: const InputDecoration(
                labelText: "Select Truck",
                border: OutlineInputBorder(),
              ),
              value: _selectedTruck,
              items: availableTrucks
                  .map(
                    (t) =>
                        DropdownMenuItem(value: t, child: Text(t.toString())),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _selectedTruck = val),
            ),
            const SizedBox(height: 16),

            // Driver Selector
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: "Select Driver",
                border: OutlineInputBorder(),
              ),
              value: _selectedDriver,
              items: availableDrivers
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedDriver = val),
            ),
            const SizedBox(height: 24),

            if (MockDatabase.mineQuota > 0 && MockDatabase.truckOwnerQuota > 0)
              FilledButton.icon(
                onPressed: _selectedTruck != null && _selectedDriver != null
                    ? () {
                        // Start New Process
                        final newTrip = Trip(
                          id: "T-${Random().nextInt(9999)}",
                          status: TripStatus.assigned,
                          truck: _selectedTruck!,
                          driverName: _selectedDriver!,
                        );
                        MockDatabase.trips.add(newTrip);

                        // Reset selection
                        setState(() {
                          _selectedTruck = null;
                          _selectedDriver = null;
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Trip Initiated! Driver notified."),
                          ),
                        );
                        _refresh();
                      }
                    : null,
                icon: const Icon(Icons.send),
                label: const Text("ASSIGN & START TRIP"),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.indigo,
                ),
              )
            else
              const Card(
                color: Colors.redAccent,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "Quota Exceeded. Cannot start new trips.",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- SCREEN 3: MINE OWNER DASHBOARD ---
class MineOwnerScreen extends StatefulWidget {
  const MineOwnerScreen({super.key});
  @override
  State<MineOwnerScreen> createState() => _MineOwnerScreenState();
}

class _MineOwnerScreenState extends State<MineOwnerScreen> {
  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final activeTrips = MockDatabase.trips
        .where((t) => t.status != TripStatus.completed)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Mine Owner")),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {}, // Add functionality later
        label: const Text("New Permit"),
        icon: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Quota Card
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text("REMAINING QUOTA"),
                  Text(
                    "${MockDatabase.mineQuota}",
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const Text("Cubic Meters"),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            "Incoming / Active Trips",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          if (activeTrips.isEmpty)
            const Text(
              "No active trips.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),

          ...activeTrips.map((trip) {
            return Column(
              children: [
                TripStatusCard(trip: trip, role: UserRole.mineOwner),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    "Vehicle: ${trip.truck.toString()}\nDriver: ${trip.driverName}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (trip.status == TripStatus.atMine)
                  FilledButton.icon(
                    onPressed: () {
                      trip.status = TripStatus.loading;
                      _refresh();
                    },
                    icon: const Icon(Icons.start),
                    label: const Text("START LOADING"),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange,
                      minimumSize: const Size.fromHeight(40),
                    ),
                  ),

                if (trip.status == TripStatus.loading)
                  FilledButton.icon(
                    onPressed: () {
                      trip.status = TripStatus.loaded;
                      _refresh();
                    },
                    icon: const Icon(Icons.check),
                    label: const Text("FINISH LOADING"),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size.fromHeight(40),
                    ),
                  ),
                const Divider(height: 30),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// --- SCREEN 4: HARDWARE OWNER DASHBOARD ---
class HardwareOwnerScreen extends StatefulWidget {
  const HardwareOwnerScreen({super.key});
  @override
  State<HardwareOwnerScreen> createState() => _HardwareOwnerScreenState();
}

class _HardwareOwnerScreenState extends State<HardwareOwnerScreen> {
  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final incomingTrips = MockDatabase.trips
        .where(
          (t) =>
              t.status.index >= TripStatus.onTrip.index &&
              t.status != TripStatus.completed,
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Hardware Buyer")),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Quota Card
            Card(
              color: Colors.purple.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "STORAGE QUOTA",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                    Text(
                      "${MockDatabase.hardwareQuota} m³",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              "Incoming Deliveries",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            if (incomingTrips.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    "No incoming deliveries.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),

            Expanded(
              child: ListView(
                children: incomingTrips
                    .map(
                      (trip) => Column(
                        children: [
                          TripStatusCard(
                            trip: trip,
                            role: UserRole.hardwareOwner,
                          ),
                          if (trip.status == TripStatus.atHardware)
                            FilledButton.icon(
                              onPressed: () {
                                trip.status = TripStatus.completed;
                                MockDatabase.hardwareQuota -=
                                    trip.truck.capacity;
                                trip.licenseKey = "EXPIRED";
                                _refresh();
                              },
                              icon: const Icon(Icons.inventory),
                              label: const Text("CONFIRM RECEIPT (UNLOAD)"),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                            ),
                          const Divider(),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// --- SETTINGS SCREEN ---
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: MockDatabase.username);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Account Settings",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 16),

          // Profile Photo Selector
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: MockDatabase.profileColor,
                  child: Text(
                    MockDatabase.username.isNotEmpty
                        ? MockDatabase.username[0]
                        : "U",
                    style: const TextStyle(fontSize: 30, color: Colors.white),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () {
                      // Cycle colors for demo
                      setState(() {
                        MockDatabase.profileColor =
                            Colors.primaries[Random().nextInt(
                              Colors.primaries.length,
                            )];
                      });
                    },
                    child: const CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.edit, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: "Display Name",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              setState(() {
                MockDatabase.username = _nameController.text;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Username updated!")),
              );
            },
            child: const Text("Save Changes"),
          ),
          const Divider(height: 40),
          const Text(
            "Danger Zone",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              // Delete account logic
              MockDatabase.username = "User";
              MockDatabase.currentUserRoles = [];
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const GeoTrustApp()),
                (r) => false,
              );
            },
            icon: const Icon(Icons.delete_forever),
            label: const Text("Delete Account"),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

// --- ABOUT SCREEN ---
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("About Us")),
      body: const Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(Icons.security_update_good, size: 80, color: Colors.teal),
            SizedBox(height: 20),
            Text(
              "GeoTrust 1.0",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text("Version 1.0.0"),
            SizedBox(height: 20),
            Text(
              "GeoTrust is a secure sand transportation ledger designed to ensure transparency and accountability in the supply chain. Built with Flutter and Material 3.",
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// --- CONTACT SCREEN ---
class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Contact Us")),
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.email),
            title: Text("Email"),
            subtitle: Text("support@geotrust.com"),
          ),
          ListTile(
            leading: Icon(Icons.phone),
            title: Text("Phone"),
            subtitle: Text("+94123456789"),
          ),
          ListTile(
            leading: Icon(Icons.location_on),
            title: Text("Address"),
            subtitle: Text("Sri Lanka"),
          ),
        ],
      ),
    );
  }
}

// --- WIDGETS ---

class TripStatusCard extends StatelessWidget {
  final Trip trip;
  final UserRole role;

  const TripStatusCard({super.key, required this.trip, required this.role});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Determine progress
    double progress = 0.1;
    if (trip.status.index >= TripStatus.atMine.index) progress = 0.3;
    if (trip.status.index >= TripStatus.onTrip.index) progress = 0.6;
    if (trip.status.index >= TripStatus.atHardware.index) progress = 0.9;
    if (trip.status.index == TripStatus.completed.index) progress = 1.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "CURRENT DELIVERY",
                  style: TextStyle(
                    color: colorScheme.outline,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (trip.licenseKey != "PENDING")
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      trip.licenseKey,
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              trip.status.name.toUpperCase(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Mine", style: TextStyle(fontSize: 10)),
                const Text("Hardware", style: TextStyle(fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Simple informative banner
class InfoBanner extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool isSuccess;

  const InfoBanner({
    super.key,
    required this.text,
    required this.icon,
    this.isSuccess = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSuccess ? Colors.green : Colors.grey;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// Mimics a "Slide to Unlock" button (Simulated with a button for now)
class ActionSlider extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onConfirmed;

  const ActionSlider({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onConfirmed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
