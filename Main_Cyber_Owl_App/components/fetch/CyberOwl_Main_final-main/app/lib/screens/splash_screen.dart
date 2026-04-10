import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/backend_monitor.dart';
import '../services/auth_service.dart';
import '../widgets/toxi_guard_logo.dart';
import '../theme/app_colors.dart';
import '../theme/theme_manager.dart';
import '../main.dart' show isStealthMode;
import 'login_screen.dart';
import 'home_screen.dart';
import '../widgets/biometric_verify_dialog.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final BackendMonitor _backendMonitor = BackendMonitor();

  late AnimationController _textController;

  double _loadingPercentage = 0.0;
  String _currentFeatureText = "Initializing...";
  Timer? _progressTimer;
  Timer? _featureTimer;
  bool _isDisposed = false;
  bool _isBackendReady = false;

  final List<String> _features = [
    "Connecting to secure server...",
    "Loading AI detection models...",
    "Configuring protection layers...",
    "Verifying security protocols...",
    "Preparing dashboard...",
  ];

  @override
  void initState() {
    super.initState();
    _textController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));

    _listenToBackendStatus();
    _startLoadingLogic();
    _initializeBackend();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _textController.dispose();
    _progressTimer?.cancel();
    _featureTimer?.cancel();
    super.dispose();
  }

  void _startLoadingLogic() {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_isDisposed) return;
      setState(() {
        if (_isBackendReady) {
          if (_loadingPercentage < 1.0) _loadingPercentage += 0.05;
        } else {
          if (_loadingPercentage < 0.85) {
            _loadingPercentage += 0.005;
          } else if (_loadingPercentage < 0.95) {
            _loadingPercentage += 0.001;
          }
        }
      });
    });

    int index = 0;
    _featureTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (_isDisposed) return;
      _textController.forward(from: 0.0);
      setState(() {
        _currentFeatureText = _features[index % _features.length];
        index++;
      });
    });
  }

  Future<Map<String, dynamic>?> _loadAutoLoginCredentials() async {
    // Check for auto-login credentials file created by backend
    const credFilePath =
        r'd:\final_year\Main_Cyber_Owl_App\main_login_system\main_login_system\.autologin_credentials';
    debugPrint('🔐 Checking for auto-login credentials at: $credFilePath');

    final credFile = File(credFilePath);
    if (await credFile.exists()) {
      try {
        final content = await credFile.readAsString();
        final credentials = jsonDecode(content);

        // Delete file immediately after reading (one-time use for security)
        await credFile.delete();
        debugPrint('🔐 Auto-login credentials loaded and deleted');

        return credentials;
      } catch (e) {
        debugPrint('Error reading auto-login credentials: $e');
        try {
          await credFile.delete(); // Clean up corrupted file
        } catch (_) {}
      }
    }
    return null;
  }

  void _initializeBackend() async {
    final success = await _backendMonitor.initialize();
    if (success) {
      // Check for stealth mode first (existing behavior for bypass from mobile)
      debugPrint(
          '🔒 [SplashScreen] Checking stealth mode: isStealthMode=$isStealthMode');
      if (isStealthMode) {
        debugPrint(
            '🔒 [SplashScreen] Stealth mode is TRUE - checking bypass credentials');
        await Future.delayed(const Duration(milliseconds: 500));

        // Check for auto-login credentials
        final credentials = await _loadAutoLoginCredentials();

        if (credentials != null) {
          // Check if machine remember me verification is required
          final requireMachineRememberMe =
              credentials['require_machine_remember_me'] == true;
          final bypassEmail = credentials['email'];
          var token = credentials['token'];
          var userData = credentials['user'];

          debugPrint(
              '🔐 [SplashScreen] Bypass: requireMachineRememberMe=$requireMachineRememberMe, email=$bypassEmail');

          bool canAutoLogin = false;

          if (requireMachineRememberMe) {
            // Verify machine remember me is enabled
            final machineRememberMe = await AuthService.getMachineRememberMe();
            final storedUser = await AuthService.getLocalUser();
            final storedEmail = storedUser?['email'];

            debugPrint(
                '🔐 [SplashScreen] Verification: machineRememberMe=$machineRememberMe, storedEmail=$storedEmail');

            if (machineRememberMe && storedEmail == bypassEmail) {
              // Email matches and remember me is enabled on this machine
              debugPrint(
                  '✅ [SplashScreen] Bypass verification PASSED - same account, remember me enabled');
              canAutoLogin = true;
            } else if (!machineRememberMe) {
              debugPrint(
                  '❌ [SplashScreen] Bypass verification FAILED - remember me not enabled on this machine');
            } else {
              debugPrint(
                  '❌ [SplashScreen] Bypass verification FAILED - email mismatch ($storedEmail != $bypassEmail)');
            }
          } else {
            // Legacy mode - no verification required
            canAutoLogin = (token != null && userData != null);
          }

          // [NEW] extra safety: check for biometric requirement even for auto-login
          if (canAutoLogin && bypassEmail != null) {
            final authStatus = await AuthService.checkAuthStatus(bypassEmail);
            if (authStatus['parent_registered'] == true) {
              debugPrint(
                  '🔐 [SplashScreen] Biometric verification required for $bypassEmail (Parent is registered)');
              if (mounted) {
                final result = await showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) =>
                      BiometricVerifyDialog(email: bypassEmail),
                );

                if (result == null || result['success'] == false) {
                  debugPrint(
                      '❌ [SplashScreen] Biometric verification failed or cancelled');
                  canAutoLogin = false;
                } else {
                  debugPrint(
                      '✅ [SplashScreen] Biometric verification successful');
                  token = result['access_token'];
                  userData = result['user'];
                  canAutoLogin = true;
                }
              }
            }
          }

          if (canAutoLogin && token != null && userData != null) {
            debugPrint('🔐 Auto-logging in with: ${userData['email']}');

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

            debugPrint('✅ Auto-login successful');

            if (mounted) {
              _isBackendReady = true;
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => const HomeScreen(),
                  transitionsBuilder: (_, animation, __, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  transitionDuration: const Duration(milliseconds: 300),
                ),
              );
            }
            return; // Exit early after successful auto-login
          }
        }

        // Bypass verification failed or no credentials - show login screen
        debugPrint(
            '🔐 [SplashScreen] Bypass conditions not met - showing login screen');
        if (mounted) {
          _isBackendReady = true;
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const LoginScreen(),
              transitionsBuilder: (_, animation, __, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 600),
            ),
          );
        }
      } else {
        // Check for machine-specific remember me preference
        final machineRememberMe = await AuthService.getMachineRememberMe();
        final token = await AuthService.getToken();

        debugPrint(
            '🔐 [SplashScreen] Machine Remember Me: $machineRememberMe, Has Token: ${token != null}');

        debugPrint(
            '🔐 [SplashScreen] Auto-login enabled - checking biometric requirement');

        // Check for biometric requirement
        final storedUser = await AuthService.getLocalUser();
        final email = storedUser?['email'];

        bool verified = true;
        String? freshToken = token;
        Map<String, dynamic>? freshUser = storedUser;

        if (email != null) {
          final authStatus = await AuthService.checkAuthStatus(email);
          if (authStatus['parent_registered'] == true) {
            debugPrint(
                '🔐 [SplashScreen] Biometric verification required for $email (Parent is registered)');
            if (mounted) {
              final result = await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => BiometricVerifyDialog(email: email),
              );

              if (result == null || result['success'] == false) {
                verified = false;
              } else {
                freshToken = result['access_token'];
                freshUser = result['user'];
              }
            }
          }
        }

        if (verified && freshToken != null) {
          if (freshUser != null) {
            await AuthService.saveUser(freshToken, freshUser);
          }
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            _isBackendReady = true;
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const HomeScreen(),
                transitionsBuilder: (_, animation, __, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: const Duration(milliseconds: 300),
              ),
            );
          }
        } else {
          // Normal flow - show splash animation then go to login
          await Future.delayed(const Duration(seconds: 3));
          if (mounted) {
            _isBackendReady = true;
            await Future.delayed(const Duration(seconds: 1));
            if (mounted) {
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => const LoginScreen(),
                  transitionsBuilder: (_, animation, __, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  transitionDuration: const Duration(milliseconds: 600),
                ),
              );
            }
          }
        }
      }
    } else {
      // Backend failed to initialize
      if (mounted) {
        setState(() {
          _currentFeatureText = "Connection Failed";
        });
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Connection Error'),
            content: Text(_backendMonitor.lastError ??
                'Could not connect to the remote server.'),
            actions: [
              TextButton(
                onPressed: () => exit(0),
                child: const Text('Exit App'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentFeatureText = "Retrying connection...";
                  });
                  _initializeBackend();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _listenToBackendStatus() {
    _backendMonitor.statusStream.listen((status) {
      if (_isDisposed || !mounted) return;
      if (status == BackendStatus.failed) {
        setState(() => _currentFeatureText = "Retrying connection...");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = themeManager.themeValue;
    final primaryColor = AppColors.getPrimary(t);
    final bgColor = AppColors.getBackground(t);
    final textColor = AppColors.getTextPrimary(t);
    final subtleColor = AppColors.getTextSecondary(t);

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo
            const Hero(
              tag: 'app_logo',
              child: ToxiGuardLogo(size: 80, animate: false),
            ),

            const SizedBox(height: 28),

            // App Name
            Text(
              'Cyber Owl',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: textColor,
              ),
            ),

            const SizedBox(height: 6),

            // Tagline
            Text(
              'Parental Security Suite',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: subtleColor,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 48),

            // Progress Bar
            SizedBox(
              width: 200,
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: _loadingPercentage.clamp(0.0, 1.0),
                      backgroundColor: AppColors.getSurface(t),
                      color: primaryColor,
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Status Text
                  AnimatedBuilder(
                    animation: _textController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _textController.value,
                        child: Text(
                          _currentFeatureText,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: subtleColor,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 80),

            // Version
            Text(
              'v2.0',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: subtleColor.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
