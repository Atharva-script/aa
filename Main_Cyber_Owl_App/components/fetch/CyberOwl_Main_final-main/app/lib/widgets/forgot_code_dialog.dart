import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

class ForgotSecretCodeDialog extends StatefulWidget {
  final String? initialEmail;
  final bool startAtOtp;

  const ForgotSecretCodeDialog({
    super.key,
    this.initialEmail,
    this.startAtOtp = false,
  });

  @override
  State<ForgotSecretCodeDialog> createState() => _ForgotSecretCodeDialogState();
}

class _ForgotSecretCodeDialogState extends State<ForgotSecretCodeDialog> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late int _step;
  bool _isLoading = false;
  bool _obscureSecretCode = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _step = widget.startAtOtp ? 2 : 1;
    if (widget.initialEmail != null) {
      _emailController.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newCodeController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    if (_emailController.text.isEmpty) {
      setState(() => _error = 'Please enter your email');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await AuthService.requestSecretCodeReset(_emailController.text.trim());
      setState(() {
        _step = 2;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _resetCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await AuthService.confirmSecretCodeReset(
        email: _emailController.text.trim(),
        otp: _otpController.text.trim(),
        newCode: _newCodeController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context, true); // Return true on success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Secret Code reset successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(FluentIcons.key_reset_24_regular, color: AppColors.primary),
          SizedBox(width: 10),
          Text('Reset Secret Code'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 300,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_step == 1) ...[
                  const Text(
                    'Enter your registered email to receive an OTP for resetting your secret code.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(FluentIcons.mail_24_regular),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _requestOtp(),
                  ),
                ] else ...[
                  const Text(
                    'Enter the 6-digit OTP sent to your email and your new secret code.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _otpController,
                    decoration: const InputDecoration(
                      labelText: 'OTP (6 Digits)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(FluentIcons.number_row_24_regular),
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _resetCode(),
                    validator: (v) =>
                        v?.length != 6 ? 'Enter valid 6-digit OTP' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _newCodeController,
                    obscureText: _obscureSecretCode,
                    decoration: InputDecoration(
                      labelText: 'New Secret Code',
                      border: const OutlineInputBorder(),
                      prefixIcon:
                          const Icon(FluentIcons.lock_closed_24_regular),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureSecretCode
                              ? FluentIcons.eye_off_24_regular
                              : FluentIcons.eye_24_regular,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureSecretCode = !_obscureSecretCode;
                          });
                        },
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _resetCode(),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Code required' : null,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (!_isLoading)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ElevatedButton(
          onPressed:
              _isLoading ? null : (_step == 1 ? _requestOtp : _resetCode),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Text(_step == 1 ? 'Send OTP' : 'Reset Code'),
        ),
      ],
    );
  }
}
