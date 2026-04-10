import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../providers/app_provider.dart';
import '../services/biometric_service.dart';
import '../utils/constants.dart';
import 'home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;
import 'login_screen.dart';

class BiometricAuthScreen extends StatefulWidget {
  const BiometricAuthScreen({super.key});

  @override
  State<BiometricAuthScreen> createState() => _BiometricAuthScreenState();
}

class _BiometricAuthScreenState extends State<BiometricAuthScreen> {
  final _biometricService = BiometricService();
  bool _isAuthenticating = false;
  String _message = 'App is locked. Please authenticate.';

  @override
  void initState() {
    super.initState();
    // Prompt immediately on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _promptBiometrics();
    });
  }

  Future<void> _promptBiometrics() async {
    setState(() {
      _isAuthenticating = true;
      _message = 'Authenticating...';
    });

    final isAvailable = await _biometricService.isBiometricAvailable();
    if (!isAvailable) {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _message = 'Biometrics not available. Please login again.';
        });
        // Send back to login
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            context.read<AppProvider>().logout();
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const LoginScreen()));
          }
        });
      }
      return;
    }

    final success = await _biometricService.authenticate(
        localizedReason: 'Please authenticate to access CyberOwl');

    if (success) {
      await _rotateBiometricValue();
    } else {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _message = 'Authentication failed. Please try again.';
        });
      }
    }
  }

  Future<void> _rotateBiometricValue() async {
    try {
      final provider = context.read<AppProvider>();
      final email = provider.userEmail;

      if (email != null) {
        // Generate a new 6-digit rotation value
        final newRotationValue =
            List.generate(6, (_) => math.Random().nextInt(10)).join();

        try {
          // Update Supabase
          await Supabase.instance.client
              .from('users')
              .update({
                'biometric_rotation_value': newRotationValue,
                'biometric_last_rotated': DateTime.now().toIso8601String()
              })
              .eq('email', email)
              .timeout(const Duration(seconds: 5));

          debugPrint("Biometric rotation value updated for $email");
        } catch (e) {
          debugPrint(
              "Failed to update biometric rotation value in Supabase (falling back to local): $e");
          // Proceed anyway so the user isn't locked out of the app
        }
      }

      // Clear pending state
      provider.completeBiometricAuth();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      debugPrint("Failed to rotate biometric value: $e");
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _message = 'System configuration error. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FluentIcons.fingerprint_48_regular,
                size: 80,
                color: AppColors.primary,
              ),
              const SizedBox(height: 32),
              Text(
                'Security Check',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 48),
              if (_isAuthenticating)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: _promptBiometrics,
                  icon: const Icon(FluentIcons.lock_closed_24_regular),
                  label: const Text('Unlock App'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              const SizedBox(height: 24),
              if (!_isAuthenticating)
                TextButton(
                  onPressed: () {
                    context.read<AppProvider>().logout();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child:
                      const Text('Logout', style: TextStyle(color: Colors.red)),
                )
            ],
          ),
        ),
      ),
    );
  }
}
