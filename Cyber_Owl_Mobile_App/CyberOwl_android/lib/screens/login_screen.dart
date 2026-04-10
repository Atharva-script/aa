import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../providers/app_provider.dart';
import '../utils/constants.dart';
import 'home_screen.dart';
import 'package:icons_plus/icons_plus.dart';
import 'biometric_auth_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _secretCodeController = TextEditingController();

  bool _obscurePassword = true;
  bool _showSecretCode = false;
  bool _isLoading = false;
  bool _isDiscovering = false; // tracks background server discovery

  String? _error;

  @override
  void initState() {
    super.initState();
    // Attempt auto-login after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDiscoveryAndLogin();
    });
  }

  Future<void> _initDiscoveryAndLogin() async {
    final provider = context.read<AppProvider>();

    debugPrint(
        '📱 [INIT] Starting _initDiscoveryAndLogin, isConnected=${provider.isConnected}');

    // Always try auto-login with cached URL first (fastest path)
    if (provider.isConnected) {
      debugPrint('📱 [INIT] Already connected, checking auto-login...');
      await _checkAutoLogin();
      return;
    }

    // Show subtle discovery indicator without blocking the form
    if (mounted) setState(() => _isDiscovering = true);

    // Run UDP discovery; on enterprise/university networks UDP broadcast
    // is often suppressed, so we timeout quickly and fall back.
    debugPrint('📱 [INIT] Running UDP discovery...');
    final discoveryFuture = provider.discoverServer();
    await Future.any([
      discoveryFuture,
      Future.delayed(const Duration(seconds: 5)),
    ]);

    if (mounted) setState(() => _isDiscovering = false);
    if (!mounted) return;

    debugPrint(
        '📱 [INIT] Discovery done, isConnected=${provider.isConnected}, apiBaseUrl=${AppConstants.apiBaseUrl}');

    // If UDP discovery didn't connect us, try the cached URL from SharedPreferences
    if (!provider.isConnected && AppConstants.apiBaseUrl.isNotEmpty) {
      debugPrint('📱 [INIT] Trying cached URL fallback...');
      await provider.testConnection(AppConstants.apiBaseUrl);
    }

    debugPrint('📱 [INIT] Calling _checkAutoLogin...');
    await _checkAutoLogin();
    debugPrint('📱 [INIT] _initDiscoveryAndLogin complete');
  }

  Future<void> _checkAutoLogin() async {
    final provider = context.read<AppProvider>();

    debugPrint('📱 [AUTO-LOGIN] Starting auto-login check...');
    // Show full-screen spinner ONLY during silent auto-login check
    if (mounted) setState(() => _isLoading = true);
    final success = await provider.tryAutoLogin();
    debugPrint('📱 [AUTO-LOGIN] tryAutoLogin returned: $success');
    if (mounted) setState(() => _isLoading = false);

    if (success && mounted) {
      if (provider.isPendingBiometric) {
        debugPrint('📱 [AUTO-LOGIN] Navigating to BiometricAuthScreen');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BiometricAuthScreen()),
        );
      } else {
        debugPrint('📱 [AUTO-LOGIN] Navigating to HomeScreen');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else {
      debugPrint('📱 [AUTO-LOGIN] Auto-login failed, showing login form');
    }
  }

  Future<void> _handleLogin() async {
    debugPrint('🔑 [HANDLE-LOGIN] Login button pressed');
    if (!_formKey.currentState!.validate()) {
      debugPrint('🔑 [HANDLE-LOGIN] Form validation FAILED');
      return;
    }

    debugPrint('🔑 [HANDLE-LOGIN] Form valid, calling provider.login...');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = context.read<AppProvider>();
      final success = await provider.login(
        _usernameController.text.trim(),
        _passwordController.text,
        _secretCodeController.text,
      );

      debugPrint('🔑 [HANDLE-LOGIN] provider.login returned: $success');

      if (success) {
        if (mounted) {
          if (provider.isPendingBiometric) {
            debugPrint('🔑 [HANDLE-LOGIN] Navigating to BiometricAuthScreen');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const BiometricAuthScreen()),
            );
          } else {
            debugPrint('🔑 [HANDLE-LOGIN] Navigating to HomeScreen');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          }
        }
      } else if (mounted) {
        debugPrint('🔑 [HANDLE-LOGIN] Login failed: ${provider.errorMessage}');
        setState(() {
          _error = provider.errorMessage ?? 'Login failed';
        });
      }
    } catch (e) {
      debugPrint('🔑 [HANDLE-LOGIN] Exception: $e');
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = context.read<AppProvider>();

      // Step 1: Sign in with Google
      final successStep1 = await provider.signInWithGoogleStep1();

      if (!successStep1) {
        if (mounted) {
          setState(() {
            _error = provider.errorMessage ?? 'Google Sign-In failed';
            _isLoading = false;
          });
        }
        return;
      }

      if (!mounted) return;

      // Step 2: Prompt for Secret Code
      final secretCode = await _showSecretCodeDialog();

      if (secretCode == null || secretCode.isEmpty) {
        // User cancelled dialog
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      // Step 3: Authenticate with Backend
      final successStep2 = await provider.signInWithGoogleStep2(secretCode);

      if (successStep2 && mounted) {
        if (provider.isPendingBiometric) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const BiometricAuthScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else if (mounted) {
        setState(() {
          _error = provider.errorMessage ?? 'Login failed';
          _isLoading = false; // Ensure loading stops
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<String?> _showSecretCodeDialog() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enter Secret Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your account requires a secret code to complete login.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Secret Code',
                border: OutlineInputBorder(),
                prefixIcon: Icon(FluentIcons.lock_closed_24_regular),
              ),
              keyboardType: TextInputType.text, // or number if numeric
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppProvider>(); // Watch for changes (e.g. discovery status)
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset:
          false, // Prevents keyboard from pushing/scrolling the layout
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.primary,
      body: Stack(
        children: [
          // Custom Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/login_bg.jpg',
              fit: BoxFit.cover,
            ),
          ),
          // Gradient Overlay to ensure readability
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Content
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            )
          else
            Column(
              children: [
                // Subtle discovery banner (doesn't block the form)
                if (_isDiscovering)
                  Material(
                    color: Colors.black38,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          ),
                          SizedBox(width: 8),
                          Text('Searching for server…',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),

                // Header Section
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Column(
                      children: [
                        // Top Navigation Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios,
                                  color: Colors.white, size: 20),
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),

                            // Register Toggle (Visual Only)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    "Don't have an account? ",
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.8),
                                      fontSize: 12,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Registration not implemented yet')),
                                      );
                                    },
                                    child: const Text(
                                      "Get Started",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20), // Compact spacing

                        // App Title with Logo
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'android/nl.png',
                              height: 100, // Restored size
                              width: 100,
                            ),
                            const SizedBox(width: 2), // Reduced Gap to 2px
                            Text(
                              'CyberOwl',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.black : Colors.white,
                                letterSpacing: 1.0,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30), // Spacing before body
                      ],
                    ),
                  ),
                ),

                // Body Section (Glassmorphism Card)
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color:
                          theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    // Removed SingleChildScrollView
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return ScrollConfiguration(
                          behavior: const ScrollBehavior()
                              .copyWith(scrollbars: false),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 20),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Center(
                                    child: Text(
                                      'Welcome Back',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: theme
                                            .textTheme.headlineLarge?.color,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Center(
                                    child: Text(
                                      'Enter your password to continue',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: theme.textTheme.bodyMedium?.color
                                            ?.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  if (_error != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.red.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.red
                                                .withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                              FluentIcons
                                                  .error_circle_24_regular,
                                              color: Colors.red,
                                              size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _error!,
                                              style: const TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 13),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  _buildTextField(
                                    controller: _usernameController,
                                    label: 'Username or Email',
                                    hint: 'Enter your username',
                                    icon: FluentIcons.person_24_regular,
                                    keyboardType: TextInputType.emailAddress,
                                    theme: theme,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    controller: _passwordController,
                                    label: 'Password',
                                    hint: 'Enter your password',
                                    icon: FluentIcons.lock_closed_24_regular,
                                    obscure: _obscurePassword,
                                    theme: theme,
                                    isPassword: true,
                                    onToggleVisibility: () => setState(() =>
                                        _obscurePassword = !_obscurePassword),
                                    validator: (value) {
                                      if (value?.isEmpty ?? true) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _buildTextField(
                                    controller: _secretCodeController,
                                    label: 'Secret Code',
                                    hint: '••••',
                                    icon: FluentIcons.key_24_regular,
                                    obscure: !_showSecretCode,
                                    theme: theme,
                                    isPassword: true,
                                    onToggleVisibility: () => setState(() =>
                                        _showSecretCode = !_showSecretCode),
                                    validator: (value) {
                                      if (value?.isEmpty ?? true) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(50, 24),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content:
                                                  Text('Reset password flow')),
                                        );
                                      },
                                      child: Text(
                                        'Forgot your password?',
                                        style: TextStyle(
                                          color:
                                              theme.textTheme.bodyMedium?.color,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 30),
                                  const SizedBox(height: 30),
                                  Container(
                                    width: double.infinity,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      gradient: AppColors.primaryGradient,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.3),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed:
                                          _isLoading ? null : _handleLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 24,
                                              width: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text(
                                              'Login',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 30),
                                  Row(
                                    children: [
                                      Expanded(
                                          child: Divider(
                                        color: theme.dividerColor,
                                        thickness: 1,
                                      )),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        child: Text(
                                          'Or sign in with',
                                          style: TextStyle(
                                            color: theme
                                                .textTheme.bodyMedium?.color
                                                ?.withValues(alpha: 0.6),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                          child: Divider(
                                        color: theme.dividerColor,
                                        thickness: 1,
                                      )),
                                    ],
                                  ),
                                  const SizedBox(height: 30),
                                  SizedBox(
                                    width: double.infinity,
                                    child: _buildSocialButton(
                                      label: 'Continue with Google',
                                      theme: theme,
                                      onPressed: _isLoading
                                          ? null
                                          : _handleGoogleSignIn,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    required ThemeData theme,
    TextInputType? keyboardType,
    bool obscure = false,
    bool isPassword = false,
    VoidCallback? onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.textTheme.bodyMedium?.color,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText:
              obscure && (_obscurePassword), // Use local state if password
          style: TextStyle(
            color: theme.textTheme.bodyLarge?.color,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
            ),
            // prefixIcon: icon != null ? Icon(icon, color: theme.primaryColor.withValues(alpha: 0.6)) : null,
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      (_obscurePassword) // Use local state for visibility
                          ? FluentIcons.eye_off_24_regular
                          : FluentIcons.eye_24_regular,
                      color: theme.textTheme.bodyMedium?.color,
                      size: 20,
                    ),
                    onPressed: onToggleVisibility,
                  )
                : (icon != null
                    ? Icon(icon, color: Colors.green)
                    : null), // Example for 'Strong' indicator if needed, else null
            filled: true,
            fillColor: isDark
                ? const Color(0xFF1E2028).withValues(alpha: 0.5)
                : Colors.white,
            // Border logic: minimal/none until focus
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.danger),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required String label,
    // required String backgroundImagePath, // Removed
    required ThemeData theme,
    required VoidCallback? onPressed,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131314) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Google Icon
                Brand(Brands.google, size: 24),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1F1F1F),
                    fontFamily: 'Inter', // Ensure premium font if available
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
