import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/theme_manager.dart';
import '../services/auth_service.dart';
import '../services/abuse_detection_service.dart';
import '../widgets/top_bar.dart';

class HistoryScreen extends StatefulWidget {
  final bool isExpanded;
  const HistoryScreen({super.key, this.isExpanded = false});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final AbuseDetectionService _detectionService = AbuseDetectionService();
  String _filterType = 'all';
  String _searchQuery = '';
  List<AbuseAlert> _allAlerts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final user = await AuthService.getLocalUser();
      final deviceId = user?['device_name'];

      final alerts =
          await _detectionService.getAlerts(limit: 1000, deviceId: deviceId);
      setState(() {
        _allAlerts = alerts;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<AbuseAlert> get _filteredAlerts {
    if (_allAlerts.isEmpty) return [];

    return _allAlerts
        .where((alert) {
          final query = _searchQuery.toLowerCase();
          final matchesSearch = query.isEmpty ||
              (alert.sentence?.toLowerCase().contains(query) ?? false) ||
              (alert.label.toLowerCase().contains(query));

          final filter = _filterType.toLowerCase();
          bool matchesType = filter == 'all';
          if (!matchesType) {
            // Match by type field OR check label for 'nudity'
            final alertType = alert.type.toLowerCase();
            final alertLabel = alert.label.toLowerCase();

            if (filter == 'abuse') {
              matchesType = alertType == 'abuse' && alertLabel != 'nudity';
            } else if (filter == 'nudity') {
              matchesType = alertType == 'nudity' || alertLabel == 'nudity';
            }
          }

          return matchesSearch && matchesType;
        })
        .toList()
        .reversed
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeManager,
      builder: (context, _) {
        final t = themeManager.themeValue;
        final isDark = themeManager.isDark;
        final backgroundColor = AppColors.getBackground(t);
        final surfaceColor = AppColors.getSurface(t);

        return Container(
          color: backgroundColor,
          child: Column(
            children: [
              TopBar(isExpanded: widget.isExpanded),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(t, isDark),
                      const SizedBox(height: 24),
                      _buildFilters(t, isDark),
                      const SizedBox(height: 16),
                      Expanded(
                        child: StreamBuilder<List<AbuseAlert>>(
                          stream: _detectionService.alertsStream,
                          builder: (context, snapshot) {
                            // If stream has data, update our local list
                            if (snapshot.hasData) {
                              _allAlerts = snapshot.data!;
                            }

                            // Still show loading only if we have NO data at all
                            if (_allAlerts.isEmpty && _isLoading) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            final filtered = _filteredAlerts;
                            if (filtered.isEmpty) {
                              return _buildEmptyState(t, isDark);
                            }

                            return _buildAlertsTable(
                                t, isDark, surfaceColor, filtered);
                          },
                        ),
                      ),
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

  Widget _buildEmptyState(double t, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FluentIcons.history_24_regular,
              size: 64,
              color: AppColors.getTextSecondary(t).withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text("No records found matching your filters",
              style: AppTextStyles.body
                  .copyWith(color: AppColors.getTextSecondary(t))),
        ],
      ),
    );
  }

  Widget _buildHeader(double t, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Analysis History',
                style: AppTextStyles.h1
                    .copyWith(color: AppColors.getTextPrimary(t))),
            const Text('Comprehensive log of all detected incidents',
                style: AppTextStyles.subBody),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Clear History?'),
                content: const Text(
                    'This will permanently delete all logs from the database.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Clear All',
                          style: TextStyle(color: Colors.red))),
                ],
              ),
            );
            if (confirm == true) {
              await _detectionService.clearAlerts();
              _fetchHistory();
            }
          },
          icon: const Icon(FluentIcons.delete_24_regular, size: 18),
          label: const Text('Clear All Logs'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentRed.withValues(alpha: 0.1),
            foregroundColor: AppColors.accentRed,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters(double t, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.getSurface(t),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.getDivider(t).withValues(alpha: 0.5)),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: const InputDecoration(
                hintText: 'Search incidents by content...',
                border: InputBorder.none,
                icon: Icon(FluentIcons.search_24_regular, size: 20),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        _buildFilterChip('All', 'all', t, isDark),
        const SizedBox(width: 8),
        _buildFilterChip('Abuse', 'abuse', t, isDark),
        const SizedBox(width: 8),
        _buildFilterChip('Nudity', 'nudity', t, isDark),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value, double t, bool isDark) {
    final isSelected = _filterType == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _filterType = value);
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.getTextSecondary(t),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildAlertsTable(
      double t, bool isDark, Color surfaceColor, List<AbuseAlert> filtered) {
    // We already have filtered data passed in now

    final textColor = AppColors.getTextPrimary(t);
    final secondaryTextColor = AppColors.getTextSecondary(t);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.getDivider(t).withValues(alpha: 0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          child: DataTable(
            showCheckboxColumn: false,
            columns: [
              DataColumn(
                  label: Text('Timestamp',
                      style: TextStyle(
                          color: textColor, fontWeight: FontWeight.w600))),
              DataColumn(
                  label: Text('Type',
                      style: TextStyle(
                          color: textColor, fontWeight: FontWeight.w600))),
              DataColumn(
                  label: Text('Context',
                      style: TextStyle(
                          color: textColor, fontWeight: FontWeight.w600))),
              DataColumn(
                  label: Text('Source',
                      style: TextStyle(
                          color: textColor, fontWeight: FontWeight.w600))),
              DataColumn(
                  label: Text('Confidence',
                      style: TextStyle(
                          color: textColor, fontWeight: FontWeight.w600))),
            ],
            rows: filtered.map((alert) {
              Color color;
              String label = alert.label.toUpperCase();

              final type = alert.type.toLowerCase();
              final alertLabel = alert.label.toLowerCase();

              if (type == 'auth' || type == 'rotation') {
                color = AppColors.accentBlue;
                label = type == 'auth' ? 'SECURITY' : 'ROUTATION';
              } else if (type == 'system') {
                if (alertLabel.contains('start')) {
                  color = AppColors.accentGreen;
                  label = 'MONITORING START';
                } else if (alertLabel.contains('stop')) {
                  color = Colors.grey;
                  label = 'MONITORING STOP';
                } else {
                  color = AppColors.accentBlue;
                }
              } else {
                // Default to Red for detections (Abuse/Nudity)
                color = alert.label == 'nudity'
                    ? AppColors.accentPurple
                    : AppColors.accentRed;
              }

              return DataRow(
                onSelectChanged: (_) {}, // Could show detail dialog
                cells: [
                  DataCell(Text(alert.timestamp,
                      style: TextStyle(color: textColor, fontSize: 13))),
                  DataCell(Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(label,
                        style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  )),
                  DataCell(SizedBox(
                    width: 300,
                    child: Text(alert.sentence ?? 'System Detection',
                        style: TextStyle(color: textColor, fontSize: 14),
                        overflow: TextOverflow.ellipsis),
                  )),
                  DataCell(Text(alert.source,
                      style:
                          TextStyle(color: secondaryTextColor, fontSize: 13))),
                  DataCell(Text('${(alert.score * 100).toInt()}%',
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.bold))),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
