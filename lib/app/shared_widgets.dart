part of '../app.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});
  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerService>();
    final themeProvider = context.watch<ThemeProvider>();
    final role = ledger.currentUserRole;
    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Profile Section
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Profile Photo'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.photo_library),
                            title: const Text('Change Photo'),
                            onTap: () async {
                              Navigator.pop(ctx);
                              final picker = ImagePicker();
                              final photo = await picker.pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 30,
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
                              'Remove Photo',
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
                child: Row(
                  children: [
                    ledger.profilePicBase64 != null
                        ? CircleAvatar(
                            radius: 28,
                            backgroundImage: MemoryImage(
                              base64Decode(ledger.profilePicBase64!),
                            ),
                          )
                        : Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.05),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.person_outline,
                              size: 28,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ledger.currentUsername.isEmpty
                                ? 'Guest'
                                : ledger.currentUsername,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (role != null)
                            Text(
                              role.displayName,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // MAIN CONSOLE section
              const Text(
                'MAIN CONSOLE',
                style: TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),

              // Dashboard tile (Highlighted/Selected)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0052FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.grid_view, color: Colors.white),
                  title: const Text(
                    'Dashboard',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(height: 24),

              // PREFERENCES section
              const Text(
                'PREFERENCES',
                style: TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),

              // Location Switcher
              ListTile(
                leading: const Icon(
                  Icons.map_outlined,
                  color: Color(0xFF94A3B8),
                ),
                title: const Text(
                  'Location-switcher',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const RolePortalScreen()),
                    (r) => false,
                  );
                },
              ),

              // Transaction History (only if role is owner)
              if (ledger.currentUserRole == UserRole.mineOwner ||
                  ledger.currentUserRole == UserRole.hardwareOwner)
                ListTile(
                  leading: const Icon(Icons.history, color: Color(0xFF94A3B8)),
                  title: const Text(
                    'Transaction History',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                    );
                  },
                ),

              // Dark Mode Switch
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: const Text(
                  'Dark Mode',
                  style: TextStyle(color: Colors.white),
                ),
                secondary: const Icon(
                  Icons.dark_mode_outlined,
                  color: Color(0xFF94A3B8),
                ),
                value: themeProvider.themeMode == ThemeMode.dark,
                onChanged: (val) => themeProvider.toggleTheme(val),
                activeColor: role?.color ?? Colors.teal,
              ),
              const SizedBox(height: 24),

              // SECURITY & SUPPORT section
              const Text(
                'SECURITY & SUPPORT',
                style: TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),

              // Change Password
              ListTile(
                leading: const Icon(
                  Icons.lock_outline,
                  color: Color(0xFF94A3B8),
                ),
                title: const Text(
                  'Change Password',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChangePasswordScreen(),
                    ),
                  );
                },
              ),

              // Support
              ListTile(
                leading: const Icon(
                  Icons.headset_mic_outlined,
                  color: Color(0xFF94A3B8),
                ),
                title: const Text(
                  'Support',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showContactDialog(context);
                },
              ),

              // Logout
              ListTile(
                leading: const Icon(
                  Icons.logout_outlined,
                  color: Color(0xFFF87171),
                ),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    color: Color(0xFFF87171),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  ledger.logout();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (r) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contact Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: support@geotrust.com'),
            SizedBox(height: 8),
            Text('Phone: +94 77 123 4567'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CLOSE'),
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
            Text('About GeoTrust'),
          ],
        ),
        content: const Text(
          'GeoTrust Transport is a modern double-handshake logistics system designed to facilitate material transport using GPS technologies.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
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
              title: const Text('Transaction History'),
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'From Mines', icon: Icon(Icons.landscape)),
                  Tab(text: 'From Hardwares', icon: Icon(Icons.store)),
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
                    'No completed transactions from mines.',
                  ),
                  _buildHistoryList(
                    ledger,
                    ledger.hardwareTransactionHistory,
                    'No completed transactions from hardware stores.',
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
            ledger.locationIdToName[permit.mineId ?? permit.hardwareId] ??
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
    return PremiumGlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      borderSide: BorderSide(color: _getColor(permit.status), width: 2),
      borderRadius: 16,
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
                    'PERMIT ID: ${permit.id.length >= 8 ? permit.id.substring(0, 8).toUpperCase() : permit.id.toUpperCase()}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isLarge ? 24 : 18,
                    ),
                  ),
                ),
                _buildPermitStatusChip(permit.status, isLarge: isLarge),
              ],
            ),
            if (isLarge) const SizedBox(height: 24) else const Divider(),
            if (locationName != null) ...[
              Text(
                'From: $locationName',
                style: TextStyle(
                  fontSize: isLarge ? 18 : 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              'Vehicle: ${permit.truckNumberPlate} | ${permit.noOfCubes} Cubes',
              style: TextStyle(fontSize: isLarge ? 22 : 14),
            ),
            if (isLarge) const SizedBox(height: 24) else const Divider(),
            Text(
              'Expires: ${permit.expiryDate.year}-${permit.expiryDate.month.toString().padLeft(2, '0')}-${permit.expiryDate.day.toString().padLeft(2, '0')} ${permit.expiryDate.hour.toString().padLeft(2, '0')}:${permit.expiryDate.minute.toString().padLeft(2, '0')}',
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

Widget _buildPermitStatusChip(PermitStatus status, {bool isLarge = false}) {
  String text = '';
  Color color = Colors.grey;
  if (status == PermitStatus.pending) {
    text = 'DRAFT';
    color = Colors.amber;
  } else if (status == PermitStatus.active) {
    text = 'ACTIVE';
    color = Colors.green;
  } else if (status == PermitStatus.completed) {
    text = 'COMPLETED';
    color = Colors.grey;
  } else if (status == PermitStatus.cancelled) {
    text = 'CANCELLED';
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
      appBar: AppBar(title: const Text('Change Password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _currentPasswordCtrl,
              obscureText: _obscureCurrent,
              decoration: InputDecoration(
                labelText: 'Current Password',
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
                labelText: 'New Password',
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
                labelText: 'Confirm New Password',
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
                            content: Text('Please fill all fields.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      if (_newPasswordCtrl.text != _confirmPasswordCtrl.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('New passwords do not match.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      if (_newPasswordCtrl.text.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Password must be at least 6 characters.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setState(() => _isUpdating = true);
                      try {
                        final response = await Supabase.instance.client
                            .from('user_accounts')
                            .select('password_hashed')
                            .eq('user_id', ledger.currentUser!.id)
                            .maybeSingle();
                        if (response == null ||
                            response['password_hashed'] !=
                                _currentPasswordCtrl.text) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Current password is incorrect.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                          setState(() => _isUpdating = false);
                          return;
                        }
                        await Supabase.instance.client
                            .from('user_accounts')
                            .update({'password_hashed': _newPasswordCtrl.text})
                            .eq('user_id', ledger.currentUser!.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password updated successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
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
                      child: Text('UPDATE PASSWORD'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class PremiumGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final BorderSide? borderSide;

  const PremiumGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20.0,
    this.borderSide,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(borderRadius),
        border: borderSide != null
            ? Border.fromBorderSide(borderSide!)
            : Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.06),
                width: 1,
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
