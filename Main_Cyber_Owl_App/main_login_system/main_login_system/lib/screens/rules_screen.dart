import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/theme_manager.dart';
import '../services/abuse_detection_service.dart';

class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key});

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  final AbuseDetectionService _detectionService = AbuseDetectionService();
  List<Map<String, dynamic>> _rules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    var rules = await _detectionService.getRules();

    // If backend has no rules, show these default UI-only rules (Requested: Don't save anywhere)
    if (rules.isEmpty) {
      rules = [
        {
          'id': 'profanity',
          'title': 'Profanity Filter',
          'description': 'Blocks extreme abusive language',
          'isEnabled': true,
          'category': 'Content Filtering'
        },
        {
          'id': 'nudity',
          'title': 'Sensitive Content',
          'description': 'Detects and flags nudity or restricted media',
          'isEnabled': true,
          'category': 'Content Filtering'
        },
        {
          'id': 'spam',
          'title': 'Spam Protection',
          'description': 'Identifies repetitive or bot-like messages',
          'isEnabled': false,
          'category': 'Content Filtering'
        },
        {
          'id': 'email',
          'title': 'Email Notifications',
          'description': 'Send alerts to parent email on high-risk detections',
          'isEnabled': true,
          'category': 'System Alerts'
        },
        {
          'id': 'popups',
          'title': 'Desktop Popups',
          'description': 'Show immediate warnings on the monitoring device',
          'isEnabled': true,
          'category': 'System Alerts'
        },
      ];
    }

    if (mounted) {
      setState(() {
        _rules = rules;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleRule(String ruleId, bool isEnabled) async {
    // Optimistic update
    setState(() {
      final index = _rules.indexWhere((r) => r['id'] == ruleId);
      if (index != -1) {
        _rules[index]['isEnabled'] = isEnabled;
      }
    });

    // Check if this is a default/mock rule or a user-added local rule
    // If so, we skip the backend call to respect "don't save anywhere" (and avoid errors)
    final isLocalRule =
        ['profanity', 'nudity', 'spam', 'email', 'popups'].contains(ruleId) ||
            ruleId.startsWith('rule_');

    if (isLocalRule) return;

    final success = await _detectionService.updateRule(ruleId, isEnabled);
    if (!success && mounted) {
      _loadRules(); // Revert on failure
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update rule on server')),
      );
    }
  }

  void _addRule(String title, String description) {
    setState(() {
      _rules.add({
        'id': 'rule_${DateTime.now().millisecondsSinceEpoch}',
        'title': title,
        'description': description,
        'isEnabled': true,
        'category': 'Custom Rules',
      });
    });
  }

  Future<void> _showAddRuleDialog() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Monitoring Rule'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                  labelText: 'Rule Title', hintText: 'e.g., Keyword Filter'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'What does this rule do?'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                _addRule(titleController.text, descController.text);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add Rule'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeManager,
      builder: (context, _) {
        final t = themeManager.themeValue;
        final backgroundColor = AppColors.getBackground(t);
        final textColor = AppColors.getTextPrimary(t);
        final secondaryTextColor = AppColors.getTextSecondary(t);
        final surfaceColor = AppColors.getSurface(t);
        final dividerColor = AppColors.getDivider(t);

        return Scaffold(
          backgroundColor: backgroundColor,
          floatingActionButton: FloatingActionButton(
            onPressed: _showAddRuleDialog,
            backgroundColor: AppColors.primary,
            child: const Icon(FluentIcons.add_24_regular, color: Colors.white),
          ),
          body: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Monitoring Rules',
                    style: AppTextStyles.h1.copyWith(color: textColor)),
                const SizedBox(height: 8),
                Text('Define and manage security detection policies',
                    style: AppTextStyles.subBody
                        .copyWith(color: secondaryTextColor)),
                const SizedBox(height: 32),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _rules.isEmpty
                          ? Center(
                              child: Text("No rules found",
                                  style: TextStyle(color: textColor)))
                          : SingleChildScrollView(
                              child: Column(
                                children: _buildRuleGroups(
                                    textColor,
                                    surfaceColor,
                                    dividerColor,
                                    secondaryTextColor),
                              ),
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildRuleGroups(Color textColor, Color surfaceColor,
      Color dividerColor, Color secondaryTextColor) {
    // Group rules by category
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (var rule in _rules) {
      final cat = rule['category'] ?? 'General';
      groups.putIfAbsent(cat, () => []).add(rule);
    }

    return groups.entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24.0),
        child: _buildRuleGroup(
          entry.key,
          entry.value.map((rule) {
            return _buildRuleItem(
              rule['id'],
              rule['title'],
              rule['description'],
              rule['isEnabled'],
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
            );
          }).toList(),
          textColor: textColor,
          surfaceColor: surfaceColor,
          dividerColor: dividerColor,
        ),
      );
    }).toList();
  }

  Widget _buildRuleGroup(String title, List<Widget> rules,
      {required Color textColor,
      required Color surfaceColor,
      required Color dividerColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: dividerColor),
          ),
          child: Column(
            children: rules,
          ),
        ),
      ],
    );
  }

  Widget _buildRuleItem(
      String id, String title, String description, bool isEnabled,
      {required Color textColor, required Color secondaryTextColor}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(title,
          style: AppTextStyles.body
              .copyWith(fontWeight: FontWeight.w600, color: textColor)),
      subtitle: Text(description,
          style: AppTextStyles.subBody.copyWith(color: secondaryTextColor)),
      trailing: Switch(
        value: isEnabled,
        onChanged: (val) => _toggleRule(id, val),
        activeTrackColor: AppColors.primary,
      ),
    );
  }
}
