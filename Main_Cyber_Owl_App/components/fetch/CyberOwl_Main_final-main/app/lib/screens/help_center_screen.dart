import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/theme_manager.dart';
import '../widgets/top_bar.dart';

class HelpCenterScreen extends StatelessWidget {
  final bool isExpanded;
  const HelpCenterScreen({super.key, this.isExpanded = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeManager,
      builder: (context, _) {
        final t = themeManager.themeValue;

        final backgroundColor = AppColors.getBackground(t);
        final textColor = AppColors.getTextPrimary(t);
        final surfaceColor = AppColors.getSurface(t);

        return Container(
          color: backgroundColor,
          child: Column(
            children: [
              TopBar(isExpanded: isExpanded),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Help Center',
                          style: AppTextStyles.h1.copyWith(color: textColor)),
                      const SizedBox(height: 8),
                      const Text(
                          'Find answers, tutorials, and support for CYBER OWL.',
                          style: AppTextStyles.subBody),
                      const SizedBox(height: 40),
                      _buildSearchBox(t),
                      const SizedBox(height: 40),
                      _buildCategoriesGrid(t, surfaceColor),
                      const SizedBox(height: 40),
                      Text('Frequently Asked Questions',
                          style: AppTextStyles.h2.copyWith(color: textColor)),
                      const SizedBox(height: 20),
                      _buildFaqList(t, surfaceColor),
                      const SizedBox(height: 40),
                      _buildContactSupport(t, surfaceColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBox(double t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.getSurface(t),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.getDivider(t).withValues(alpha: 0.5)),
      ),
      child: const TextField(
        decoration: InputDecoration(
          hintText: 'Search for articles, guides...',
          border: InputBorder.none,
          icon: Icon(FluentIcons.search_24_regular),
        ),
      ),
    );
  }

  Widget _buildCategoriesGrid(double t, Color surfaceColor) {
    final categories = [
      {
        'icon': FluentIcons.rocket_24_regular,
        'title': 'Getting Started',
        'count': '12 articles'
      },
      {
        'icon': FluentIcons.shield_24_regular,
        'title': 'Privacy & Safety',
        'count': '8 articles'
      },
      {
        'icon': FluentIcons.settings_24_regular,
        'title': 'Account Settings',
        'count': '15 articles'
      },
      {
        'icon': FluentIcons.bug_24_regular,
        'title': 'Troubleshooting',
        'count': '10 articles'
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.getDivider(t).withValues(alpha: 0.5)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(cat['icon'] as IconData, color: AppColors.primary, size: 32),
              const SizedBox(height: 12),
              Text(cat['title'] as String,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(cat['count'] as String,
                  style: AppTextStyles.subBody.copyWith(fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFaqList(double t, Color surfaceColor) {
    final faqs = [
      {
        'q': 'How does CYBER OWL detect abuse?',
        'a':
            'We use advanced BERT models trained on millions of examples of toxic language to classify speech and text in real-time.'
      },
      {
        'q': 'Is my data stored permanently?',
        'a':
            'We only store data that identifies threats. Normal interactions are analyzed in-memory and discarded immediately.'
      },
      {
        'q': 'What happens when a threat is detected?',
        'a':
            'An email alert is immediately sent to the configured parent/guardian email with details and confidence scores.'
      },
    ];

    return Column(
      children: faqs
          .map((faq) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.getDivider(t).withValues(alpha: 0.5)),
                ),
                child: ExpansionTile(
                  title: Text(faq['q']!,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(faq['a']!, style: AppTextStyles.body),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildContactSupport(double t, Color surfaceColor) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Still need help?',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text(
                    'Our support team is available 24/7 to assist you with any issues.',
                    style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Contact Us',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
