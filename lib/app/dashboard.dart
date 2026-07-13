part of '../app.dart';

// Shared status chip renderer used across multiple panels.
Widget _buildStatusChip(PermitStatus status) {
  switch (status) {
    case PermitStatus.pending:
      return const Chip(label: Text('PENDING'), backgroundColor: Colors.amber);
    case PermitStatus.active:
      return const Chip(
        label: Text('ACTIVE'),
        backgroundColor: Colors.green,
        labelStyle: TextStyle(color: Colors.white),
      );
    case PermitStatus.completed:
      return const Chip(label: Text('COMPLETED'), backgroundColor: Colors.grey);
    default:
      return Chip(label: Text(status.toString().split('.').last.toUpperCase()));
  }
}

class RolePortalScreen extends StatefulWidget {
  const RolePortalScreen({super.key});

  @override
  State<RolePortalScreen> createState() => _RolePortalScreenState();
}

class _RolePortalScreenState extends State<RolePortalScreen> {
  String _searchQuery = '';
  int _currentIndex = 0; // 0: HUB, 1: MINES, 2: H-WARE, 3: TRUCKS

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerService>();
    final user = ledger.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not Logged In')));
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
    var trucks = ledger.userTrucks;

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
      trucks = trucks
          .where(
            (t) => (t['number_plate'] ?? 'Truck').toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ),
          )
          .toList();
    }

    Widget body;
    if (_currentIndex == 0) {
      body = _buildHubView(context, ledger, mines, hardwares, trucks);
    } else if (_currentIndex == 1) {
      body = Column(
        children: [
          _buildSearchField(),
          Expanded(child: _buildLocationList(context, ledger, mines, true)),
        ],
      );
    } else if (_currentIndex == 2) {
      body = Column(
        children: [
          _buildSearchField(),
          Expanded(
            child: _buildLocationList(context, ledger, hardwares, false),
          ),
        ],
      );
    } else {
      body = Column(
        children: [
          _buildSearchField(),
          Expanded(child: _buildTruckList(context, ledger, trucks)),
        ],
      );
    }

    return AmbientGradientBackground(
      primaryColor: const Color(0xFF0F172A),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Welcome ${user.name}!',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : const Color(0xFF1E293B),
            ),
          ),
          iconTheme: IconThemeData(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : const Color(0xFF1E293B),
          ),
        ),
        drawer: const AppDrawer(),
        body: body,
        bottomNavigationBar: _buildRolePortalBottomNavBar(),
      ),
    );
  }

  Widget _buildSearchField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          hintText: 'Search...',
          hintStyle: TextStyle(color: textColor.withOpacity(0.4)),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
          filled: true,
          fillColor: isDark
              ? const Color(0xFF1E293B).withOpacity(0.5)
              : Colors.white.withOpacity(0.7),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.08),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.blueAccent),
          ),
        ),
      ),
    );
  }

  Widget _buildHubView(
    BuildContext context,
    LedgerService ledger,
    List<Map<String, dynamic>> mines,
    List<Map<String, dynamic>> hardwares,
    List<Map<String, dynamic>> trucks,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        const SizedBox(height: 12),
        Text(
          'GeoTrust',
          style: TextStyle(
            fontSize: 45,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        const Text(
          ' Ledger overview',
          style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 35),

        // Stockpile Infrastructure Card
        PremiumGlassCard(
          borderRadius: 24,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.hub_outlined,
                      color: Colors.blueAccent,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Infrastructure Overview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildHubStatItem(
                      context,
                      'Mines',
                      '${mines.length}',
                      Icons.engineering_outlined,
                    ),
                    _buildHubStatItem(
                      context,
                      'Hardwares',
                      '${hardwares.length}',
                      Icons.storefront_outlined,
                    ),
                    _buildHubStatItem(
                      context,
                      'Trucks',
                      '${trucks.length}',
                      Icons.local_shipping_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Quick Actions
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(
            Icons.engineering_outlined,
            color: Colors.blueAccent,
          ),
          title: Text(
            'Access Mines List',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: isDark ? Colors.white60 : Colors.black38,
          ),
          onTap: () {
            setState(() {
              _currentIndex = 1;
            });
          },
        ),
        ListTile(
          leading: const Icon(
            Icons.storefront_outlined,
            color: Colors.blueAccent,
          ),
          title: Text(
            'Access Hardwares List',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: isDark ? Colors.white60 : Colors.black38,
          ),
          onTap: () {
            setState(() {
              _currentIndex = 2;
            });
          },
        ),
      ],
    );
  }

  Widget _buildHubStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Icon(icon, color: isDark ? Colors.white60 : Colors.black45, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildRolePortalBottomNavBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withOpacity(0.8)
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (idx) {
            setState(() {
              _currentIndex = idx;
              _searchQuery = ''; // Clear search query when switching tabs
            });
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: isDark
              ? const Color.fromARGB(255, 49, 162, 255)
              : const Color(0xFF0052FF),
          unselectedItemColor: isDark
              ? const Color.fromARGB(255, 211, 209, 209)
              : const Color(0xFF64748B),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: 'HUB'),
            BottomNavigationBarItem(
              icon: Icon(Icons.engineering_outlined),
              label: 'MINES',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.storefront_outlined),
              label: 'HARDWARES',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_shipping_outlined),
              label: 'TRUCKS',
            ),
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
            ? 'No mines assigned to your account.'
            : 'No hardware stores assigned to your account.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: locations.length,
      itemBuilder: (context, index) {
        final loc = locations[index];
        final title =
            loc['name'] ??
            (isMine ? 'Yard Manager (Mine)' : 'Hardware Store (Buyer)');
        final inventory = (loc['inventory_cubes'] as num?)?.toDouble() ?? 0.0;
        final isQuotaOver = isMine && inventory <= 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _buildPortalCard(
            context: context,
            ledger: ledger,
            title: title,
            icon: isMine ? Icons.landscape : Icons.store,
            color: isMine
                ? UserRole.mineOwner.color
                : UserRole.hardwareOwner.color,
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

    return HoverBentoCard(
      color: color,
      isDark: isDark,
      onTap: () {
        ledger.setLocationAndPreload(locationId, role);
        Navigator.push(context, MaterialPageRoute(builder: (_) => destination));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: isDark
                        ? color.shade400.withOpacity(0.2)
                        : color.shade100,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? color.shade400.withOpacity(0.4)
                          : color.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: isDark ? color.shade300 : color.shade900,
                    size: 44,
                  ),
                ),
                if (showRedDot)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.red.shade500,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF1B263B)
                              : Colors.white,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: role == UserRole.mineOwner
                    ? '.SF Pro Rounded'
                    : 'Plus Jakarta Sans',
                fontFamilyFallback: role == UserRole.mineOwner
                    ? const ['Quicksand', 'Nunito', 'sans-serif']
                    : null,
                fontWeight: role == UserRole.mineOwner
                    ? FontWeight.w900
                    : FontWeight.w800,
                fontSize: 22,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                letterSpacing: role == UserRole.mineOwner ? 0.0 : -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Tap to manage location',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? Colors.white.withOpacity(0.5)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
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
    final color = UserRole.driver.color;

    return HoverBentoCard(
      color: color,
      isDark: isDark,
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
        padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: isDark
                    ? color.shade400.withOpacity(0.2)
                    : color.shade100,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? color.shade400.withOpacity(0.4)
                      : color.shade200,
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.local_shipping,
                color: isDark ? color.shade300 : color.shade900,
                size: 44,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              numberPlate,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Capacity: ${capacity.toStringAsFixed(1)} m³',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? Colors.white.withOpacity(0.5)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
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

    return AmbientGradientBackground(
      primaryColor: UserRole.driver.color,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Truck: $numberPlate',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
          iconTheme: IconThemeData(
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
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
              return Center(
                child: Text('Error loading permits: ${snapshot.error}'),
              );
            }
            final permits = snapshot.data ?? [];
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PremiumGlassCard(
                    borderRadius: 16,
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
                              color: isDark
                                  ? Colors.blue.shade200
                                  : Colors.blue.shade900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow('Plate Number', numberPlate, isDark),
                          _buildDetailRow(
                            'Chassis Number',
                            chassisNumber,
                            isDark,
                          ),
                          _buildDetailRow(
                            'Capacity',
                            '${capacity.toStringAsFixed(1)} m³',
                            isDark,
                          ),
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

class MineOwnerScreen extends StatefulWidget {
  final String locationName;
  const MineOwnerScreen({super.key, required this.locationName});

  @override
  State<MineOwnerScreen> createState() => _MineOwnerScreenState();
}

class _MineOwnerScreenState extends State<MineOwnerScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerService>();

    final ongoingPermits = ledger.permits
        .where(
          (p) =>
              p.status != PermitStatus.completed &&
              p.status != PermitStatus.cancelled,
        )
        .toList();

    final recentTransactions = ledger.permits
        .where(
          (p) =>
              p.status == PermitStatus.completed ||
              p.status == PermitStatus.cancelled,
        )
        .take(5)
        .toList();

    Widget body;
    if (_currentIndex == 0) {
      body = _buildDashboardTab(
        context,
        ledger,
        ongoingPermits,
        recentTransactions,
      );
    } else if (_currentIndex == 1) {
      body = _buildOngoingTab(context, ledger, ongoingPermits);
    } else {
      body = _buildLocationSwitcherTab(context, ledger);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AmbientGradientBackground(
      primaryColor: const Color(0xFF0F172A),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.menu,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          title: Text(
            widget.locationName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
          iconTheme: IconThemeData(
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        drawer: const AppDrawer(),
        body: body,
        bottomNavigationBar: _buildBottomNavigationBar(context, _currentIndex, (
          idx,
        ) {
          setState(() {
            _currentIndex = idx;
          });
        }),
        floatingActionButton: _currentIndex == 0
            ? Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: FloatingActionButton.extended(
                  onPressed: () => _showDraftPermitBottomSheet(context, ledger),
                  backgroundColor: const Color(0xFF0052FF),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Draft Permit',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildDashboardTab(
    BuildContext context,
    LedgerService ledger,
    List<TransportPermit> ongoingPermits,
    List<TransportPermit> recentTransactions,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final utilPercent = ledger.currentMaxCapacity > 0
        ? (ledger.currentInventoryCubes / ledger.currentMaxCapacity)
        : 0.0;

    return RefreshIndicator(
      onRefresh: ledger.refreshData,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Stockpile Status
          const Text(
            'STOCKPILE STATUS',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Builder(
            builder: (ctx) {
              final isDark = Theme.of(ctx).brightness == Brightness.dark;
              return Text(
                'Current Inventory',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          PremiumGlassCard(
            borderRadius: 24,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: StockpileGauge(
                value: utilPercent,
                cubes: ledger.currentInventoryCubes,
                maxCapacity: ledger.currentMaxCapacity,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Active Permits subtitle & View All
          Builder(
            builder: (bCtx) {
              final isDarkHere = Theme.of(bCtx).brightness == Brightness.dark;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Permits',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDarkHere
                              ? Colors.white
                              : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Validation queue for active transport',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _currentIndex = 1;
                      });
                    },
                    child: const Row(
                      children: [
                        Text(
                          'View All',
                          style: TextStyle(color: Colors.blueAccent),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: Colors.blueAccent,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          // Horizontal permits list
          ongoingPermits.isEmpty
              ? Container(
                  height: 120,
                  alignment: Alignment.center,
                  child: const Text(
                    'No active permits.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                )
              : SizedBox(
                  height: 188,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: ongoingPermits.length,
                    itemBuilder: (context, index) {
                      return _buildHorizontalPermitCard(
                        context,
                        ledger,
                        ongoingPermits[index],
                      );
                    },
                  ),
                ),
          const SizedBox(height: 32),

          // Recent Transactions Section
          Builder(
            builder: (bCtx) {
              final isDarkTx = Theme.of(bCtx).brightness == Brightness.dark;
              return Text(
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDarkTx ? Colors.white : const Color(0xFF1E293B),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.05),
              ),
            ),
            child: recentTransactions.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        'No completed or cancelled transactions.',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                  )
                : Column(
                    children: List.generate(recentTransactions.length, (idx) {
                      final permit = recentTransactions[idx];
                      final isCompleted =
                          permit.status == PermitStatus.completed;

                      // Format time (e.g. 14:20 PM)
                      final timeStr =
                          "${permit.startedDate.hour.toString().padLeft(2, '0')}:${permit.startedDate.minute.toString().padLeft(2, '0')}";

                      return Container(
                        decoration: BoxDecoration(
                          border: idx == recentTransactions.length - 1
                              ? null
                              : Border(
                                  bottom: BorderSide(
                                    color: Colors.white.withOpacity(0.05),
                                    width: 1,
                                  ),
                                ),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? const Color(0xFF065F46).withOpacity(0.2)
                                  : const Color(0xFF7F1D1D).withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isCompleted
                                  ? Icons.check_circle_outline
                                  : Icons.cancel_outlined,
                              color: isCompleted
                                  ? const Color(0xFF34D399)
                                  : const Color(0xFFF87171),
                              size: 20,
                            ),
                          ),
                          title: Builder(
                            builder: (bCtx) {
                              final isDarkItem =
                                  Theme.of(bCtx).brightness == Brightness.dark;
                              return Text(
                                'Permit #${permit.id.length >= 8 ? permit.id.substring(0, 8).toUpperCase() : permit.id.toUpperCase()}',
                                style: TextStyle(
                                  color: isDarkItem
                                      ? Colors.white
                                      : const Color(0xFF1E293B),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              );
                            },
                          ),
                          subtitle: Text(
                            '${isCompleted ? "Completed" : "Cancelled"} • $timeStr',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                            ),
                          ),
                          trailing: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                isCompleted
                                    ? '+${permit.noOfCubes.toStringAsFixed(0)} Cubes'
                                    : '0 Cubes',
                                style: TextStyle(
                                  color: isCompleted
                                      ? const Color(0xFF34D399)
                                      : const Color(0xFFF87171),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                isCompleted
                                    ? 'VERIFIED EXIT'
                                    : 'REJECTED WEIGHT',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
          ),
          const SizedBox(height: 80), // extra padding for FAB
        ],
      ),
    );
  }

  Widget _buildOngoingTab(
    BuildContext context,
    LedgerService ledger,
    List<TransportPermit> ongoingPermits,
  ) {
    if (ongoingPermits.isEmpty) {
      return const EmptyState(
        icon: Icons.local_shipping_outlined,
        message: 'No active or draft permits.',
      );
    }
    return RefreshIndicator(
      onRefresh: ledger.refreshData,
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: ongoingPermits.length,
        itemBuilder: (context, index) {
          final permit = ongoingPermits[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: _buildDetailedManagerCard(context, ledger, permit),
          );
        },
      ),
    );
  }

  Widget _buildDetailedManagerCard(
    BuildContext context,
    LedgerService ledger,
    TransportPermit permit,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF475569);
    return PremiumGlassCard(
      borderRadius: 20,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'ID: ${permit.id.toUpperCase()}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textPrimary,
                    ),
                  ),
                ),
                _buildCustomStatusChip(permit.status),
              ],
            ),
            Divider(
              color: isDark ? Colors.white12 : Colors.black12,
              height: 24,
            ),
            Text(
              'Vehicle Registration: ${permit.truckNumberPlate}',
              style: TextStyle(fontSize: 14, color: textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Load Quantity: ${permit.noOfCubes.toStringAsFixed(1)} Cubes',
              style: TextStyle(fontSize: 14, color: textSecondary),
            ),
            if (permit.permitCode != null &&
                !permit.permitCode!.startsWith('DRAFT-'))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blueAccent.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Driver Access Code: ${permit.permitCode}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                          fontSize: 14,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.copy,
                          size: 18,
                          color: Colors.blueAccent,
                        ),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: permit.permitCode ?? ''),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Access code copied to clipboard!'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
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
                label: const Text('DISPATCH TRUCK'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSwitcherTab(BuildContext context, LedgerService ledger) {
    final otherLocations = ledger.userLocations
        .where((loc) => loc['id'] != ledger.currentLocationId)
        .toList();

    if (otherLocations.isEmpty) {
      return const Center(
        child: Text(
          'No other locations to switch to.',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: otherLocations.length,
      itemBuilder: (context, index) {
        final loc = otherLocations[index];
        final isMine =
            loc['location_type'] == 'MINE' ||
            loc['location_type'] == 'MINE_OWNER';
        final title = loc['name'] ?? (isMine ? 'Mine' : 'Hardware');
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: PremiumGlassCard(
            borderRadius: 16,
            child: ListTile(
              leading: Icon(
                isMine ? Icons.landscape : Icons.store,
                color: isMine
                    ? UserRole.mineOwner.color
                    : UserRole.hardwareOwner.color,
              ),
              title: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                isMine ? 'Mine Location' : 'Hardware Store',
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
              trailing: const Icon(Icons.swap_horiz, color: Colors.blueAccent),
              onTap: () {
                ledger.setLocationAndPreload(
                  loc['id'],
                  isMine ? UserRole.mineOwner : UserRole.hardwareOwner,
                );
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => isMine
                        ? MineOwnerScreen(locationName: title)
                        : HardwareOwnerScreen(locationName: title),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showDraftPermitBottomSheet(BuildContext context, LedgerService ledger) {
    final vehicleCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Draft New Permit',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: vehicleCtrl,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [TruckNumberFormatter()],
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Transport Truck No. (e.g. NW AA - 1234)',
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFF1E293B).withOpacity(0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Number of Cubes',
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFF1E293B).withOpacity(0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Date: ${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate.isBefore(today)
                                ? today
                                : selectedDate,
                            firstDate: today,
                            lastDate: today.add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setModalState(() => selectedDate = picked);
                          }
                        },
                        icon: const Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.blueAccent,
                        ),
                        label: const Text(
                          'Change',
                          style: TextStyle(color: Colors.blueAccent),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0052FF),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () async {
                      if (vehicleCtrl.text.trim().isEmpty ||
                          qtyCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please enter vehicle number and quantity.',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      final qty = double.tryParse(qtyCtrl.text) ?? 0.0;
                      if (qty <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Quantity must be greater than zero.',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      final error = await ledger.issueNewPermit(
                        vehicleCtrl.text.trim(),
                        qty,
                        selectedDate,
                      );
                      if (error != null) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(error),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Draft permit created successfully!',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Create Draft License'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// Global UI Widgets shared by Dashboards

class StockpileGauge extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final double cubes;
  final double maxCapacity;

  const StockpileGauge({
    super.key,
    required this.value,
    required this.cubes,
    required this.maxCapacity,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        SizedBox(
          height: 140,
          width: 240,
          child: CustomPaint(
            painter: _SemiCircleGaugePainter(value, isDark),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatCubes(cubes),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981), // Vibrant green
                      ),
                    ),
                    const Text(
                      'CUBES OF SAND',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'UTILIZED',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${(value * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'MAX CAPACITY',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _formatMaxCapacity(maxCapacity),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  String _formatCubes(double val) {
    return val
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  String _formatMaxCapacity(double val) {
    if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(0)}k';
    }
    return '${val.toStringAsFixed(0)}';
  }
}

class _SemiCircleGaugePainter extends CustomPainter {
  final double value;
  final bool isDark;

  _SemiCircleGaugePainter(this.value, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 10);
    final radius = size.width / 2 - 20;

    final trackPaint = Paint()
      ..color = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final gradientColors = isDark
        ? [const Color(0xFF60A5FA), const Color(0xFF34D399)]
        : [const Color(0xFF2563EB), const Color(0xFF10B981)];

    final progressPaint = Paint()
      ..shader = LinearGradient(
        colors: gradientColors,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi,
      false,
      trackPaint,
    );

    if (value > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        pi,
        pi * value.clamp(0.0, 1.0),
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SemiCircleGaugePainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.isDark != isDark;
  }
}

Widget _buildBottomNavigationBar(
  BuildContext context,
  int currentIndex,
  Function(int) onTap,
) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    decoration: BoxDecoration(
      color: isDark
          ? const Color(0xFF0F172A).withOpacity(0.8)
          : Colors.white.withOpacity(0.9),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.08),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: isDark
            ? const Color.fromARGB(255, 49, 162, 255)
            : const Color(0xFF0052FF),
        unselectedItemColor: isDark
            ? const Color.fromARGB(255, 211, 209, 209)
            : const Color(0xFF64748B),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view),
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping_outlined),
            label: 'Ongoing',
          ),
        ],
      ),
    ),
  );
}

Widget _buildCustomStatusChip(PermitStatus status) {
  String text = 'UNKNOWN';
  Color bg = Colors.grey;
  Color fg = Colors.white;

  if (status == PermitStatus.pending) {
    text = 'AWAITING DISPATCH';
    bg = const Color(0xFF1E293B);
    fg = const Color(0xFF10B981);
  } else if (status == PermitStatus.active) {
    text = 'ACTIVE JOURNEY';
    bg = const Color(0xFF065F46);
    fg = const Color(0xFF34D399);
  } else if (status == PermitStatus.completed) {
    text = 'COMPLETED';
    bg = const Color(0xFF334155);
    fg = const Color(0xFF94A3B8);
  } else if (status == PermitStatus.cancelled) {
    text = 'CANCELLED';
    bg = const Color(0xFF7F1D1D);
    fg = const Color(0xFFF87171);
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: fg.withOpacity(0.3), width: 1),
    ),
    child: Text(
      text,
      style: TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.bold),
    ),
  );
}

Widget _buildHorizontalPermitCard(
  BuildContext context,
  LedgerService ledger,
  TransportPermit permit,
) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
  return Container(
    width: 220,
    margin: const EdgeInsets.only(right: 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: isDark
          ? const Color(0xFF1E293B).withOpacity(0.6)
          : Colors.white.withOpacity(0.75),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.06),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.local_shipping,
                size: 14,
                color: Colors.blueAccent,
              ),
            ),
            Flexible(child: _buildCustomStatusChip(permit.status)),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'TRUCK NUMBER PLATE',
          style: TextStyle(
            fontSize: 9,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          permit.truckNumberPlate,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'QUANTITY',
                  style: TextStyle(
                    fontSize: 9,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${permit.noOfCubes.toStringAsFixed(0)} Cubes',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: Icon(
                Icons.more_vert,
                color: isDark ? Colors.white70 : Colors.black45,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                _showPermitOptions(context, ledger, permit);
              },
            ),
          ],
        ),
      ],
    ),
  );
}

void _showPermitOptions(
  BuildContext context,
  LedgerService ledger,
  TransportPermit permit,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF0F172A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Builder(
                builder: (ctx) {
                  final isDark = Theme.of(ctx).brightness == Brightness.dark;
                  return Text(
                    'Permit ID: ${permit.id.toUpperCase()}',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white60
                          : const Color.fromARGB(137, 186, 185, 185),
                      fontSize: 14,
                    ),
                  );
                },
              ),
            ),
            if (permit.status == PermitStatus.pending)
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Builder(
                  builder: (ctx) {
                    final isDark = Theme.of(ctx).brightness == Brightness.dark;
                    return Text(
                      'Dispatch / Activate Permit',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    );
                  },
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ledger.activatePermitAndGenerateCode(permit.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Permit activated! Code generated: ${permit.permitCode ?? ""}',
                      ),
                    ),
                  );
                },
              ),
            if (permit.permitCode != null &&
                !permit.permitCode!.startsWith('DRAFT-'))
              ListTile(
                leading: const Icon(Icons.vpn_key, color: Colors.blueAccent),
                title: Text(
                  'Access Code: ${permit.permitCode}',
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.copy, color: Colors.blueAccent),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: permit.permitCode ?? ''),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Access code copied to clipboard!'),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      );
    },
  );
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
        final expirationDate = (created ?? DateTime.now()).add(
          const Duration(hours: 24),
        );
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

    return AmbientGradientBackground(
      primaryColor: UserRole.driver.color,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Transporter Dashboard',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : const Color(0xFF1E293B),
            ),
          ),
          foregroundColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : const Color(0xFF1E293B),
          iconTheme: IconThemeData(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : const Color(0xFF1E293B),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (activePermit != null) ...[
                // Circular Timer CountDown Progress
                Center(child: CircularTimerWidget(timeLeft: _timeLeft)),
                const SizedBox(height: 32),

                // Timeline Bento Card
                Expanded(
                  child: PremiumGlassCard(
                    borderRadius: 24,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'JOURNEY TIMELINE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B),
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            JourneyTimeline(
                              origin:
                                  ledger.locationIdToName[activePermit
                                      .mineId] ??
                                  'Origin Mine Yard',
                              destination:
                                  ledger.locationIdToName[activePermit
                                      .hardwareId] ??
                                  'Destination Hardware Hub',
                            ),
                            const SizedBox(height: 24),
                            const Divider(color: Colors.white10),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'CARGO VOLUME',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${activePermit.noOfCubes.toStringAsFixed(1)} Cubes',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white
                                            : const Color(0xFF1E293B),
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'TRUCK REG',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      activePermit.truckNumberPlate,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white
                                            : const Color(0xFF1E293B),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Photo Audit & Unload Button
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0052FF).withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Material(
                      color: Colors.transparent,
                      child: Ink(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF0052FF), Color(0xFF06B6D4)],
                          ),
                        ),
                        child: InkWell(
                          onTap: _isUnloading
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
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Unloaded successfully! Photo & GPS Logged.',
                                          ),
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
                                  if (mounted)
                                    setState(() => _isUnloading = false);
                                },
                          child: Container(
                            alignment: Alignment.center,
                            height: 60,
                            child: _isUnloading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'PHOTO AUDIT & UNLOAD',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (activePermit == null)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_outline,
                          size: 96,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Journey Completed',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'The permit was successfully processed.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 32),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.15),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        ),
                        child: const Text('Return to Home Screen'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Sub-widgets for Driver Journey Dashboard

class CircularTimerWidget extends StatelessWidget {
  final Duration timeLeft;

  const CircularTimerWidget({super.key, required this.timeLeft});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const totalSecs = 24 * 3600;
    final leftSecs = timeLeft.inSeconds.clamp(0, totalSecs);
    final progress = leftSecs / totalSecs;

    final hours = timeLeft.inHours.toString().padLeft(2, '0');
    final minutes = (timeLeft.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (timeLeft.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withOpacity(0.5)
            : const Color(0xFF0052FF).withOpacity(0.05),
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.06),
          width: 2,
        ),
      ),
      child: CustomPaint(
        painter: CircularTimerPainter(progress, isDark),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$hours:$minutes:$seconds',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'EST. TIME LEFT',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E3A8A).withOpacity(0.3)
                      : const Color(0xFF60A5FA).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(progress * 100).toStringAsFixed(0)}% remaining',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFF60A5FA)
                        : const Color(0xFF1D4ED8),
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

class CircularTimerPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  CircularTimerPainter(this.progress, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    final trackPaint = Paint()
      ..color = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;

    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0052FF), Color(0xFF06B6D4)],
      ).createShader(Rect.fromLTRB(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CircularTimerPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}

class JourneyTimeline extends StatelessWidget {
  final String origin;
  final String destination;

  const JourneyTimeline({
    super.key,
    required this.origin,
    required this.destination,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTimelineNode(
          context,
          icon: Icons.store,
          color: const Color(0xFF0052FF),
          title: 'ORIGIN YARD',
          location: origin,
          isLast: false,
        ),
        _buildTimelineConnector(context, Colors.blueAccent),
        _buildTimelineNode(
          context,
          icon: Icons.navigation_outlined,
          color: const Color(0xFFF59E0B),
          title: 'IN TRANSIT',
          location: 'Current Position (On Route)',
          isLast: false,
          isGlowing: true,
        ),
        _buildTimelineConnector(context, Colors.grey.shade700),
        _buildTimelineNode(
          context,
          icon: Icons.flag_outlined,
          color: const Color(0xFF10B981),
          title: 'DESTINATION STORE',
          location: destination,
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildTimelineNode(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String location,
    required bool isLast,
    bool isGlowing = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isGlowing
                    ? color.withOpacity(0.2)
                    : const Color(0xFF1E293B),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
                boxShadow: isGlowing
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Icon(icon, size: 16, color: color),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                location,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineConnector(BuildContext context, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 17),
      height: 30,
      width: 2,
      decoration: BoxDecoration(color: color.withOpacity(0.4)),
    );
  }
}

class HardwareOwnerScreen extends StatefulWidget {
  final String locationName;
  const HardwareOwnerScreen({super.key, required this.locationName});

  @override
  State<HardwareOwnerScreen> createState() => _HardwareOwnerScreenState();
}

class _HardwareOwnerScreenState extends State<HardwareOwnerScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerService>();

    final ongoingPermits = ledger.permits
        .where(
          (p) =>
              p.status != PermitStatus.completed &&
              p.status != PermitStatus.cancelled,
        )
        .toList();

    final recentTransactions = ledger.permits
        .where(
          (p) =>
              p.status == PermitStatus.completed ||
              p.status == PermitStatus.cancelled,
        )
        .take(5)
        .toList();

    Widget body;
    if (_currentIndex == 0) {
      body = _buildDashboardTab(
        context,
        ledger,
        ongoingPermits,
        recentTransactions,
      );
    } else if (_currentIndex == 1) {
      body = _buildOngoingTab(context, ledger, ongoingPermits);
    } else {
      body = _buildLocationSwitcherTab(context, ledger);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AmbientGradientBackground(
      primaryColor: const Color(0xFF0F172A),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.menu,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          title: Text(
            widget.locationName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
          iconTheme: IconThemeData(
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        drawer: const AppDrawer(),
        body: body,
        bottomNavigationBar: _buildBottomNavigationBar(context, _currentIndex, (
          idx,
        ) {
          setState(() {
            _currentIndex = idx;
          });
        }),
        floatingActionButton: _currentIndex == 0
            ? Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: FloatingActionButton.extended(
                  onPressed: () =>
                      _showAssignMiniPermitBottomSheet(context, ledger),
                  backgroundColor: const Color(0xFF0052FF),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Assign Permit',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildDashboardTab(
    BuildContext context,
    LedgerService ledger,
    List<TransportPermit> ongoingPermits,
    List<TransportPermit> recentTransactions,
  ) {
    final maxCap = ledger.currentMaxCapacity > 0
        ? ledger.currentMaxCapacity
        : 250.0;
    final utilPercent = ledger.currentInventoryCubes / maxCap;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: ledger.refreshData,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Stockpile Status
          const Text(
            'STORE STOCKPILE STATUS',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Current Inventory',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),

          PremiumGlassCard(
            borderRadius: 24,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: StockpileGauge(
                value: utilPercent,
                cubes: ledger.currentInventoryCubes,
                maxCapacity: maxCap,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Active Permits subtitle & View All
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Mini-Permits',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Validation queue for ongoing deliveries',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentIndex = 1; // Switch to detailed list tab
                  });
                },
                child: const Row(
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(color: Colors.blueAccent),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: Colors.blueAccent,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Horizontal permits list
          ongoingPermits.isEmpty
              ? Container(
                  height: 120,
                  alignment: Alignment.center,
                  child: const Text(
                    'No active mini-permits.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                )
              : SizedBox(
                  height: 188,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: ongoingPermits.length,
                    itemBuilder: (context, index) {
                      return _buildHorizontalPermitCard(
                        context,
                        ledger,
                        ongoingPermits[index],
                      );
                    },
                  ),
                ),
          const SizedBox(height: 32),

          // Recent Transactions Section
          Text(
            'Recent Transactions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.15),
              ),
            ),
            child: recentTransactions.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        'No completed or cancelled transactions.',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                  )
                : Column(
                    children: List.generate(recentTransactions.length, (idx) {
                      final permit = recentTransactions[idx];
                      final isCompleted =
                          permit.status == PermitStatus.completed;

                      // Format time (e.g. 14:20 PM)
                      final timeStr =
                          "${permit.startedDate.hour.toString().padLeft(2, '0')}:${permit.startedDate.minute.toString().padLeft(2, '0')}";

                      return Container(
                        decoration: BoxDecoration(
                          border: idx == recentTransactions.length - 1
                              ? null
                              : Border(
                                  bottom: BorderSide(
                                    color: Colors.white.withOpacity(0.05),
                                    width: 1,
                                  ),
                                ),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? const Color(0xFF065F46).withOpacity(0.2)
                                  : const Color(0xFF7F1D1D).withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isCompleted
                                  ? Icons.check_circle_outline
                                  : Icons.cancel_outlined,
                              color: isCompleted
                                  ? const Color(0xFF34D399)
                                  : const Color(0xFFF87171),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            'Permit #${permit.id.length >= 8 ? permit.id.substring(0, 8).toUpperCase() : permit.id.toUpperCase()}',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '${isCompleted ? "Completed" : "Cancelled"} • $timeStr',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                            ),
                          ),
                          trailing: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                isCompleted
                                    ? '+${permit.noOfCubes.toStringAsFixed(0)} Cubes'
                                    : '0 Cubes',
                                style: TextStyle(
                                  color: isCompleted
                                      ? const Color(0xFF34D399)
                                      : const Color(0xFFF87171),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                isCompleted
                                    ? 'VERIFIED EXIT'
                                    : 'REJECTED WEIGHT',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
          ),
          const SizedBox(height: 80), // extra padding for FAB
        ],
      ),
    );
  }

  Widget _buildOngoingTab(
    BuildContext context,
    LedgerService ledger,
    List<TransportPermit> ongoingPermits,
  ) {
    if (ongoingPermits.isEmpty) {
      return const EmptyState(
        icon: Icons.local_shipping_outlined,
        message: 'No active mini-permits.',
      );
    }
    return RefreshIndicator(
      onRefresh: ledger.refreshData,
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: ongoingPermits.length,
        itemBuilder: (context, index) {
          final permit = ongoingPermits[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: _buildDetailedManagerCard(context, ledger, permit),
          );
        },
      ),
    );
  }

  Widget _buildDetailedManagerCard(
    BuildContext context,
    LedgerService ledger,
    TransportPermit permit,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF475569);
    return PremiumGlassCard(
      borderRadius: 20,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'ID: ${permit.id.toUpperCase()}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textPrimary,
                    ),
                  ),
                ),
                _buildCustomStatusChip(permit.status),
              ],
            ),
            Divider(
              color: isDark ? Colors.white12 : Colors.black12,
              height: 24,
            ),
            Text(
              'Vehicle Registration: ${permit.truckNumberPlate}',
              style: TextStyle(fontSize: 14, color: textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Load Quantity: ${permit.noOfCubes.toStringAsFixed(1)} Cubes',
              style: TextStyle(fontSize: 14, color: textSecondary),
            ),
            if (permit.permitCode != null &&
                !permit.permitCode!.startsWith('DRAFT-'))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blueAccent.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Driver Access Code: ${permit.permitCode}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                          fontSize: 14,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.copy,
                          size: 18,
                          color: Colors.blueAccent,
                        ),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: permit.permitCode ?? ''),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Access code copied to clipboard!'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
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
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSwitcherTab(BuildContext context, LedgerService ledger) {
    final otherLocations = ledger.userLocations
        .where((loc) => loc['id'] != ledger.currentLocationId)
        .toList();

    if (otherLocations.isEmpty) {
      return const Center(
        child: Text(
          'No other locations to switch to.',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: otherLocations.length,
      itemBuilder: (context, index) {
        final loc = otherLocations[index];
        final isMine =
            loc['location_type'] == 'MINE' ||
            loc['location_type'] == 'MINE_OWNER';
        final title = loc['name'] ?? (isMine ? 'Mine' : 'Hardware');
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: PremiumGlassCard(
            borderRadius: 16,
            child: ListTile(
              leading: Icon(
                isMine ? Icons.landscape : Icons.store,
                color: isMine
                    ? UserRole.mineOwner.color
                    : UserRole.hardwareOwner.color,
              ),
              title: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                isMine ? 'Mine Location' : 'Hardware Store',
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
              trailing: const Icon(Icons.swap_horiz, color: Colors.blueAccent),
              onTap: () {
                ledger.setLocationAndPreload(
                  loc['id'],
                  isMine ? UserRole.mineOwner : UserRole.hardwareOwner,
                );
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => isMine
                        ? MineOwnerScreen(locationName: title)
                        : HardwareOwnerScreen(locationName: title),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showAssignMiniPermitBottomSheet(
    BuildContext context,
    LedgerService ledger,
  ) {
    final vehicleCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Assign Mini-Permit to Home (< 5 Cubes)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: vehicleCtrl,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [TruckNumberFormatter()],
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Truck Registration (e.g. NW AA - 1234)',
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFF1E293B).withOpacity(0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Quantity (< 5 Cubes)',
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFF1E293B).withOpacity(0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0052FF),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () async {
                      if (vehicleCtrl.text.trim().isEmpty ||
                          qtyCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill all fields.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      final qty = double.tryParse(qtyCtrl.text) ?? 0.0;
                      if (qty <= 0 || qty >= 5.0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Quantity must be greater than zero and less than 5 Cubes.',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      final error = await ledger.issueMiniPermit(
                        vehicleCtrl.text.trim(),
                        qty,
                        DateTime.now(),
                      );
                      if (error != null) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(error),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Mini permit assigned successfully!',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Issue Mini Permit'),
                  ),
                ],
              ),
            );
          },
        );
      },
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

class HoverBentoCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final MaterialColor color;
  final bool isDark;

  const HoverBentoCard({
    super.key,
    required this.child,
    required this.onTap,
    required this.color,
    required this.isDark,
  });

  @override
  State<HoverBentoCard> createState() => _HoverBentoCardState();
}

class _HoverBentoCardState extends State<HoverBentoCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = _isPressed ? 0.97 : 1.0;

    final decoration = widget.isDark
        ? BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1B263B).withOpacity(0.95),
                const Color(0xFF121C2C).withOpacity(0.50),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF2E3F5D), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0E1726).withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          )
        : BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFECF0F6),
                const Color(0xFFE2E8F1).withOpacity(0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFD4DCE8), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.blueGrey.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          );

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(scale),
        transformAlignment: Alignment.center,
        decoration: decoration,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: widget.child,
        ),
      ),
    );
  }
}

class AmbientGradientBackground extends StatefulWidget {
  final Widget child;
  final Color primaryColor;
  final bool animate;

  const AmbientGradientBackground({
    super.key,
    required this.child,
    required this.primaryColor,
    this.animate = false,
  });

  @override
  State<AmbientGradientBackground> createState() =>
      _AmbientGradientBackgroundState();
}

class _AmbientGradientBackgroundState extends State<AmbientGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );
    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getVibrantColor(Color baseColor, bool isDark) {
    // Return vibrant royal blue / sapphire blue -> strictly no green
    if (baseColor.value == 0xFF0F172A || baseColor == Colors.blueGrey) {
      return isDark ? const Color(0xFF1D4ED8) : const Color(0xFFDBEAFE);
    }
    // MineOwner indigo -> Indigo Blue
    if (baseColor == Colors.indigo) {
      return isDark ? const Color(0xFF2563EB) : const Color(0xFFC7D2FE);
    }
    // HardwareOwner teal -> Electric Sky Blue (strictly no green)
    if (baseColor == Colors.teal) {
      return isDark ? const Color(0xFF3B82F6) : const Color(0xFF93C5FD);
    }
    return baseColor;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Base background gradient with deep blue tints
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF030712), // Deepest dark slate-blue
                      const Color(0xFF070F26), // Deep Navy Blue
                      const Color(0xFF0C1635), // Deep Sapphire Blue tint
                    ]
                  : [
                      const Color(0xFFEFF6FF), // Soft azure blue tint
                      const Color(0xFFFFFFFF), // Pure white
                      const Color(0xFFDBEAFE), // Soft sky blue tint
                    ],
            ),
          ),
        ),
        // Animated gradient blobs and glowing matching line waves
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;

            // Distribute coordinates wide across the screen corners to cover full screen
            final blob1X = size.width * (0.05 + 0.10 * sin(t * 2 * pi));
            final blob1Y = size.height * (0.05 + 0.10 * cos(t * 2 * pi));

            final blob2X = size.width * (0.95 - 0.10 * cos(t * 2 * pi));
            final blob2Y = size.height * (0.10 + 0.10 * sin(t * 2 * pi));

            final blob3X = size.width * (0.05 + 0.10 * cos(t * 2 * pi + pi));
            final blob3Y = size.height * (0.90 + 0.10 * sin(t * 2 * pi));

            final blob4X =
                size.width * (0.95 - 0.10 * sin(t * 2 * pi + pi / 2));
            final blob4Y = size.height * (0.90 - 0.10 * cos(t * 2 * pi));

            final primaryVibrant = _getVibrantColor(
              widget.primaryColor,
              isDark,
            );

            return Stack(
              children: [
                // Blob 1: Role Primary Color (Vibrant blue, wide spread)
                Positioned(
                  left: blob1X - 300,
                  top: blob1Y - 300,
                  child: Container(
                    width: 600,
                    height: 600,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          primaryVibrant.withOpacity(isDark ? 0.35 : 0.28),
                          primaryVibrant.withOpacity(isDark ? 0.15 : 0.10),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
                ),
                // Blob 2: Vibrant Electric Indigo
                Positioned(
                  left: blob2X - 350,
                  top: blob2Y - 350,
                  child: Container(
                    width: 700,
                    height: 700,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(
                            0xFF4F46E5,
                          ).withOpacity(isDark ? 0.32 : 0.24),
                          const Color(
                            0xFF4F46E5,
                          ).withOpacity(isDark ? 0.12 : 0.08),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
                ),
                // Blob 3: Vibrant Royal Blue
                Positioned(
                  left: blob3X - 275,
                  top: blob3Y - 275,
                  child: Container(
                    width: 550,
                    height: 550,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(
                            0xFF2563EB,
                          ).withOpacity(isDark ? 0.30 : 0.22),
                          const Color(
                            0xFF2563EB,
                          ).withOpacity(isDark ? 0.10 : 0.06),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
                ),
                // Blob 4: Vibrant Electric Cobalt
                Positioned(
                  left: blob4X - 300,
                  top: blob4Y - 300,
                  child: Container(
                    width: 600,
                    height: 600,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(
                            0xFF3B82F6,
                          ).withOpacity(isDark ? 0.28 : 0.20),
                          const Color(0xFF3B82F6).withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Dynamic waving matching light beam lines (rendered under blur)
                Positioned.fill(
                  child: CustomPaint(
                    painter: GlowingLightBeamsPainter(
                      animationValue: t,
                      isDark: isDark,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        // Apple-style heavy blur backdrop (increased to 75.0 for a seamless fluid blend)
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 75.0, sigmaY: 75.0),
            child: Container(color: Colors.transparent),
          ),
        ),
        // Screen Content (directly over the blurred background, no foreground sharp lines)
        Positioned.fill(child: widget.child),
      ],
    );
  }
}

class GlowingLightBeamsPainter extends CustomPainter {
  final double animationValue;
  final bool isDark;

  GlowingLightBeamsPainter({
    required this.animationValue,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = animationValue;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Dynamic wave 1: Vibrant Cobalt Blue (Wide Stroke for soft diffusion)
    final paint1 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 36.0
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF3B82F6).withOpacity(0.25),
          const Color(0xFF2563EB).withOpacity(0.12),
          const Color(0xFF1D4ED8).withOpacity(0.0),
        ],
      ).createShader(rect);

    final path1 = Path();
    path1.moveTo(0, size.height * 0.25 + sin(t * 2 * pi) * 60);
    path1.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.05 + cos(t * 2 * pi) * 80,
      size.width,
      size.height * 0.35 + sin(t * 2 * pi) * 60,
    );
    canvas.drawPath(path1, paint1);

    // Dynamic wave 2: Electric Indigo-Blue
    final paint2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 48.0
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF1D4ED8).withOpacity(0.0),
          const Color(0xFF4F46E5).withOpacity(0.20),
          const Color(0xFF2563EB).withOpacity(0.20),
        ],
      ).createShader(rect);

    final path2 = Path();
    path2.moveTo(0, size.height * 0.75 + cos(t * 2 * pi) * 70);
    path2.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.90 + sin(t * 2 * pi) * 90,
      size.width,
      size.height * 0.60 + cos(t * 2 * pi) * 70,
    );
    canvas.drawPath(path2, paint2);

    // Dynamic wave 3: Cross-wave from bottom-left to top-right
    final paint3 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 30.0
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF2563EB).withOpacity(0.0),
          const Color(0xFF3B82F6).withOpacity(0.18),
          const Color(0xFF1D4ED8).withOpacity(0.0),
        ],
      ).createShader(rect);

    final path3 = Path();
    path3.moveTo(0, size.height * 0.90 - sin(t * 2 * pi) * 50);
    path3.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.50 + cos(t * 2 * pi) * 60,
      size.width,
      size.height * 0.10 - sin(t * 2 * pi) * 50,
    );
    canvas.drawPath(path3, paint3);
  }

  @override
  bool shouldRepaint(covariant GlowingLightBeamsPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
