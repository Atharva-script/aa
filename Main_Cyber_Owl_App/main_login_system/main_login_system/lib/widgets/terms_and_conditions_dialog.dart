import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/theme_manager.dart';

class TermsAndConditionsDialog extends StatefulWidget {
  const TermsAndConditionsDialog({super.key});

  @override
  State<TermsAndConditionsDialog> createState() =>
      _TermsAndConditionsDialogState();
}

class _TermsAndConditionsDialogState extends State<TermsAndConditionsDialog> {
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;

  bool get _canProceed => _acceptedTerms && _acceptedPrivacy;

  @override
  Widget build(BuildContext context) {
    final t = themeManager.themeValue;
    final textColor = AppColors.getTextPrimary(t);
    final secondaryTextColor = AppColors.getTextSecondary(t);
    final surfaceColor = AppColors.getSurface(t);

    return AlertDialog(
      backgroundColor: surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Terms & Privacy Policy',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      content: SizedBox(
        width: 600, // Wide enough for professional look
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Scrollable Content
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 400),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: AppColors.getBorder(t).withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.getBackground(t), // Interpolated background
                ),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('1. Introduction', textColor),
                        _buildText(
                            'Welcome to Cyber Owl. These terms govern your use of our child safety monitoring application. By creating an account, you agree to these terms.',
                            secondaryTextColor),
                        const SizedBox(height: 16),
                        _buildSectionHeader(
                            '2. Data Collection & Monitoring', textColor),
                        _buildText(
                            'Cyber Owl is designed to protect users by monitoring key digital activities. We capture the following data:',
                            secondaryTextColor),
                        _buildBulletPoint(
                            'Screen Content: We capture periodic screenshots to detect nudity, violence, or sensitive content using AI analysis.',
                            secondaryTextColor),
                        _buildBulletPoint(
                            'Audio Monitoring: Real-time microphone analysis is used to detect bullying, threats, or distress signals.',
                            secondaryTextColor),
                        _buildBulletPoint(
                            'Keystroke & Text: We analyze typed text and clipboard content for harmful keywords or predatory behavior.',
                            secondaryTextColor),
                        _buildBulletPoint(
                            'System Info: We access running processes to identify usage of blacklisted applications.',
                            secondaryTextColor),
                        const SizedBox(height: 16),
                        _buildSectionHeader('3. Privacy & Control', textColor),
                        _buildText(
                            'Your privacy and trust are paramount. Please note:',
                            secondaryTextColor),
                        _buildBulletPoint(
                            'Data Ownership: All monitored data belongs to the account holder (Parent/Guardian).',
                            secondaryTextColor),
                        _buildBulletPoint(
                            'Encryption: Sensitive data is encrypted in transit and at rest.',
                            secondaryTextColor),
                        _buildBulletPoint(
                            'No Third-Party Sales: We do NOT sell your personal data or monitoring logs to third parties.',
                            secondaryTextColor),
                        const SizedBox(height: 16),
                        _buildSectionHeader(
                            '4. User Responsibilities', textColor),
                        _buildText(
                            'You acknowledge that you have the legal authority (e.g., as a parent or guardian) to install this software on the target device. Unauthorized use for spying on adults is strictly prohibited.',
                            secondaryTextColor),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Checkboxes
            CheckboxListTile(
              value: _acceptedTerms,
              onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
              title: Text(
                'I accept the Terms and Conditions',
                style: TextStyle(color: textColor, fontSize: 14),
              ),
              activeColor: AppColors.primary,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              value: _acceptedPrivacy,
              onChanged: (v) => setState(() => _acceptedPrivacy = v ?? false),
              title: Text(
                'I accept the Privacy Policy and consent to data monitoring',
                style: TextStyle(color: textColor, fontSize: 14),
              ),
              activeColor: AppColors.primary,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancel',
              style: TextStyle(color: AppColors.getTextSecondary(t))),
        ),
        ElevatedButton(
          onPressed: _canProceed ? () => Navigator.of(context).pop(true) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.3),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('Agree & Register'),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildText(String text, Color color) {
    return Text(
      text,
      style: TextStyle(color: color, fontSize: 13, height: 1.5),
    );
  }

  Widget _buildBulletPoint(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ',
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
