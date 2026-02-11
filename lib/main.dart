import 'package:flutter/material.dart';

void main() {
  runApp(const GeoTrustApp());
}

// --- DATA MODELS ---
enum TripStatus {
  assigned,      // Driver assigned, on way to mine
  atMine,        // Driver arrived at mine
  loading,       // Mine owner is loading sand
  loaded,        // Loading done, ready for license
  onTrip,        // License Issued! Driving to hardware
  atHardware,    // Arrived at destination
  completed      // Unloaded, license expired
}

// --- MAIN APP ---
class GeoTrustApp extends StatelessWidget {
  const GeoTrustApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoTrust Prototype',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: const RoleSelectionScreen(),
    );
  }
}

// --- SCREEN 1: ROLE SELECTION ---
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("GeoTrust Login")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text("Select Your Role", style: TextStyle(fontSize: 20)),
            const SizedBox(height: 40),
            _RoleButton(
              label: "Truck Driver",
              icon: Icons.local_shipping,
              color: Colors.blue,
              onTap: () => _nav(context, const DriverScreen()),
            ),
            _RoleButton(
              label: "Mine Owner",
              icon: Icons.engineering,
              color: Colors.orange,
              onTap: () => _nav(context, const MineOwnerScreen()),
            ),
            _RoleButton(
              label: "Hardware Owner",
              icon: Icons.store,
              color: Colors.green,
              onTap: () => _nav(context, const HardwareOwnerScreen()),
            ),
          ],
        ),
      ),
    );
  }

  void _nav(BuildContext ctx, Widget page) {
    Navigator.push(ctx, MaterialPageRoute(builder: (c) => page));
  }
}

class _RoleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoleButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 40),
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white),
        label: Text(label, style: const TextStyle(fontSize: 18, color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          minimumSize: const Size(double.infinity, 50),
        ),
        onPressed: onTap,
      ),
    );
  }
}

// --- GLOBAL STATE (SIMULATION) ---
// In the real app, this would be in Firebase.
class MockDatabase {
  static TripStatus currentStatus = TripStatus.assigned;
  static int mineQuota = 500; // Starting Quota
  static String licenseKey = "PENDING";
}

// --- SCREEN 2: DRIVER VIEW ---
class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key});

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  void _refresh() => setState(() {}); // Hack to refresh UI for demo

  @override
  Widget build(BuildContext context) {
    var status = MockDatabase.currentStatus;

    return Scaffold(
      appBar: AppBar(title: const Text("Driver Dashboard"), backgroundColor: Colors.blue, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _StatusCard(status: status),
            const Spacer(),

            // LOGIC: Buttons change based on Status
            if (status == TripStatus.assigned)
              _ActionButton(
                label: "ARRIVED AT MINE",
                color: Colors.orange,
                onPressed: () {
                  MockDatabase.currentStatus = TripStatus.atMine;
                  _refresh();
                },
              ),

            if (status == TripStatus.atMine)
              const InfoBox(text: "Waiting for Mine Owner to load truck..."),

            if (status == TripStatus.loading)
              const InfoBox(text: "Loading in progress..."),

            if (status == TripStatus.loaded)
              _ActionButton(
                label: "START TRIP (GET LICENSE)",
                color: Colors.green,
                onPressed: () {
                  // The "Transaction"
                  MockDatabase.currentStatus = TripStatus.onTrip;
                  MockDatabase.mineQuota -= 1; // Deduct Quota
                  MockDatabase.licenseKey = "LIC-9988-VALID"; // Generate License
                  _refresh();
                },
              ),

            if (status == TripStatus.onTrip)
              _ActionButton(
                label: "ARRIVED AT HARDWARE",
                color: Colors.purple,
                onPressed: () {
                  MockDatabase.currentStatus = TripStatus.atHardware;
                  _refresh();
                },
              ),

            if (status == TripStatus.atHardware)
              const InfoBox(text: "Waiting for Buyer to confirm unload..."),

            if (status == TripStatus.completed)
              const InfoBox(text: "Trip Complete. License Expired.", isSuccess: true),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// --- SCREEN 3: MINE OWNER VIEW ---
class MineOwnerScreen extends StatefulWidget {
  const MineOwnerScreen({super.key});
  @override
  State<MineOwnerScreen> createState() => _MineOwnerScreenState();
}

class _MineOwnerScreenState extends State<MineOwnerScreen> {
  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    var status = MockDatabase.currentStatus;

    return Scaffold(
      appBar: AppBar(title: const Text("Mine Owner"), backgroundColor: Colors.orange, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Remaining Quota: ${MockDatabase.mineQuota} Cubes",
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Divider(),
            _StatusCard(status: status),
            const Spacer(),

            if (status == TripStatus.atMine)
              _ActionButton(
                label: "CONFIRM TRUCK & START LOADING",
                color: Colors.orange,
                onPressed: () {
                  MockDatabase.currentStatus = TripStatus.loading;
                  _refresh();
                },
              ),

            if (status == TripStatus.loading)
              _ActionButton(
                label: "LOADING COMPLETE",
                color: Colors.green,
                onPressed: () {
                  MockDatabase.currentStatus = TripStatus.loaded;
                  _refresh();
                },
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// --- SCREEN 4: HARDWARE OWNER VIEW ---
class HardwareOwnerScreen extends StatefulWidget {
  const HardwareOwnerScreen({super.key});
  @override
  State<HardwareOwnerScreen> createState() => _HardwareOwnerScreenState();
}

class _HardwareOwnerScreenState extends State<HardwareOwnerScreen> {
  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    var status = MockDatabase.currentStatus;

    return Scaffold(
      appBar: AppBar(title: const Text("Hardware Buyer"), backgroundColor: Colors.green, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _StatusCard(status: status),
            const Spacer(),

            if (status == TripStatus.atHardware)
              _ActionButton(
                label: "CONFIRM UNLOAD",
                color: Colors.green,
                onPressed: () {
                  MockDatabase.currentStatus = TripStatus.completed;
                  MockDatabase.licenseKey = "EXPIRED";
                  _refresh();
                },
              ),

            if (status == TripStatus.completed)
              const InfoBox(text: "Sand Received. Transaction Closed.", isSuccess: true),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// --- WIDGETS ---

class _StatusCard extends StatelessWidget {
  final TripStatus status;
  const _StatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text("CURRENT TRIP STATUS", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            Text(status.name.toUpperCase(),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            const SizedBox(height: 10),
            if (MockDatabase.licenseKey != "PENDING")
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.amber[100],
                child: Text("LICENSE: ${MockDatabase.licenseKey}", style: const TextStyle(fontWeight: FontWeight.bold)),
              )
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;
  const _ActionButton({required this.label, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: color),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}

class InfoBox extends StatelessWidget {
  final String text;
  final bool isSuccess;
  const InfoBox({super.key, required this.text, this.isSuccess = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      width: double.infinity,
      decoration: BoxDecoration(
        color: isSuccess ? Colors.green[100] : Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
    );
  }
}