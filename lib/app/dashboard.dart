part of '../app.dart';

// Shared status chip renderer used across multiple panels.
Widget _buildStatusChip(PermitStatus status) {
  switch (status) {
    case PermitStatus.pending:
      return const Chip(
        label: Text('PENDING'),
        backgroundColor: Colors.amber,
      );
    case PermitStatus.active:
      return const Chip(
        label: Text('ACTIVE'),
        backgroundColor: Colors.green,
        labelStyle: TextStyle(color: Colors.white),
      );
    case PermitStatus.completed:
      return const Chip(
        label: Text('COMPLETED'),
        backgroundColor: Colors.grey,
      );
    default:
      return Chip(
        label: Text(status.toString().split('.').last.toUpperCase()),
      );
  }
}

class RolePortalScreen extends StatefulWidget {
  const RolePortalScreen({super.key});

  @override
  State<RolePortalScreen> createState() => _RolePortalScreenState();
}

class _RolePortalScreenState extends State<RolePortalScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerService>();
    final user = ledger.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not Logged In')));
    }

    var mines = ledger.userLocations
        .where((loc) => loc['location_type'] == 'MINE' || loc['location_type'] == 'MINE_OWNER')
        .toList();
    var hardwares = ledger.userLocations
        .where((loc) => loc['location_type'] != 'MINE' && loc['location_type'] != 'MINE_OWNER')
        .toList();
    var trucks = ledger.userTrucks;

    if (_searchQuery.isNotEmpty) {
      mines = mines.where((m) => (m['name'] ?? 'Mine').toLowerCase().contains(_searchQuery.toLowerCase())).toList();
      hardwares = hardwares.where((h) => (h['name'] ?? 'Hardware').toLowerCase().contains(_searchQuery.toLowerCase())).toList();
      trucks = trucks.where((t) => (t['number_plate'] ?? 'Truck').toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 75,
          title: Text(
            'Welcome ${user.name}!',
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
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search locations or trucks...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.black26 : Colors.white.withOpacity(0.8),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                ),
                const TabBar(
                  tabs: [
                    Tab(text: 'Mines', icon: Icon(Icons.landscape)),
                    Tab(text: 'Hardwares', icon: Icon(Icons.store)),
                    Tab(text: 'Trucks', icon: Icon(Icons.local_shipping)),
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
            _buildTruckList(context, ledger, trucks),
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
        message: isMine ? 'No mines assigned to your account.' : 'No hardware stores assigned to your account.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: locations.length,
      itemBuilder: (context, index) {
        final loc = locations[index];
        final title = loc['name'] ?? (isMine ? 'Yard Manager (Mine)' : 'Hardware Store (Buyer)');
        final inventory = (loc['inventory_cubes'] as num?)?.toDouble() ?? 0.0;
        final isQuotaOver = isMine && inventory <= 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _buildPortalCard(
            context: context,
            ledger: ledger,
            title: title,
            icon: isMine ? Icons.landscape : Icons.store,
            color: isMine ? Colors.orange : Colors.purple,
            destination: isMine ? MineOwnerScreen(locationName: title) : HardwareOwnerScreen(locationName: title),
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
        side: isDark ? BorderSide(color: color.shade400.withOpacity(0.6), width: 1.5) : BorderSide.none,
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
                'Tap to manage location',
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

  Widget _buildTruckList(
    BuildContext context,
    LedgerService ledger,
    List<Map<String, dynamic>> trucks,
  ) {
    if (trucks.isEmpty) {
      return const EmptyState(
        icon: Icons.local_shipping_outlined,
        message: 'No trucks registered or assigned to your account.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: trucks.length,
      itemBuilder: (context, index) {
        final truck = trucks[index];
        final numberPlate = truck['number_plate'] ?? 'Unknown Truck';
        final capacity = (truck['capacity'] as num?)?.toDouble() ?? 0.0;
        final chassisNumber = truck['chassis_number'] ?? 'N/A';
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _buildTruckPortalCard(
            context: context,
            ledger: ledger,
            numberPlate: numberPlate,
            capacity: capacity,
            chassisNumber: chassisNumber,
          ),
        );
      },
    );
  }

  Widget _buildTruckPortalCard({
    required BuildContext context,
    required LedgerService ledger,
    required String numberPlate,
    required double capacity,
    required String chassisNumber,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = Colors.blue;

    return Card(
      elevation: isDark ? 0 : 6,
      shadowColor: isDark ? Colors.transparent : color.withOpacity(0.4),
      color: isDark ? color.withOpacity(0.15) : color.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: isDark ? BorderSide(color: color.shade400.withOpacity(0.6), width: 1.5) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TruckOwnerScreen(
                numberPlate: numberPlate,
                capacity: capacity,
                chassisNumber: chassisNumber,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: isDark ? color.shade400 : color,
                child: const Icon(Icons.local_shipping, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                numberPlate,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: isDark ? Colors.white : color.shade900,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Capacity: ${capacity.toStringAsFixed(1)} m³',
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

class TruckOwnerScreen extends StatelessWidget {
  final String numberPlate;
  final double capacity;
  final String chassisNumber;

  const TruckOwnerScreen({
    super.key,
    required this.numberPlate,
    required this.capacity,
    required this.chassisNumber,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ledger = context.watch<LedgerService>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Truck: $numberPlate'),
        backgroundColor: isDark ? Colors.blue.shade900 : Colors.blue.shade700,
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
      ),
      drawer: const AppDrawer(),
      body: FutureBuilder<List<TransportPermit>>(
        future: ledger.getPermitsForTruck(numberPlate),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading permits: ${snapshot.error}'));
          }
          final permits = snapshot.data ?? [];
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: isDark ? Colors.blue.shade900.withOpacity(0.2) : Colors.blue.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: isDark ? BorderSide(color: Colors.blue.shade400.withOpacity(0.5)) : BorderSide.none,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Truck Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: isDark ? Colors.blue.shade200 : Colors.blue.shade900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow('Plate Number', numberPlate, isDark),
                        _buildDetailRow('Chassis Number', chassisNumber, isDark),
                        _buildDetailRow('Capacity', '${capacity.toStringAsFixed(1)} m³', isDark),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Transport Permits History',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: permits.isEmpty
                      ? const Center(
                          child: Text(
                            'No permits associated with this truck.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: permits.length,
                          itemBuilder: (context, index) {
                            final permit = permits[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: PermitCard(permit: permit),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

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
              Tab(text: 'Remaining', icon: Icon(Icons.inventory)),
              Tab(text: 'On going', icon: Icon(Icons.local_shipping)),
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
  late LedgerService _ledger;

  @override
  void initState() {
    super.initState();
    _ledger = context.read<LedgerService>();
    _ledger.addListener(_onLedgerChanged);
  }

  void _onLedgerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ledger.removeListener(_onLedgerChanged);
    vehicleCtrl.dispose();
    qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ledger = _ledger;
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
                    'Mine Inventory Status',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: ledger.currentInventoryCubes / ledger.currentMaxCapacity,
                    minHeight: 12,
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor: Colors.grey.shade300,
                    color: ledger.currentInventoryCubes < 10 ? Colors.red : Colors.green,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${ledger.currentInventoryCubes} / ${ledger.currentMaxCapacity} Cubes Available',
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
                    'Draft New License',
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
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            TruckNumberFormatter(),
          ],
          decoration: InputDecoration(
            labelText: 'Transport Truck No. (e.g. NW AA - 1234)',
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
            labelText: 'Number of Cubes',
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
                'Transport Date: ${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final initial = _selectedDate.isBefore(today) ? today : _selectedDate;

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
              label: const Text('Change'),
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
                    if (vehicleCtrl.text.trim().isEmpty || qtyCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter vehicle number and quantity.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    final qty = double.tryParse(qtyCtrl.text) ?? 0.0;
                    if (qty <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Quantity must be greater than zero.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    setState(() => _isSubmitting = true);
                    final errorMsg = await ledger.issueNewPermit(
                      vehicleCtrl.text.trim(),
                      qty,
                      _selectedDate,
                    );
                    if (mounted) setState(() => _isSubmitting = false);
                    if (errorMsg == null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Draft Permit Created!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      vehicleCtrl.clear();
                      qtyCtrl.clear();
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(errorMsg ?? 'ERROR: Failed to issue permit.'),
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
                : const Text('SAVE DRAFT LICENSE'),
          ),
        ),
      ],
    );
  }
}


class _OngoingPanel extends StatefulWidget {
  const _OngoingPanel();

  @override
  State<_OngoingPanel> createState() => _OngoingPanelState();
}

class _OngoingPanelState extends State<_OngoingPanel> {
  late LedgerService _ledger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Unsubscribe from old instance (if any) and subscribe to the current one
    final newLedger = context.read<LedgerService>();
    if (newLedger != _ledger) {
      try { _ledger.removeListener(_onLedgerChanged); } catch (_) {}
      _ledger = newLedger;
      _ledger.addListener(_onLedgerChanged);
    }
  }

  @override
  void initState() {
    super.initState();
    _ledger = context.read<LedgerService>();
    _ledger.addListener(_onLedgerChanged);
  }

  void _onLedgerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ledger.removeListener(_onLedgerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ongoingPermits = _ledger.permits
        .where((p) => p.status != PermitStatus.completed)
        .toList();

    if (ongoingPermits.isEmpty) {
      return const EmptyState(
        icon: Icons.local_shipping_outlined,
        message: 'No active or draft permits.',
      );
    }

    return RefreshIndicator(
      onRefresh: _ledger.refreshData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Active & Draft Permits',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...ongoingPermits.map((permit) => _buildManagerCard(context, _ledger, permit)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(PermitStatus status) {
    // Provide a small visual status indicator for permits
    switch (status) {
      case PermitStatus.pending:
        return const Chip(
          label: Text('PENDING'),
          backgroundColor: Colors.amber,
        );
      case PermitStatus.active:
        return const Chip(
          label: Text('ACTIVE'),
          backgroundColor: Colors.green,
          labelStyle: TextStyle(color: Colors.white),
        );
      case PermitStatus.completed:
        return const Chip(
          label: Text('COMPLETED'),
          backgroundColor: Colors.grey,
        );
      default:
        return Chip(
          label: Text(status.toString().split('.').last.toUpperCase()),
        );
    }
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
                Expanded(
                  child: Text(
                    'ID: ${permit.id.length >= 8 ? permit.id.substring(0, 8).toUpperCase() : permit.id.toUpperCase()}',
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
              'Vehicle: ${permit.truckNumberPlate}  |  ${permit.noOfCubes} Cubes',
              style: const TextStyle(fontSize: 14),
            ),
            if (permit.permitCode != null && !permit.permitCode!.startsWith('DRAFT-'))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Driver Access Code: ${permit.permitCode}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    fontSize: 15,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            if (permit.status == PermitStatus.pending)
              FilledButton.icon(
                onPressed: () {
                  ledger.activatePermitAndGenerateCode(permit.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Truck Dispatched! Give code to driver.'),
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle),
                label: const Text('DONE LOADING (DISPATCH)'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amber,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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
        // TransportPermit may expose createdAt or created_at or issuedAt depending on version.
        final dynamic p = permit as dynamic;
        DateTime? created;
        try {
          created = p.createdAt as DateTime?;
        } catch (_) {
          try {
            created = p.created_at as DateTime?;
          } catch (_) {
            try {
              created = p.issuedAt as DateTime?;
            } catch (_) {
              created = null;
            }
          }
        }
        final expirationDate = (created ?? DateTime.now()).add(const Duration(hours: 24));
        _updateTimeLeft(expirationDate);
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          _updateTimeLeft(expirationDate);
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
          content: Text('Permit Expired and Cancelled!'),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transporter Dashboard'),
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
                'ACTIVE JOURNEY',
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
                      'EXPIRES IN: ${_timeLeft.inHours.toString().padLeft(2, '0')}:${(_timeLeft.inMinutes % 60).toString().padLeft(2, '0')}:${(_timeLeft.inSeconds % 60).toString().padLeft(2, '0')}',
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
                                content: Text('Unloaded! Photo & GPS Logged.'),
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
                          'UNLOAD AT DESTINATION',
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
                    'Journey Completed.',
                    style: TextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                    child: const Text('Return to Home'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class HardwareOwnerScreen extends StatelessWidget {
  final String locationName;
  const HardwareOwnerScreen({super.key, required this.locationName});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(locationName),
          backgroundColor: isDark ? Colors.purple.shade900 : UserRole.hardwareOwner.color,
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
              Tab(text: 'Inventory', icon: Icon(Icons.inventory_2)),
              Tab(text: 'Transports', icon: Icon(Icons.local_shipping)),
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
                  const Icon(Icons.inventory_2, size: 56, color: Colors.white),
                  const SizedBox(height: 8),
                  const Text(
                    'Current Sand Inventory',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${ledger.currentInventoryCubes} Cubes',
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
              child: Text('ASSIGN TRANSPORTATION TO HOME (< 5 CUBES)'),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.purple,
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
        var isSubmitting = false;
        return StatefulBuilder(
          builder: (stateContext, setState) {
            return AlertDialog(
              title: const Text('Mini-Permit Assignment'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   TextField(
                    controller: vehicleCtrl,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      TruckNumberFormatter(),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Truck Registration (e.g. NW AA - 1234)',
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
                      labelText: 'Quantity (< 5)',
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
                          if (vehicleCtrl.text.trim().isEmpty || qtyCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text('Please fill all fields.'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }
                          final qty = double.tryParse(qtyCtrl.text) ?? 0.0;
                          if (qty <= 0) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text('Quantity must be greater than zero.'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }
                          setState(() => isSubmitting = true);
                          final errorMsg = await ledger.issueMiniPermit(
                            vehicleCtrl.text.trim(),
                            qty,
                            DateTime.now(),
                          );
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          if (errorMsg == null && screenContext.mounted) {
                            ScaffoldMessenger.of(screenContext).showSnackBar(
                              const SnackBar(
                                content: Text('Mini Permit Issued!'),
                              ),
                            );
                          } else if (screenContext.mounted) {
                            ScaffoldMessenger.of(screenContext).showSnackBar(
                              SnackBar(
                                content: Text(errorMsg ?? 'Error issuing mini permit.'),
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
                      : const Text('ISSUE'),
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
    final ongoingPermits = ledger.permits.where((p) => p.status != PermitStatus.completed).toList();

    if (ongoingPermits.isEmpty) {
      return const EmptyState(
        icon: Icons.fire_truck_outlined,
        message: 'No ongoing mini-permits.',
      );
    }

    return RefreshIndicator(
      onRefresh: ledger.refreshData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Ongoing Mini-Permits',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...ongoingPermits.map((permit) => _buildHardwareManagerCard(context, ledger, permit)),
        ],
      ),
    );
  }

  Widget _buildHardwareManagerCard(
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
                Expanded(
                  child: Text(
                    'ID: ${permit.id.length >= 8 ? permit.id.substring(0, 8).toUpperCase() : permit.id.toUpperCase()}',
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
              'Vehicle: ${permit.truckNumberPlate}  |  ${permit.noOfCubes} Cubes',
              style: const TextStyle(fontSize: 14),
            ),
            if (permit.permitCode != null && !permit.permitCode!.startsWith('DRAFT-'))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Driver Access Code: ${permit.permitCode}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    fontSize: 15,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            if (permit.status == PermitStatus.pending)
              FilledButton.icon(
                onPressed: () {
                  ledger.activatePermitAndGenerateCode(permit.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Transport Dispatched!')),
                  );
                },
                icon: const Icon(Icons.local_shipping),
                label: const Text('DISPATCH TO BUYER'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class TruckNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final isDeleting = newValue.text.length < oldValue.text.length;

    // Strip all formatting characters — work only with raw letters and digits
    String newLetters = newValue.text
        .replaceAll(RegExp(r'[^a-zA-Z]'), '')
        .toUpperCase();
    String newDigits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    final oldLetters = oldValue.text
        .replaceAll(RegExp(r'[^a-zA-Z]'), '')
        .toUpperCase();
    final oldDigits = oldValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Cap at 4 each
    if (newLetters.length > 4) newLetters = newLetters.substring(0, 4);
    if (newDigits.length > 4) newDigits = newDigits.substring(0, 4);

    // If the user pressed backspace but only deleted a separator (raw chars unchanged),
    // manually remove one character: digits first, then letters.
    if (isDeleting && newLetters == oldLetters && newDigits == oldDigits) {
      if (newDigits.isNotEmpty) {
        newDigits = newDigits.substring(0, newDigits.length - 1);
      } else if (newLetters.isNotEmpty) {
        newLetters = newLetters.substring(0, newLetters.length - 1);
      }
    }

    // Build the formatted string
    final buf = StringBuffer();

    for (int i = 0; i < newLetters.length; i++) {
      if (i == 2) buf.write(' '); // insert space after 2nd letter
      buf.write(newLetters[i]);
    }

    // Auto-insert ' - ' immediately once all 4 letters are present
    if (newLetters.length == 4) {
      buf.write(' - ');
      buf.write(newDigits);
    }

    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}               