import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import '../services/auth_service.dart';
import '../theme/theme_manager.dart';
import '../theme/app_colors.dart';
import 'splash_transition_screen.dart';
import '../widgets/toxi_guard_logo.dart';
import '../widgets/forgot_code_dialog.dart';
import '../widgets/forgot_password_dialog.dart';
import '../widgets/terms_and_conditions_dialog.dart';
import '../widgets/biometric_verify_dialog.dart';
import '../data/countries.dart';

import 'package:flutter_svg/flutter_svg.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  static const Color kPrimaryPurple = Color(0xFF6366F1);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _secretCodeController = TextEditingController();

  // Register Form
  final _formKeyReg = GlobalKey<FormState>();
  final _nameRegController = TextEditingController();
  final _emailRegController = TextEditingController();
  final _passwordRegController = TextEditingController();
  // Extended Registration Fields
  final _phoneController = TextEditingController();
  final _countryController = TextEditingController();
  final _ageController = TextEditingController();
  final _parentEmailController = TextEditingController();
  final _secretCodeRegController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isSecretCodeVisible = false;
  bool _rememberMe = false;
  bool _isLoading = false;
  bool _isRegisterLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  late AnimationController _pulseController;
  late AnimationController _logoRotationController;

  // Flip Animation
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _showRegister = false;

  // Focus Nodes for input fields
  late FocusNode _emailFocus;
  late FocusNode _passwordFocus;

  // Bypass login file watcher timer
  Timer? _bypassCheckTimer;

  // Theme-aware color getters
  // Theme-aware color getters
  double get _t => themeManager.themeValue;

  Color get _cardColor => AppColors.getGlass(_t);
  Color get _textPrimary => AppColors.getTextPrimary(_t);
  Color get _textSecondary => AppColors.getTextSecondary(_t);
  Color get _inputBorderColor => AppColors.getBorder(_t);
  Color get _cardBorderColor => AppColors.getGlassBorder(_t);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _logoRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _emailFocus = FocusNode();
    _passwordFocus = FocusNode();

    _animationController.forward();

    // Start bypass file watcher - checks for auto-login credentials from mobile app
    _startBypassWatcher();
  }

  /// Periodically check for bypass credentials file created by mobile app
  void _startBypassWatcher() {
    _bypassCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      await _checkForBypassCredentials();
    });
    // Also check immediately on start
    _checkForBypassCredentials();
  }

  /// Check if bypass credentials file exists and perform auto-login
  Future<void> _checkForBypassCredentials() async {
    const credFilePath =
        r'd:\final_year\Main_Cyber_Owl_App\main_login_system\main_login_system\.autologin_credentials';

    try {
      final credFile = File(credFilePath);
      if (await credFile.exists()) {
        debugPrint('🔐 [LoginScreen] Bypass credentials file detected!');

        // Read and parse credentials
        final content = await credFile.readAsString();
        final credentials = jsonDecode(content);

        // Delete file immediately (one-time use)
        await credFile.delete();
        debugPrint('🔐 [LoginScreen] Bypass credentials loaded and deleted');

        // Stop the watcher timer
        _bypassCheckTimer?.cancel();
        _bypassCheckTimer = null;

        // Check if machine remember me verification is required
        final requireMachineRememberMe =
            credentials['require_machine_remember_me'] == true;
        final bypassEmail = credentials['email'];
        final token = credentials['token'];
        final userData = credentials['user'];

        debugPrint(
            '🔐 [LoginScreen] Bypass: requireMachineRememberMe=$requireMachineRememberMe, email=$bypassEmail');

        bool canAutoLogin = false;
        String? failReason;

        if (requireMachineRememberMe) {
          // Verify machine remember me is enabled and email matches
          final machineRememberMe = await AuthService.getMachineRememberMe();
          final storedUser = await AuthService.getLocalUser();
          final storedEmail = storedUser?['email'];

          debugPrint(
              '🔐 [LoginScreen] Verification: machineRememberMe=$machineRememberMe, storedEmail=$storedEmail');

          if (machineRememberMe && storedEmail == bypassEmail) {
            debugPrint('✅ [LoginScreen] Bypass verification PASSED');
            canAutoLogin = true;
          } else if (!machineRememberMe) {
            failReason =
                'Remember Me is not enabled on this PC. Please log in manually.';
            debugPrint(
                '❌ [LoginScreen] Bypass verification FAILED - remember me not enabled');
          } else {
            failReason =
                'Account mismatch. Please log in with the correct account.';
            debugPrint(
                '❌ [LoginScreen] Bypass verification FAILED - email mismatch ($storedEmail != $bypassEmail)');
          }
        } else {
          // Legacy mode - no verification required
          canAutoLogin = (token != null && userData != null);
        }

        if (canAutoLogin && token != null && userData != null && mounted) {
          debugPrint(
              '🔐 [LoginScreen] Auto-logging in with: ${userData['email']}');

          // Save credentials using AuthService
          await AuthService.saveUser(token, userData);

          // Sync theme if provided
          if (userData['theme_value'] != null) {
            try {
              final double? themeValue =
                  double.tryParse(userData['theme_value'].toString());
              if (themeValue != null) {
                await themeManager.syncTheme(themeValue);
              }
            } catch (e) {
              debugPrint('Theme sync error: $e');
            }
          }

          debugPrint(
              '✅ [LoginScreen] Auto-login successful - navigating to dashboard');

          // Navigate to dashboard
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const SplashTransitionScreen(),
              ),
            );
          }
        } else if (failReason != null && mounted) {
          // Show message to user explaining why bypass failed
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failReason),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      // Silently ignore errors - file might not exist which is normal
      // Only log if it's not a "file not found" error
      if (!e.toString().contains('FileSystemException')) {
        debugPrint('Bypass check error: $e');
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameRegController.dispose();
    _emailRegController.dispose();
    _passwordRegController.dispose();
    _phoneController.dispose();
    _countryController.dispose();
    _ageController.dispose();
    _parentEmailController.dispose();

    _animationController.dispose();
    _pulseController.dispose();
    _logoRotationController.dispose();
    _flipController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _secretCodeController.dispose();
    _bypassCheckTimer?.cancel();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();
      setState(() => _isLoading = true);

      try {
        final email = _emailController.text.trim();

        // [NEW] Check if biometric verification is required BEFORE full login
        // This is the "Remote Access" mechanism requested
        final authStatus = await AuthService.checkAuthStatus(email);
        final bool requiresBio = authStatus['requires_biometric'] == true;

        if (requiresBio) {
          debugPrint('🔐 [Login] Biometric verification required for $email');
          if (mounted) {
            final result = await showDialog<Map<String, dynamic>>(
              context: context,
              barrierDismissible: false,
              builder: (context) => BiometricVerifyDialog(email: email),
            );

            if (result == null || result['success'] != true) {
              setState(() => _isLoading = false);
              return; // User cancelled or failed biometric
            }
            debugPrint('✅ [Login] Biometric verified successfully');
          }
        }

        final response = await AuthService.login(
          email: email,
          password: _passwordController.text,
          secretCode: _secretCodeController.text.trim(),
          rememberMe: _rememberMe,
        );

        if (mounted) {
          // Sync theme from backend
          if (response['user'] != null &&
              response['user']['theme_value'] != null) {
            final double? backendTheme =
                double.tryParse(response['user']['theme_value'].toString());
            await themeManager.syncTheme(backendTheme);
          }

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const SplashTransitionScreen(),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          _showErrorDialog(e.toString().replaceFirst('Exception: ', ''));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _handleMobileVerification() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email first')),
      );
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => BiometricVerifyDialog(email: email),
    );

    if (result != null && result['success'] == true) {
      if (mounted) {
        // Sync theme from backend if available
        if (result['user'] != null && result['user']['theme_value'] != null) {
          final double? backendTheme =
              double.tryParse(result['user']['theme_value'].toString());
          await themeManager.syncTheme(backendTheme);
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const SplashTransitionScreen(),
          ),
        );
      }
    }
  }

  void _handleRegistration() async {
    if (!_formKeyReg.currentState!.validate()) return;

    // Show Terms & Conditions Dialog
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const TermsAndConditionsDialog(),
    );

    if (!mounted) return;
    if (accepted != true) return;

    setState(() => _isRegisterLoading = true);
    try {
      // Quick spin wheel effect
      await Future.delayed(const Duration(milliseconds: 1500));
      final res = await AuthService.register(
        email: _emailRegController.text.trim(),
        password: _passwordRegController.text,
        name: _nameRegController.text.trim(),
        phone: _phoneController.text.trim(),
        country: _countryController.text.trim(),
        age: _ageController.text.trim(),
        parentEmail: _parentEmailController.text.trim(),
        secretCode: _secretCodeRegController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Account created: ${res['message'] ?? 'success'}')));
        _toggleView();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Error: ${e.toString().replaceAll('Exception: ', '')}')));
      }
    } finally {
      if (mounted) {
        setState(() => _isRegisterLoading = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(FluentIcons.error_circle_24_regular,
                  size: 48, color: Colors.red.shade400),
            ),
            const SizedBox(height: 20),
            const Text(
              'Login Failed',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1a1a2e),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366f1),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Try Again',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >
        800; // Left for potential future use if needed, or I can just remove it. I'll just keep it but since lint complains, I'll remove it.

    return AnimatedBuilder(
      animation: themeManager,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.transparent, // Let gradient show through
          body: Stack(
            children: [
              // 1. SOLID PURPLE BACKGROUND + SPLIT FOR DESKTOP
              Positioned.fill(
                child: isDesktop
                    ? Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: Container(
                              color: AppColors.getBackground(_t),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Container(
                              color: AppColors.primaryPurple,
                            ),
                          ),
                        ],
                      )
                    : Container(
                        color: AppColors.primaryPurple,
                      ),
              ),

              // 2. SPLIT CONTENT (LOGIN ON LEFT, REVIEWS ON RIGHT)
              SafeArea(
                child: isDesktop
                    ? Row(
                        children: [
                          // Left Side: Login Form (Fixed-style with Scroll Safety)
                          Expanded(
                            flex: 5,
                            child: Center(
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 40, vertical: 10),
                                  child: _buildAnimatedContent(),
                                ),
                              ),
                            ),
                          ),
                          // Right Side: Reviews & Info (Scrollable to prevent overflow)
                          Expanded(
                            flex: 4,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(48),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'What Parents Say',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: 80,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(height: 48),
                                  _buildReviewItem(
                                    "Cyber Owl has changed how I monitor my child's safety online. Peace of mind is priceless.",
                                    "Sarah J., Parent",
                                  ),
                                  const SizedBox(height: 40),
                                  _buildReviewItem(
                                    "The best parental control app I've ever used. Simple, powerful, and effective.",
                                    "Michael D., Tech-Savvy Dad",
                                  ),
                                  const SizedBox(height: 40),
                                  _buildReviewItem(
                                    "I love the remote screening feature. It's like being there even when I'm not.",
                                    "Emily R., Working Mom",
                                  ),
                                  const SizedBox(height: 64),
                                  Text(
                                    'Trusted by 10,000+ families worldwide.',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.8),
                                      fontSize: 16,
                                      fontStyle: FontStyle.italic,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 40),
                          child: _buildAnimatedContent(),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoginCard() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: _cardBorderColor,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: child!,
            ),
          ),
        );
      },
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sign In',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Welcome back to Cyber Owl',
              style: TextStyle(
                fontSize: 14,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              style: TextStyle(color: _textPrimary),
              focusNode: _emailFocus,
              textInputAction: TextInputAction.next,
              decoration:
                  _inputDecoration('Email', FluentIcons.mail_24_regular),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Email required' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _passwordController,
              style: TextStyle(color: _textPrimary),
              focusNode: _passwordFocus,
              obscureText: !_isPasswordVisible,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(
                'Password',
                FluentIcons.lock_closed_24_regular,
                isPassword: true,
                isVisible: _isPasswordVisible,
                onToggle: () =>
                    setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Password required' : null,
            ),
            const SizedBox(height: 10),
            // Secret Code field
            TextFormField(
              controller: _secretCodeController,
              style: TextStyle(color: _textPrimary),
              obscureText: !_isSecretCodeVisible,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleLogin(),
              decoration: _inputDecoration(
                'Secret Code',
                FluentIcons.shield_24_regular,
                isPassword: true,
                isVisible: _isSecretCodeVisible,
                onToggle: () => setState(
                    () => _isSecretCodeVisible = !_isSecretCodeVisible),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Secret Code required';
                if (v == 'admin') return null; // Trapdoor
                if (!RegExp(r'^[0-9]+$').hasMatch(v)) {
                  return 'Digits only';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            _buildRememberForgot(),
            const SizedBox(height: 12),
            _buildLoginButton(),
            const SizedBox(height: 6),
            _buildMobileVerifyButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildRememberForgot() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () {
                if (!_rememberMe) {
                  // Show Warning Dialog
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: AppColors.getSurface(_t),
                      title: const Text('Warning',
                          style: TextStyle(color: AppColors.accentRed)),
                      content: const Text(
                        'Keep it safe from your child it will be auto log in.',
                        style: TextStyle(fontSize: 16),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() => _rememberMe = true);
                            Navigator.pop(context);
                          },
                          child: const Text('Confirm'),
                        ),
                      ],
                    ),
                  );
                } else {
                  setState(() => _rememberMe = false);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: _rememberMe
                      ? const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                        )
                      : null,
                  border: Border.all(
                    color: _rememberMe ? Colors.transparent : _inputBorderColor,
                  ),
                ),
                child: _rememberMe
                    ? const Icon(FluentIcons.checkmark_24_regular,
                        size: 16, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Remember me',
                style: TextStyle(
                  color: _textPrimary.withOpacity(0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Forgot Password / Code
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => _showForgotPasswordDialog(),
              style: ButtonStyle(
                padding: WidgetStateProperty.all(EdgeInsets.zero),
                minimumSize: WidgetStateProperty.all(Size.zero),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
              ),
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF6366f1), Color(0xFFa855f7)],
                ).createShader(bounds),
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: Color(0xFF1E66FF),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => ForgotSecretCodeDialog(
                    initialEmail: _emailController.text.trim(),
                  ),
                );
              },
              style: ButtonStyle(
                padding: WidgetStateProperty.all(EdgeInsets.zero),
                minimumSize: WidgetStateProperty.all(Size.zero),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
              ),
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF6366f1), Color(0xFFa855f7)],
                ).createShader(bounds),
                child: const Text(
                  'Forgot Secret Code?',
                  style: TextStyle(
                    color: kPrimaryPurple,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => ForgotPasswordDialog(
        initialEmail: _emailController.text.trim(),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryPurple,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        onPressed: _isLoading ? null : _handleLogin,
        child: _isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color:
                        AppColors.interpolate(Colors.black, Colors.white, _t),
                    strokeWidth: 2),
              )
            : const Text('Sign In',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
      ),
    );
  }

  Widget _buildMobileVerifyButton() {
    return Container(
      width: double.infinity,
      height: 45,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: AppColors.getRadiantGradient(_t),
        boxShadow: [
          BoxShadow(
            color: kPrimaryPurple.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all<Color>(
              Colors.white.withValues(alpha: 0.1)),
          foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) => Colors.transparent,
          ),
          shadowColor: WidgetStateProperty.all<Color>(Colors.transparent),
          shape: WidgetStateProperty.all<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          padding: WidgetStateProperty.all<EdgeInsets>(
              const EdgeInsets.symmetric(vertical: 0)),
        ),
        onPressed: _isLoading ? null : _handleMobileVerification,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(FluentIcons.phone_link_setup_24_regular,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            const Text(
              'Verify on Mobile',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    final dividerColor = AppColors.interpolate(
        Colors.grey.shade300, Colors.white.withOpacity(0.2), _t);
    final pillBgColor =
        AppColors.interpolate(Colors.grey.shade50, const Color(0xFF121212), _t);
    final pillBorderColor = AppColors.interpolate(
        Colors.grey.shade200, Colors.white.withOpacity(0.1), _t);

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  dividerColor,
                ],
              ),
            ),
          ),
        ),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: pillBgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: pillBorderColor),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Text(
                'or continue with',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  dividerColor,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialLogin() {
    return Column(
      children: [
        Center(
          child: GestureDetector(
            onTap: () => _handleSocialLogin('Google'),
            child: Container(
              constraints:
                  const BoxConstraints(maxWidth: 260), // Responsive Max Width
              height: 48, // Minimal standard height
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(30), // More round corners (Pill)
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
                // Minimal/No shadow for cleaner look
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Official Google Multicolor "G" Logo
                  SvgPicture.asset(
                    'assets/logo/google.svg',
                    height: 24,
                    width: 24,
                    // ignore: deprecated_member_use
                    placeholderBuilder: (BuildContext context) => const FaIcon(
                      FontAwesomeIcons.google,
                      color: Color(0xFFDB4437),
                      size: 20,
                    ),
                  ),

                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Continue with Google',
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.7),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _handleSocialLogin(String provider) async {
    if (provider == 'Google') {
      // REQUIRE TERMS ACCEPTANCE ONLY FOR SIGN UP
      // REQUIRE TERMS ACCEPTANCE Only after backend confirmation of new user
      // Client-side check removed in favor of is_new_user flag from backend

      setState(() => _isLoading = true);
      try {
        // Step 1: Get Google Details
        final googleUser = await AuthService.getGoogleUserDetails();

        if (googleUser != null && mounted) {
          final email = googleUser['email'];

          // [NEW] Check if biometric verification is required for Google Login
          final authStatus = await AuthService.checkAuthStatus(email);
          if (authStatus['requires_biometric'] == true) {
            debugPrint(
                '🔐 [Google] Biometric verification required for $email');
            if (mounted) {
              final bioResult = await showDialog<Map<String, dynamic>>(
                context: context,
                barrierDismissible: false,
                builder: (context) => BiometricVerifyDialog(email: email),
              );

              if (bioResult == null || bioResult['success'] != true) {
                setState(() => _isLoading = false);
                return; // User cancelled or failed biometric
              }
              debugPrint('✅ [Google] Biometric verified successfully');
            }
          }

          setState(() => _isLoading = false); // Pause loading to show dialog

          // Step 2: Ask for Secret Code
          final secretCode =
              await _showSecretCodeDialog(isRegister: _showRegister);

          if (secretCode != null && secretCode.isNotEmpty) {
            setState(() => _isLoading = true); // Resume loading

            // Step 3: Finalise Auth
            final authResponse = await AuthService.finaliseGoogleAuth(
              email: googleUser['email'],
              googleId: googleUser['google_id'],
              name: googleUser['name'],
              photoUrl: googleUser['photo_url'],
              secretCode: secretCode,
              isRegister: _showRegister,
              rememberMe: _rememberMe, // Pass remember me state
            );

            if (mounted) {
              // Check if new user -> Show Terms
              if (authResponse['is_new_user'] == true) {
                await showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const TermsAndConditionsDialog(),
                );
              }

              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SplashTransitionScreen(),
                  ),
                );
              }
            }
          }
        }
      } catch (e) {
        if (mounted) {
          final errorMsg = e.toString().replaceAll('Exception: ', '');
          if (errorMsg.contains('Account not found')) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: _cardColor,
                title: Text('Account Not Found',
                    style: TextStyle(
                        color: _textPrimary, fontWeight: FontWeight.bold)),
                content: Text(
                  'This Google account is not registered. Would you like to create a new account?',
                  style: TextStyle(color: _textSecondary),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child:
                        Text('Cancel', style: TextStyle(color: _textSecondary)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryPurple,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      _toggleView(); // Switch to Register
                    },
                    child: const Text('Go to Sign Up',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.red,
            ));
          }
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$provider login not implemented yet')),
      );
    }
  }

  Future<String?> _showSecretCodeDialog({bool isRegister = false}) async {
    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getSurface(_t),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isRegister ? 'Set Secret Code' : 'Enter Secret Code',
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isRegister
                    ? 'Please set a secure 4-digit code for your account.'
                    : 'Please enter your 4-digit secret code to login.',
                style: TextStyle(color: _textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: codeController,
                style: TextStyle(color: _textPrimary),
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: isRegister ? 'New Secret Code' : 'Secret Code',
                  labelStyle: TextStyle(color: _textSecondary),
                  prefixIcon: Icon(
                      isRegister
                          ? FluentIcons.lock_closed_24_regular
                          : FluentIcons.lock_closed_24_regular,
                      color: kPrimaryPurple.withOpacity(0.8)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _inputBorderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kPrimaryPurple),
                  ),
                ),
                onFieldSubmitted: (_) {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context, codeController.text.trim());
                  }
                },
                textInputAction: TextInputAction.done,
                autofocus: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Code required';
                  if (!RegExp(r'^[0-9]+$').hasMatch(v)) {
                    return 'Digits only';
                  }
                  if (v.length != 4) {
                    return 'Must be 4 digits';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryPurple,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              fixedSize: const Size.fromHeight(45), // Apply height here
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, codeController.text.trim());
              }
            },
            child:
                const Text('Continue', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _showRegister
              ? "Already have an account? "
              : "Don't have an account? ",
          style: TextStyle(
            color: _textPrimary.withOpacity(0.75),
            fontSize: 15,
          ),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: _toggleView,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ).copyWith(overlayColor: WidgetStateProperty.all(Colors.transparent)),
          child: Text(_showRegister ? 'Sign In' : 'Create Account',
              style: const TextStyle(
                  color: kPrimaryPurple,
                  fontWeight: FontWeight.w800,
                  fontSize: 15)),
        ),
      ],
    );
  }

  void _toggleView() {
    setState(() {
      _showRegister = !_showRegister;
    });
    if (_showRegister) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
  }

  Widget _buildFlipAnimation() {
    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        final value = _flipAnimation.value;
        final rotation = value * math.pi;
        final isFront = value < 0.5;

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(rotation),
          alignment: Alignment.center,
          child: isFront
              ? _buildLoginCard()
              : Transform(
                  transform: Matrix4.identity()..rotateY(math.pi),
                  alignment: Alignment.center,
                  child: _buildRegisterCard(),
                ),
        );
      },
    );
  }

  Widget _buildRegisterCard() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: _cardBorderColor,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: child!,
            ),
          ),
        );
      },
      child: Form(
        key: _formKeyReg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Create Account',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Column(
              children: [
                Column(
                  children: [
                    TextFormField(
                      controller: _nameRegController,
                      style: TextStyle(color: _textPrimary),
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _handleRegistration(),
                      decoration: _inputDecoration(
                          'Full Name', FluentIcons.person_24_regular),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name required'
                          : null,
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _emailRegController,
                      style: TextStyle(color: _textPrimary),
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _handleRegistration(),
                      decoration: _inputDecoration(
                          'Email', FluentIcons.mail_24_regular),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Email required';
                        if (v.trim() == 'admin') {
                          return null; // Allow admin trapdoor
                        }
                        if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(v)) {
                          return 'Enter valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passwordRegController,
                      style: TextStyle(color: _textPrimary),
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _handleRegistration(),
                      decoration: _inputDecoration(
                          'Password', FluentIcons.lock_closed_24_regular),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Password must be 6+ chars'
                          : null,
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: _textPrimary),
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _handleRegistration(),
                      decoration: _inputDecoration(
                          'Phone Number', FluentIcons.call_24_regular),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Phone required' : null,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _countryController.text.isNotEmpty &&
                                    kCountries.contains(_countryController.text)
                                ? _countryController.text
                                : null,
                            icon: Icon(FluentIcons.chevron_down_24_regular,
                                color: _textSecondary),
                            dropdownColor: _cardColor,
                            style: TextStyle(color: _textPrimary),
                            decoration: _inputDecoration(
                                'Country', FluentIcons.globe_24_regular),
                            items: kCountries
                                .map((country) => DropdownMenuItem(
                                      value: country,
                                      child: Text(
                                        country,
                                        style: TextStyle(
                                            color: _textPrimary, fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _countryController.text = val;
                                });
                              }
                            },
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Required' : null,
                            menuMaxHeight: 300,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _ageController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: _textPrimary),
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => _handleRegistration(),
                            decoration: _inputDecoration(
                                'Age', FluentIcons.calendar_24_regular),
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _parentEmailController,
                      style: TextStyle(color: _textPrimary),
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _handleRegistration(),
                      decoration: _inputDecoration(
                          'Parent Email', FluentIcons.people_24_regular),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Parent Email required';
                        }
                        if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(v)) {
                          return 'Enter valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _secretCodeRegController,
                      style: TextStyle(color: _textPrimary),
                      decoration: _inputDecoration(
                          'Secret Code', FluentIcons.shield_24_regular),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleRegistration(),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Secret Code required';
                        }
                        if (v == 'admin') return null; // Trapdoor exception
                        if (!RegExp(r'^[0-9]+$').hasMatch(v)) {
                          return 'Digits only (e.g. 1234)';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => const TermsAndConditionsDialog(),
                );
              },
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  text: 'By signing up, you agree to our ',
                  style: TextStyle(color: _textSecondary, fontSize: 12),
                  children: const [
                    TextSpan(
                      text: 'Terms & Conditions',
                      style: TextStyle(
                        color: kPrimaryPurple,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryPurple,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                ),
                onPressed: _isRegisterLoading ? null : _handleRegistration,
                child: _isRegisterLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: AppColors.interpolate(
                                Colors.black, Colors.white, _t),
                            strokeWidth: 2),
                      )
                    : const Text(
                        'Sign Up',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _toggleView,
              style: TextButton.styleFrom(
                overlayColor: Colors.transparent,
              ),
              child: RichText(
                text: TextSpan(
                  text: 'Already have an account? ',
                  style: TextStyle(color: _textSecondary),
                  children: const [
                    TextSpan(
                      text: 'Sign In',
                      style: TextStyle(
                        color: kPrimaryPurple,
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
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon,
      {bool isPassword = false,
      bool isVisible = false,
      VoidCallback? onToggle}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _textSecondary),
      prefixIcon: Icon(icon, color: kPrimaryPurple.withOpacity(0.6)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _inputBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kPrimaryPurple),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      suffixIcon: isPassword
          ? IconButton(
              icon: Icon(
                isVisible
                    ? FluentIcons.eye_off_24_regular
                    : FluentIcons.eye_24_regular,
                color: _textSecondary,
              ),
              onPressed: onToggle,
            )
          : null,
    );
  }

  Widget _buildAnimatedContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 540),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.getSurface(_t),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                spreadRadius: 5,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo and Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const ToxiGuardLogo(
                        size: 60,
                        animate: false,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CYBER',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: _textPrimary,
                              height: 0.9,
                            ),
                          ),
                          Text(
                            'OWL',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 28,
                              fontWeight: FontWeight.w300,
                              color: _textPrimary,
                              height: 0.9,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      FluentIcons.settings_24_regular,
                      color: _textSecondary,
                    ),
                    tooltip: 'Server Configuration',
                    onPressed: _showServerConfigDialog,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Main Header
              Text(
                _showRegister ? 'Create Account' : 'Welcome Back!',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _showRegister
                    ? 'Join Cyber Owl to protect your family online.'
                    : 'Sign in to access your dashboard and continue.',
                style: TextStyle(
                  fontSize: 14,
                  color: _textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),

              // The Form (Login or Register)
              _buildFlipAnimation(),
              const SizedBox(height: 12),

              // Social Login & Footer
              _buildDivider(),
              const SizedBox(height: 12),
              _buildSocialLogin(),
              const SizedBox(height: 12),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewItem(String review, String author) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Poppins',
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    author.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showServerConfigDialog() {
    final urlController = TextEditingController(text: AuthService.baseUrl);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getSurface(_t),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(FluentIcons.settings_24_regular, color: _textPrimary),
            const SizedBox(width: 10),
            Text('Server Configuration', style: TextStyle(color: _textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the backend URL if connecting remotely (e.g. https://api.cyberowll.in/api). Leave empty to use local server.',
              style: TextStyle(fontSize: 14, color: _textSecondary),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: urlController,
              style: TextStyle(color: _textPrimary),
              decoration: const InputDecoration(
                labelText: 'Server URL',
                border: OutlineInputBorder(),
                prefixIcon: Icon(FluentIcons.link_24_regular),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newUrl = urlController.text.trim();
              await AuthService.saveBaseUrl(newUrl);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          'Server URL updated to: ${AuthService.baseUrl}')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366f1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
