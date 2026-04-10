import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Reports Section', style: AppTextStyles.h1),
    );
  }
}
