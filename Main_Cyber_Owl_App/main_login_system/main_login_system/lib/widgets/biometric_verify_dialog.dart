import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

class BiometricVerifyDialog extends StatefulWidget {
  final String email;

  const BiometricVerifyDialog({
    super.key,
    required this.email,
  });

  @override
  State<BiometricVerifyDialog> createState() => _BiometricVerifyDialogState();
}

class _BiometricVerifyDialogState extends State<BiometricVerifyDialog> {
  bool _isLoading = true;
  String? _error;
  Timer? _pollingTimer;
  int _secondsRemaining = 120;
  String? _requestId;

  @override
  void initState() {
    super.initState();
    _startVerification();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _startVerification() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Create Request
      final reqResponse = await AuthService.createVerifyRequest(
        email: widget.email,
        deviceInfo: 'PC App (Windows)',
      );

      _requestId = reqResponse['request_id'];

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      // 2. Start Polling
      _startPolling();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _secondsRemaining--;
      });

      if (_secondsRemaining <= 0) {
        timer.cancel();
        setState(() {
          _error = 'Verification timed out. Please try again.';
        });
        return;
      }

      try {
        final data = await AuthService.checkRequestStatus(_requestId!);
        final status = data['status'];

        if (status == 'approved') {
          timer.cancel();
          if (mounted) {
            // Return the successful auth data
            Navigator.pop(context, {
              'success': true,
              'access_token': data['access_token'],
              'user': data['user'],
            });
          }
        } else if (status == 'rejected') {
          timer.cancel();
          if (mounted) {
            setState(() {
              _error = 'Verification request was rejected.';
            });
          }
        }
      } catch (e) {
        // Ignore network errors during polling, just keep trying until timeout
        debugPrint('Polling error: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isLoading && _error != null,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            if (_error != null) ...[
              const Icon(FluentIcons.warning_24_regular,
                  size: 64, color: AppColors.accentRed),
              const SizedBox(height: 24),
              const Text(
                'Verification Failed',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _startVerification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Try Again',
                    style: TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, {'success': false}),
                child: const Text('Cancel'),
              ),
            ] else if (_isLoading) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              const Text('Starting Verification...'),
            ] else ...[
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      value: _secondsRemaining / 120,
                      strokeWidth: 3,
                      color: AppColors.primary,
                      backgroundColor: Colors.grey[200],
                    ),
                  ),
                  const Icon(FluentIcons.phone_link_setup_24_regular,
                      size: 32, color: AppColors.primary),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Check your Mobile',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'A secure verification request has been sent to your Cyber Owl mobile app.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              Text(
                'Expires in $_secondsRemaining seconds',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pop(context, {'success': false}),
                child: const Text('Cancel Request'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
