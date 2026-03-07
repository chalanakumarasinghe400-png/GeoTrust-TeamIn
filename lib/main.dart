import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const GeoTrustApp(),
    ),
  );
}

// =============================================================================
// --- DATA MODELS ---
// =============================================================================

enum PermitStatus { pending, active, completed }

enum UserRole { driver, mineOwner, hardwareOwner, truckOwner }

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.driver:
        return "Transporter (Driver)";
      case UserRole.mineOwner:
        return "Yard Manager (Mine)";
      case UserRole.hardwareOwner:
        return "Hardware Store (Buyer)";
      case UserRole.truckOwner:
        return "Fleet Manager";
    }
  }

  IconData get icon {
    switch (this) {
      case UserRole.driver:
        return Icons.local_shipping;
      case UserRole.mineOwner:
        return Icons.engineering;
      case UserRole.hardwareOwner:
        return Icons.store;
      case UserRole.truckOwner:
        return Icons.rv_hookup;
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

class TransportPermit {
  final String permitId;
  final String vehicleNumber;
  final String materialType;
  final String quantity;
  final String destinationZone;
  final DateTime issueTime;
  final DateTime expiryTime;
  PermitStatus status;

  TransportPermit({
    required this.permitId,
    required this.vehicleNumber,
    required this.materialType,
    required this.quantity,
    required this.destinationZone,
    required this.issueTime,
    required this.expiryTime,
    this.status = PermitStatus.pending,
  });
}

// =============================================================================
// --- STATE MANAGEMENT ---
// =============================================================================

class LedgerService extends ChangeNotifier {
  // --- NEW INVENTORY LOGIC ---
  double yardInventoryCubes = 40.0; // What they currently have in stock
  final double maxYardCapacity =
      100.0; // The max GSMB limit they are allowed to hold

  final List<TransportPermit> _permits = [
    TransportPermit(
      permitId: "GSMB-2026-001",
      vehicleNumber: "WP-LK-4592",
      materialType: "River Sand",
      quantity: "3 Cubes",
      destinationZone: "Western Province",
      issueTime: DateTime.now().subtract(const Duration(hours: 1)),
      expiryTime: DateTime.now().add(const Duration(hours: 11)),
      status: PermitStatus.active,
    ),
  ];

  String currentUsername = "Saman Perera";
  String currentVehicleNumber = "WP-LK-4592";
  UserRole? currentUserRole;

  List<TransportPermit> get permits => List.unmodifiable(_permits);

  // --- UPDATED TO RETURN BOOLEAN FOR INVENTORY CHECK ---
  bool issueNewPermit(
    String vehicle,
    String material,
    String qty,
    String zone,
  ) {
    // Extract the number from the text input (e.g., "3 Cubes" becomes 3.0)
    double requestedQty =
        double.tryParse(qty.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;

    // Reject the permit if they try to sell more than they have
    if (requestedQty > yardInventoryCubes) {
      return false; // Transaction Failed
    }

    // Deduct from the yard inventory
    yardInventoryCubes -= requestedQty;

    _permits.insert(
      0,
      TransportPermit(
        permitId:
            "GSMB-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}",
        vehicleNumber: vehicle,
        materialType: material,
        quantity: qty,
        destinationZone: zone,
        issueTime: DateTime.now(),
        expiryTime: DateTime.now().add(const Duration(hours: 12)),
      ),
    );
    notifyListeners();
    return true; // Transaction Success
  }

  // ... (Leave the rest of the dispatchJourneyViaBLE and other functions exactly as they are)

  void dispatchJourneyViaBLE(String permitId) {
    final permit = _permits.firstWhere((p) => p.permitId == permitId);
    permit.status = PermitStatus.active;
    notifyListeners();
  }

  void completeJourneyViaBLE(String permitId) {
    final permit = _permits.firstWhere((p) => p.permitId == permitId);
    permit.status = PermitStatus.completed;
    notifyListeners();
  }

  // --- FLEET MANAGEMENT LOGIC ---
  void reassignDriverVehicle(String newVehicleNumber) {
    currentVehicleNumber = newVehicleNumber;
    notifyListeners();
  }
}

// =============================================================================
// --- FLUTTER UI LAYER ---
// =============================================================================

class ThemeProvider extends ChangeNotifier {
  final ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;
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
              colorSchemeSeed: const Color(0xFF006C50),
            ),
            home: const LoginScreen(),
          );
        },
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ledger = context.read<LedgerService>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.shield_moon,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  "GeoTrust Transport",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Double-Handshake Logistics System",
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 40),
                _buildLoginButton(
                  context,
                  ledger,
                  UserRole.mineOwner,
                  const MineOwnerScreen(),
                ),
                const SizedBox(height: 12),
                _buildLoginButton(
                  context,
                  ledger,
                  UserRole.driver,
                  const DriverScreen(),
                ),
                const SizedBox(height: 12),
                _buildLoginButton(
                  context,
                  ledger,
                  UserRole.hardwareOwner,
                  const HardwareOwnerScreen(),
                ),
                const SizedBox(height: 12),
                _buildLoginButton(
                  context,
                  ledger,
                  UserRole.truckOwner,
                  const TruckOwnerScreen(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton(
    BuildContext context,
    LedgerService ledger,
    UserRole role,
    Widget destination,
  ) {
    return FilledButton.icon(
      onPressed: () {
        ledger.currentUserRole = role;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => destination),
        );
      },
      icon: Icon(role.icon),
      label: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text("LOGIN AS ${role.name.toUpperCase()}"),
      ),
      style: FilledButton.styleFrom(backgroundColor: role.color),
    );
  }
}

// --- 1. YARD MANAGER (MINE OWNER) ---
class MineOwnerScreen extends StatelessWidget {
  const MineOwnerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerService>();
    return Scaffold(
      appBar: AppBar(title: const Text("Yard Manager Dashboard")),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showIssuePermitDialog(context, ledger),
        icon: const Icon(Icons.note_add),
        label: const Text("Draft Permit"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- NEW INVENTORY VISUALIZER ---
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    "Yard Inventory Status",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: ledger.yardInventoryCubes / ledger.maxYardCapacity,
                    minHeight: 12,
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor: Colors.grey.shade300,
                    color: ledger.yardInventoryCubes < 10
                        ? Colors.red
                        : Colors.green, // Turns red if low
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${ledger.yardInventoryCubes} / ${ledger.maxYardCapacity} Cubes Available",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: ledger.yardInventoryCubes < 10
                          ? Colors.red
                          : Colors.green.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Yard Logistics",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...ledger.permits.map(
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
                Text(
                  permit.permitId,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                _buildStatusChip(permit.status),
              ],
            ),
            const Divider(),
            Text("Vehicle: ${permit.vehicleNumber} | ${permit.quantity}"),
            const SizedBox(height: 8),
            if (permit.status == PermitStatus.pending)
              FilledButton.icon(
                onPressed: () =>
                    _simulateOriginBLEScan(context, ledger, permit.permitId),
                icon: const Icon(Icons.bluetooth_searching),
                label: const Text("SCAN DRIVER (DISPATCH)"),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showIssuePermitDialog(BuildContext context, LedgerService ledger) {
    final vehicleCtrl = TextEditingController();
    final materialCtrl = TextEditingController(text: "River Sand");
    final qtyCtrl = TextEditingController(text: "3 Cubes");
    final zoneCtrl = TextEditingController(text: "Western Province");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Draft New Transport Permit"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: vehicleCtrl,
                decoration: const InputDecoration(
                  labelText: "Vehicle No.",
                  hintText: "WP-XX-1234",
                ),
              ),
              TextField(
                controller: materialCtrl,
                decoration: const InputDecoration(labelText: "Material"),
              ),
              TextField(
                controller: qtyCtrl,
                decoration: const InputDecoration(
                  labelText: "Quantity (e.g. 3 Cubes)",
                ),
              ),
              TextField(
                controller: zoneCtrl,
                decoration: const InputDecoration(
                  labelText: "Destination Zone",
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              // --- NEW INVENTORY CHECK LOGIC ---
              bool success = ledger.issueNewPermit(
                vehicleCtrl.text,
                materialCtrl.text,
                qtyCtrl.text,
                zoneCtrl.text,
              );
              Navigator.pop(context); // Close the dialog

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Draft Permit Saved!"),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                // Show error if they try to sell more than they have
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "ERROR: Insufficient Yard Inventory! Cannot issue permit.",
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text("SAVE DRAFT"),
          ),
        ],
      ),
    );
  }

  void _simulateOriginBLEScan(
    BuildContext context,
    LedgerService ledger,
    String permitId,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Scanning Yard Radius (BLE)..."),
          ],
        ),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (!context.mounted) {
        return;
      }
      Navigator.pop(context);
      ledger.dispatchJourneyViaBLE(permitId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Driver verified in yard. Truck dispatched!"),
          backgroundColor: Colors.green,
        ),
      );
    });
  }
}

// --- 2. TRANSPORTER (DRIVER) ---
class DriverScreen extends StatelessWidget {
  const DriverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerService>();
    final myPermits = ledger.permits
        .where((p) => p.vehicleNumber == ledger.currentVehicleNumber)
        .toList();
    final activePermit = myPermits
        .where((p) => p.status == PermitStatus.active)
        .firstOrNull;
    final pendingPermit = myPermits
        .where((p) => p.status == PermitStatus.pending)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Transporter Dashboard"),
        backgroundColor: UserRole.driver.color,
        foregroundColor: Colors.white,
      ),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Registered Vehicle: ${ledger.currentVehicleNumber}",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),

            if (pendingPermit != null) ...[
              const Text(
                "LOADING AT YARD",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.warning_amber,
                        color: Colors.orange,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Permit ${pendingPermit.permitId} drafted.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        "Broadcast your location to the Yard Manager to legally start the journey.",
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _simulateBLEBroadcast(
                          context,
                          "Origin verification broadcasting...",
                        ),
                        icon: const Icon(Icons.bluetooth_audio),
                        label: const Text("BROADCAST TO YARD MANAGER"),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            if (activePermit != null) ...[
              const Text(
                "ACTIVE JOURNEY",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: PermitCard(permit: activePermit)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _simulateBLEBroadcast(
                  context,
                  "Unload verification broadcasting...",
                ),
                icon: const Icon(Icons.bluetooth_audio, size: 28),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    "BROADCAST TO HARDWARE STORE",
                    style: TextStyle(fontSize: 15),
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blue.shade800,
                ),
              ),
            ],

            if (activePermit == null && pendingPermit == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 50),
                  child: Text(
                    "No assignments.\nWaiting for Yard Manager.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _simulateBLEBroadcast(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bluetooth_searching, size: 80, color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("STOP BROADCAST"),
          ),
        ],
      ),
    );
  }
}

// --- 3. HARDWARE OWNER (BUYER) ---
class HardwareOwnerScreen extends StatelessWidget {
  const HardwareOwnerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerService>();
    final incomingPermits = ledger.permits
        .where((p) => p.status == PermitStatus.active)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Hardware Store"),
        backgroundColor: UserRole.hardwareOwner.color,
        foregroundColor: Colors.white,
      ),
      drawer: const AppDrawer(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Incoming Deliveries",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...incomingPermits.map(
            (permit) => Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Vehicle: ${permit.vehicleNumber}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _simulateDestinationBLEScan(
                        context,
                        ledger,
                        permit.permitId,
                      ),
                      icon: const Icon(Icons.bluetooth_searching),
                      label: const Text("SCAN TRUCK TO RECEIVE"),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.purple.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _simulateDestinationBLEScan(
    BuildContext context,
    LedgerService ledger,
    String permitId,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Scanning Unload Area..."),
          ],
        ),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (!context.mounted) {
        return;
      }
      Navigator.pop(context);
      ledger.completeJourneyViaBLE(permitId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Delivery Completed!"),
          backgroundColor: Colors.green,
        ),
      );
    });
  }
}

// --- 4. TRUCK OWNER (FLEET MANAGER) ---
class TruckOwnerScreen extends StatelessWidget {
  const TruckOwnerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Fleet Manager Dashboard"),
        backgroundColor: UserRole.truckOwner.color,
        foregroundColor: Colors.white,
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAssignDriverDialog(context, ledger),
        icon: const Icon(Icons.assignment_ind),
        label: const Text("Assign Driver"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Active Fleet Roster",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          Card(
            color: Colors.indigo.shade50,
            child: ListTile(
              leading: const Icon(Icons.person, color: Colors.indigo),
              title: Text("Driver: ${ledger.currentUsername}"),
              subtitle: Text(
                "Currently Assigned to: ${ledger.currentVehicleNumber}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              trailing: const Icon(Icons.local_shipping, color: Colors.indigo),
            ),
          ),

          const Divider(height: 32),
          const Text(
            "Fleet GPS Tracking",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...ledger.permits.map((permit) => PermitCard(permit: permit)),
        ],
      ),
    );
  }

  void _showAssignDriverDialog(BuildContext context, LedgerService ledger) {
    final vehicleCtrl = TextEditingController(
      text: ledger.currentVehicleNumber,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Assign Vehicle to Driver"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Select which vehicle Saman Perera will operate today.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: vehicleCtrl,
              decoration: const InputDecoration(
                labelText: "Vehicle Registration No.",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          FilledButton(
            onPressed: () {
              if (vehicleCtrl.text.isNotEmpty) {
                ledger.reassignDriverVehicle(vehicleCtrl.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Driver roster updated!"),
                    backgroundColor: Colors.indigo,
                  ),
                );
              }
            },
            child: const Text("ASSIGN TRUCK"),
          ),
        ],
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
    final role = ledger.currentUserRole;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: role?.color ?? Colors.blueGrey),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.account_circle, size: 48, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  ledger.currentUsername,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                Text(
                  role?.displayName ?? "Guest",
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
          _buildSwitchTile(
            context,
            ledger,
            UserRole.driver,
            const DriverScreen(),
          ),
          _buildSwitchTile(
            context,
            ledger,
            UserRole.truckOwner,
            const TruckOwnerScreen(),
          ),
          _buildSwitchTile(
            context,
            ledger,
            UserRole.mineOwner,
            const MineOwnerScreen(),
          ),
          _buildSwitchTile(
            context,
            ledger,
            UserRole.hardwareOwner,
            const HardwareOwnerScreen(),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              "Logout User",
              style: TextStyle(color: Colors.red),
            ),
            onTap: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (r) => false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context,
    LedgerService ledger,
    UserRole targetRole,
    Widget destination,
  ) {
    final isActive = ledger.currentUserRole == targetRole;
    return ListTile(
      leading: Icon(
        targetRole.icon,
        color: isActive ? targetRole.color : Colors.grey,
      ),
      title: Text(
        targetRole.displayName,
        style: TextStyle(
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          color: isActive ? targetRole.color : Colors.black87,
        ),
      ),
      trailing: isActive
          ? const Icon(Icons.check_circle, color: Colors.green, size: 16)
          : null,
      onTap: () {
        if (!isActive) {
          ledger.currentUserRole = targetRole;
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
}

class PermitCard extends StatelessWidget {
  final TransportPermit permit;
  const PermitCard({super.key, required this.permit});

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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  permit.permitId,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                _buildStatusChip(permit.status),
              ],
            ),
            const Divider(),
            Text(
              "Vehicle: ${permit.vehicleNumber} | ${permit.quantity} ${permit.materialType}",
            ),
            Text(
              "Zone: ${permit.destinationZone}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Text(
              "Expires: ${permit.expiryTime.hour}:${permit.expiryTime.minute.toString().padLeft(2, '0')}",
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
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
    }
  }
}

Widget _buildStatusChip(PermitStatus status) {
  String text = "";
  Color color = Colors.grey;
  if (status == PermitStatus.pending) {
    text = "DRAFT";
    color = Colors.orange;
  } else if (status == PermitStatus.active) {
    text = "ACTIVE";
    color = Colors.green;
  } else if (status == PermitStatus.completed) {
    text = "COMPLETED";
    color = Colors.grey;
  }

  return Chip(
    label: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    ),
    backgroundColor: color,
    padding: EdgeInsets.zero,
  );
}
