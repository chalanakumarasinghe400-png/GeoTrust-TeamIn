part of '../app.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _driverCodeController = TextEditingController();

  // Pin code controllers and focus nodes
  final List<TextEditingController> _pinControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _pinFocusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _obscurePassword = true;
  int _selectedTab = 0; // 0: Management, 1: Drivers
  String? _emailError;
  String? _passwordError;
  String? _pinError;

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _driverCodeController.dispose();
    for (var controller in _pinControllers) {
      controller.dispose();
    }
    for (var node in _pinFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _checkAutoLogin() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final savedUserId = prefs.getString('loggedInUserId');
    final savedPermitStr = prefs.getString('savedDriverPermit');

    final ledger = context.read<LedgerService>();

    if (savedUserId != null) {
      final success = await ledger.loadUserProfile(savedUserId);
      if (success && mounted) {
        ledger.subscribeToPermitChanges();
        if (ledger.currentUserRole == UserRole.mineOwner ||
            ledger.currentUserRole == UserRole.hardwareOwner) {
          ledger.subscribeToInventory();
        }
        ledger.syncOfflineUnloads();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RolePortalScreen()),
        );
        return;
      }
    } else if (savedPermitStr != null) {
      try {
        ledger.currentDriverPermit = TransportPermit.fromJson(
          jsonDecode(savedPermitStr),
        );
        ledger.currentUserRole = UserRole.driver;
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DriverScreen()),
          );
          return;
        }
      } catch (e) {
        print('Failed to load saved permit: $e');
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Widget _buildTabItem(int index, String label, bool isDark) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        width: 130,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF334155) : const Color(0xFF0052FF))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white60 : const Color(0xFF64748B)),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AmbientGradientBackground(
      primaryColor: const Color(0xFF0F172A),
      animate: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Top Globe Icon Container
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (isDark ? const Color(0xFF1E293B) : Colors.white)
                            .withOpacity(0.4),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (isDark ? Colors.white : Colors.black)
                              .withOpacity(0.05),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.language,
                        size: 32,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // App Title
                    Text(
                      'GeoTrust Transport',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Custom Segmented Control Tab Selector
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: (isDark ? const Color(0xFF1E293B) : Colors.white)
                            .withOpacity(0.5),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: (isDark ? Colors.white : Colors.black)
                              .withOpacity(0.05),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildTabItem(0, 'Management', isDark),
                          _buildTabItem(1, 'Drivers', isDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Card Container
                    Container(
                      padding: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A).withOpacity(0.85)
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
                            color: isDark
                                ? Colors.black.withOpacity(0.3)
                                : Colors.blueGrey.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: _selectedTab == 0
                          ? _buildManagementForm(context, ledger, isDark)
                          : _buildDriversForm(context, ledger, isDark),
                    ),
                    const SizedBox(height: 48),

                    // Glow-enhanced Sign-in Button
                    if (_isLoading)
                      const SizedBox(
                        height: 56,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Colors.blueAccent,
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.35),
                              blurRadius: 30,
                              spreadRadius: 2,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0052FF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            if (_selectedTab == 0) {
                              // Management Login
                              setState(() {
                                _emailError = null;
                                _passwordError = null;
                              });

                              bool hasError = false;
                              if (_emailController.text.trim().isEmpty) {
                                setState(() {
                                  _emailError = 'Please enter your email.';
                                });
                                hasError = true;
                              }
                              if (_passwordController.text.trim().isEmpty) {
                                setState(() {
                                  _passwordError = 'Please enter your password.';
                                });
                                hasError = true;
                              }

                              if (hasError) return;

                              setState(() => _isLoading = true);
                              final success = await ledger.loginWithCredentials(
                                _emailController.text.trim(),
                                _passwordController.text.trim(),
                              );
                              if (mounted) setState(() => _isLoading = false);
                              if (success && mounted) {
                                ledger.subscribeToPermitChanges();
                                if (ledger.currentUserRole ==
                                        UserRole.mineOwner ||
                                    ledger.currentUserRole ==
                                        UserRole.hardwareOwner) {
                                  ledger.subscribeToInventory();
                                }
                                ledger.syncOfflineUnloads();
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RolePortalScreen(),
                                  ),
                                );
                              } else if (mounted) {
                                setState(() {
                                  _emailError = 'Invalid Email or Password.';
                                  _passwordError = 'Invalid Email or Password.';
                                });
                              }
                            } else {
                              // Drivers Login
                              setState(() {
                                _pinError = null;
                              });

                              String pin = _pinControllers
                                  .map((c) => c.text)
                                  .join();
                              _driverCodeController.text = pin;
                              if (pin.length < 6) {
                                setState(() {
                                  _pinError = 'Please enter 6-Digit Permit Code.';
                                });
                                return;
                              }
                              setState(() => _isLoading = true);
                              try {
                                await ledger.driverLoginWithCode(pin);
                                if (mounted) setState(() => _isLoading = false);
                                if (mounted) {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const DriverScreen(),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) setState(() => _isLoading = false);
                                if (mounted) {
                                  setState(() {
                                    _pinError = e.toString().replaceAll(
                                      'Exception: ',
                                      '',
                                    );
                                  });
                                }
                              }
                            }
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Sign In to Dashboard',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 24),
                              Text(
                                '——→',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildManagementForm(
    BuildContext context,
    LedgerService ledger,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.security,
                size: 20,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Management',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const Text(
                  'Enterprise portal login',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),

        // EMAIL label
        const Text(
          'EMAIL',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
          decoration: InputDecoration(
            hintText: 'name@geotrust.com',
            hintStyle: TextStyle(
              color: isDark ? Colors.white.withOpacity(0.3) : Colors.black38,
            ),
            filled: true,
            fillColor: isDark
                ? const Color(0xFF1E293B).withOpacity(0.5)
                : Colors.grey.shade100,
            prefixIcon: const Icon(
              Icons.mail_outline,
              color: Color(0xFF64748B),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
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
            errorText: _emailError,
            errorStyle: const TextStyle(color: Colors.redAccent),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // PASSWORD label
        const Text(
          'PASSWORD',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
          decoration: InputDecoration(
            hintText: '••••••••••••',
            hintStyle: TextStyle(
              color: isDark ? Colors.white.withOpacity(0.3) : Colors.black38,
            ),
            filled: true,
            fillColor: isDark
                ? const Color(0xFF1E293B).withOpacity(0.5)
                : Colors.grey.shade100,
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: Color(0xFF64748B),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: const Color(0xFF64748B),
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
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
            errorText: _passwordError,
            errorStyle: const TextStyle(color: Colors.redAccent),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Forgot password link
        InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Please contact administrator to reset password.',
                ),
              ),
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Forgot password?',
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.north_east, size: 14, color: Colors.blueAccent),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDriversForm(
    BuildContext context,
    LedgerService ledger,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF065F46).withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.local_shipping,
                size: 20,
                color: Color(0xFF34D399),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Drivers',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF1E293B),
                  ),
                ),
                const Text(
                  'Direct terminal access',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'ENTER 6-DIGIT FLEET PIN',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 16),
        PinInputWidget(
          controllers: _pinControllers,
          focusNodes: _pinFocusNodes,
          hasError: _pinError != null,
        ),
        if (_pinError != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Text(
              _pinError!,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          'Terminal pin is provided by dispatch.',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 24),

        // Request new pin link
        InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Contact your dispatcher to request a new pin.'),
              ),
            );
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Request new pin',
                style: TextStyle(
                  color: Color(0xFF34D399),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.help_outline, size: 14, color: Color(0xFF34D399)),
            ],
          ),
        ),
      ],
    );
  }
}

class PinInputWidget extends StatefulWidget {
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final bool hasError;

  const PinInputWidget({
    super.key,
    required this.controllers,
    required this.focusNodes,
    this.hasError = false,
  });

  @override
  State<PinInputWidget> createState() => _PinInputWidgetState();
}

class _PinInputWidgetState extends State<PinInputWidget> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 40,
          height: 45,
          child: TextField(
            controller: widget.controllers[index],
            focusNode: widget.focusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            maxLength: 1,
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: isDark
                  ? const Color(0xFF1E293B).withOpacity(0.5)
                  : Colors.grey.shade100,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: widget.hasError
                      ? Colors.redAccent
                      : (isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.08)),
                  width: widget.hasError ? 1.5 : 1.0,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: widget.hasError ? Colors.redAccent : const Color(0xFF34D399),
                  width: 1.5,
                ),
              ),
            ),
            onChanged: (value) {
              if (value.isNotEmpty) {
                if (index < 5) {
                  widget.focusNodes[index + 1].requestFocus();
                } else {
                  widget.focusNodes[index].unfocus();
                }
              } else {
                if (index > 0) {
                  widget.focusNodes[index - 1].requestFocus();
                }
              }
            },
          ),
        );
      }),
    );
  }
}
