part of '../app.dart';

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

    if (_searchQuery.isNotEmpty) {
      mines = mines.where((m) => (m['name'] ?? 'Mine').toLowerCase().contains(_searchQuery.toLowerCase())).toList();
      hardwares = hardwares.where((h) => (h['name'] ?? 'Hardware').toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    return DefaultTabController(
      length: 2,
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
                      hintText: 'Search locations...',
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

  @override
  void dispose() {
    vehicleCtrl.dispose();
    qtyCtrl.dispose();
    super.dispose();
  }

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
          decoration: InputDecoration(
            labelText: 'Transport Truck No. (e.g. WP LA-1234)',
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
                    final success = await ledger.issueNewPermit(
                      vehicleCtrl.text,
                      qty,
                      _selectedDate,
                    );
                    if (mounted) setState(() => _isSubmitting = false);
                    if (success && context.mounted) {
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
                        const SnackBar(
                          content: Text('ERROR: Insufficient Quota!'),
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

class _OngoingPanel extends StatelessWidget {
  const _OngoingPanel();

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerService>();
    final ongoingPermits = ledger.permits.where((p) => p.status != PermitStatus.completed).toList();

    if (ongoingPermits.isEmpty) {
      return const EmptyState(
        icon: Icons.local_shipping_outlined,
        message: 'No active or draft permits.',
      );
    }

    return RefreshIndicator(
      onRefresh: ledger.refreshData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Active & Draft Permits',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...ongoingPermits.map((permit) => _buildManagerCard(context, ledger, permit)),
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
            Text('Vehicle: ${permit.truckNumber} | ${permit.volumeCubes} Cubes'),
            if (permit.permitCode != null)
              const Text(
                'Driver Access Code: ',
                style: TextStyle(
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
                    decoration: InputDecoration(
                      labelText: 'Truck Registration',
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
                          final success = await ledger.issueMiniPermit(
                            vehicleCtrl.text,
                            qty,
                            DateTime.now(),
                          );
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          if (success && screenContext.mounted) {
                            ScaffoldMessenger.of(screenContext).showSnackBar(
                              const SnackBar(
                                content: Text('Mini Permit Issued!'),
                              ),
                            );
                          } else if (screenContext.mounted) {
                            ScaffoldMessenger.of(screenContext).showSnackBar(
                              const SnackBar(
                                content: Text('Error: Must be < 5 cubes & within inventory!'),
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
            Text('Vehicle: ${permit.truckNumber} | ${permit.volumeCubes} Cubes'),
            if (permit.permitCode != null)
              const Text(
                'Driver Access Code: ',
                style: TextStyle(
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
