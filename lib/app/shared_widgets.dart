part of '../app.dart';

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
          Container(
            padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 24, 16, 24),
            color: Colors.teal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: ledger.profilePicBase64 != null ? MemoryImage(base64Decode(ledger.profilePicBase64!)) : null,
                  child: ledger.profilePicBase64 == null ? const Icon(Icons.account_circle, size: 80, color: Colors.white) : null,
                ),
                const SizedBox(height: 8),
                Text(ledger.currentUsername, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white)),
              ],
            ),
          ),
          ListTile(leading: const Icon(Icons.history), title: const Text('Transaction History'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()))),
          ListTile(leading: const Icon(Icons.password), title: const Text('Change Password'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()))),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () {
              ledger.logout();
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
            },
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
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<LedgerService>().fetchTransactionHistory());
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
              bottom: const TabBar(tabs: [Tab(text: 'From Mines'), Tab(text: 'From Hardwares')]),
            ),
            body: TabBarView(
              children: [
                ListView.builder(itemCount: ledger.mineTransactionHistory.length, itemBuilder: (c, i) => PermitCard(permit: ledger.mineTransactionHistory[i])),
                ListView.builder(itemCount: ledger.hardwareTransactionHistory.length, itemBuilder: (c, i) => PermitCard(permit: ledger.hardwareTransactionHistory[i])),
              ],
            ),
          ),
        );
      },
    );
  }
}

class PermitCard extends StatelessWidget {
  final TransportPermit permit;
  final bool isLarge;
  final String? locationName;
  const PermitCard({super.key, required this.permit, this.isLarge = false, this.locationName});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PERMIT ID: ${permit.id.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Vehicle: ${permit.truckNumberPlate} | ${permit.noOfCubes} Cubes'),
            Text('Expires: ${permit.expiryDate.toIso8601String().substring(0, 10)}', style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _currentPasswordCtrl, decoration: const InputDecoration(labelText: 'Current Password', filled: true)),
            const SizedBox(height: 16),
            TextField(controller: _newPasswordCtrl, decoration: const InputDecoration(labelText: 'New Password', filled: true)),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isUpdating ? null : () async {
                setState(() => _isUpdating = true);
                try {
                  // UPDATED to user_accounts table and password_hashed column
                  final response = await Supabase.instance.client.from('user_accounts').select('password_hashed').eq('user_id', ledger.currentUser!.id).maybeSingle();
                  if (response == null || response['password_hashed'] != _currentPasswordCtrl.text) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Current password incorrect.'), backgroundColor: Colors.red));
                    setState(() => _isUpdating = false);
                    return;
                  }
                  await Supabase.instance.client.from('user_accounts').update({'password_hashed': _newPasswordCtrl.text}).eq('user_id', ledger.currentUser!.id);
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  setState(() => _isUpdating = false);
                }
              },
              child: const Text('UPDATE PASSWORD'),
            ),
          ],
        ),
      ),
    );
  }
}