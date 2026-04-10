import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class ChildDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> childData;

  const ChildDetailsScreen({super.key, required this.childData});

  @override
  State<ChildDetailsScreen> createState() => _ChildDetailsScreenState();
}

class _ChildDetailsScreenState extends State<ChildDetailsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      final childEmail = widget.childData['email'];
      final provider = Provider.of<AppProvider>(context, listen: false);
      final parentEmail = provider.userEmail;

      if (parentEmail == null) {
        throw Exception("Parent email not found");
      }

      // Fetch unified notifications for this specific child
      final notifs = await ApiService.getParentNotifications(parentEmail,
          childEmail: childEmail, limit: 100);

      if (mounted) {
        setState(() {
          _notifications = notifs ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _unlinkChild() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlink Account'),
        content: Text(
            'Are you sure you want to unlink ${widget.childData['name']}? You will no longer receive alerts or manage this account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unlink', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isLoading = true);
      final provider = Provider.of<AppProvider>(context, listen: false);
      if (provider.userEmail == null) return;

      await ApiService.unlinkChildAccount(
          provider.userEmail!, widget.childData['email']);

      if (mounted) {
        Navigator.pop(context, true); // Return true to refresh parent list
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unlink: $e')),
        );
      }
    }
  }

  /// Resolve profile_pic to a full URL (handles relative paths)
  String? _resolveProfilePic(String? pic) {
    return AppConstants.resolveProfilePic(pic);
  }

  Future<void> _pickAndUploadProfilePic() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isLoading = true);

      final file = File(image.path);
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${widget.childData['email']}.jpg';

      try {
        // Upload to Supabase Storage
        await Supabase.instance.client.storage
            .from('avatars')
            .upload(fileName, file)
            .timeout(const Duration(seconds: 10));

        // Get public URL
        final publicUrl = Supabase.instance.client.storage
            .from('avatars')
            .getPublicUrl(fileName);

        // Update devices table
        final targetEmail =
            widget.childData['email'] ?? widget.childData['user_email'];

        await Supabase.instance.client
            .from('devices')
            .update({
              'profile_pic_url': publicUrl,
            })
            .eq('user_email', targetEmail)
            .eq('device_type', 'pc')
            .timeout(const Duration(seconds: 5));

        setState(() {
          widget.childData['profile_pic'] = publicUrl;
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Profile picture updated successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to connect to Supabase: $e')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick picture: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Child Data
    final name = widget.childData['name'] ?? 'Unknown';
    final email = widget.childData['email'] ?? '';
    final profilePic = _resolveProfilePic(widget.childData['profile_pic']);
    final deviceName = widget.childData['device_name'] ??
        widget.childData['hostname'] ??
        'PC Device';
    final lastIp = widget.childData['last_ip'];
    final hostname = widget.childData['hostname'];
    final macAddress = widget.childData['mac_address'];
    final secretCode = widget.childData['secret_code'];
    final isMonitoring = widget.childData['is_monitoring'] ?? false;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(name),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedLinkSquare02,
                color: Colors.redAccent,
                size: 22),
            tooltip: 'Unlink Account',
            onPressed: _unlinkChild,
          )
        ],
      ),
      body: Column(
        children: [
          // Header Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        const Color(0xFF6366F1).withValues(alpha: 0.15),
                        const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                      ]
                    : [const Color(0xFFF5F3FF), const Color(0xFFEDE9FE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF6366F1).withValues(alpha: 0.2)
                    : const Color(0xFF6366F1).withValues(alpha: 0.05),
              ),
            ),
            child: Column(
              children: [
                // Profile picture with PC avatar overlay
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onTap: _pickAndUploadProfilePic,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                const Color(0xFF6366F1).withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 42,
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundImage: profilePic != null
                              ? NetworkImage(profilePic)
                              : null,
                          child: profilePic == null
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                )
                              : null,
                        ),
                      ),
                    ),
                    // Edit badge
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickAndUploadProfilePic,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // PC device badge
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF1B1B1B) : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                const Color(0xFF6366F1).withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const HugeIcon(
                          icon: HugeIcons.strokeRoundedComputerDesk01,
                          size: 16,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: 6),
                // Device name chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF6366F1).withValues(alpha: 0.1)
                        : const Color(0xFF6366F1).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HugeIcon(
                          icon: HugeIcons.strokeRoundedLaptopCheck,
                          size: 13,
                          color:
                              isDark ? Colors.white60 : Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        deviceName,
                        style: TextStyle(
                            color:
                                isDark ? Colors.white60 : Colors.grey.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                // IP & Hostname info chips
                if (lastIp != null ||
                    hostname != null ||
                    macAddress != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      if (hostname != null)
                        _buildInfoChip(
                          HugeIcons.strokeRoundedComputerDesk01,
                          hostname,
                          isDark,
                        ),
                      if (lastIp != null)
                        _buildInfoChip(
                          HugeIcons.strokeRoundedGlobalRefresh,
                          lastIp,
                          isDark,
                        ),
                      if (macAddress != null)
                        _buildInfoChip(
                          HugeIcons.strokeRoundedWifiConnected01,
                          macAddress,
                          isDark,
                        ),
                    ],
                  ),
                ],
                // Secret Code display
                if (secretCode != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF10B981).withValues(alpha: 0.1)
                          : const Color(0xFF10B981).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedLockKey,
                          size: 16,
                          color: const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Secret Code: ',
                          style: TextStyle(
                            color:
                                isDark ? Colors.white70 : Colors.grey.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          secretCode,
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatusChip(
                        'Monitoring',
                        isMonitoring ? 'Active' : 'Inactive',
                        isMonitoring ? Colors.green : Colors.orange,
                        isDark),
                    const SizedBox(width: 12),
                    _buildStatusChip(
                        'Alerts',
                        '${_notifications.where((n) => n['type'] == 'abuse').length}',
                        Colors.red,
                        isDark),
                  ],
                )
              ],
            ),
          ),

          // Timeline Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                HugeIcon(
                    icon: HugeIcons.strokeRoundedClock01,
                    color: theme.iconTheme.color?.withValues(alpha: 0.7) ??
                        Colors.grey,
                    size: 20),
                const SizedBox(width: 8),
                Text(
                  'Activity Feed',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowReloadHorizontal,
                      color: theme.iconTheme.color?.withValues(alpha: 0.5) ??
                          Colors.grey),
                  onPressed: _fetchNotifications,
                )
              ],
            ),
          ),

          // Timeline List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red)))
                    : _notifications.isEmpty
                        ? Center(
                            child: Text(
                              'No recent activity',
                              style: TextStyle(
                                  color: theme.disabledColor, fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _notifications.length,
                            itemBuilder: (context, index) {
                              final notif = _notifications[index];
                              final type = notif['type'] ?? 'system';

                              // Group similar notifications visually or by day could be a future enhancement
                              Widget card;
                              switch (type) {
                                case 'abuse':
                                  card = _buildAbuseCard(notif, isDark);
                                  break;
                                case 'auth':
                                  card = _buildAuthCard(
                                      notif, isDark); // Only Blue
                                  break;
                                case 'rotation':
                                  card = _buildAuthCard(notif,
                                      isDark); // Blue for Secret Code too
                                  break;
                                case 'system':
                                  // Check for Start/Stop events
                                  final label = (notif['label'] ?? '')
                                      .toString()
                                      .toLowerCase();
                                  final msg = (notif['sentence'] ?? '')
                                      .toString()
                                      .toLowerCase();
                                  final lowerLabel = label.toLowerCase();
                                  final lowerMsg = msg.toLowerCase();
                                  if (lowerLabel.contains('monitor') ||
                                      lowerMsg.contains('active') ||
                                      lowerMsg.contains('online') ||
                                      lowerMsg.contains('start') ||
                                      lowerMsg.contains('stop')) {
                                    if (lowerMsg.contains('stop') ||
                                        lowerMsg.contains('inactive') ||
                                        lowerMsg.contains('disconnect') ||
                                        lowerLabel.contains('stop')) {
                                      card = _buildSystemCard(notif, isDark,
                                          isStart: false); // Grey
                                    } else {
                                      card = _buildSystemCard(notif, isDark,
                                          isStart: true); // Green
                                    }
                                  } else {
                                    card = _buildGenericCard(notif, isDark);
                                  }
                                  break;
                                default:
                                  card = _buildGenericCard(notif, isDark);
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: card,
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET CARD TEMPLATES ---

  Widget _buildAbuseCard(Map<String, dynamic> notif, bool isDark) {
    final score = notif['score'] ?? 0.0;
    final label = notif['label'] ?? 'Abuse Detected';
    final sentence = notif['sentence'] ?? '';
    final time = notif['display_time'] ?? notif['timestamp'] ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2C1E26)
            : const Color(0xFFFEF2F2), // Dark Red tint or Light Red bg
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.redAccent.withValues(alpha: 0.3)
              : Colors.red.shade100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedAlert02,
                    color: Colors.red,
                    size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
              Text(
                time,
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '"$sentence"',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontStyle: FontStyle.italic,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          // Clean Confidence Bar
          Row(
            children: [
              Text('Confidence:',
                  style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.grey,
                      fontSize: 11)),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: score,
                    backgroundColor:
                        isDark ? Colors.white10 : Colors.red.shade50,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text('${(score * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 11)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildAuthCard(Map<String, dynamic> notif, bool isDark) {
    final label = notif['label'] ?? 'Authentication';
    final message = notif['sentence'] ?? '';
    final time = notif['display_time'] ?? notif['timestamp'] ?? '';

    // OTP Extraction
    final otpMatch = RegExp(r'\b\d{4,8}\b').firstMatch(message);
    final otp = otpMatch?.group(0);

    // Blue Scheme
    final color = Colors.blue;
    final bgColor = isDark ? const Color(0xFF1E2A38) : const Color(0xFFEFF6FF);
    final borderColor =
        isDark ? Colors.blue.withValues(alpha: 0.3) : Colors.blue.shade100;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(
                    icon: HugeIcons.strokeRoundedLockPassword,
                    color: color,
                    size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              Text(
                time,
                style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                    fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message.replaceAll(otp ?? '', '').trim(),
            style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87, fontSize: 13),
          ),
          if (otp != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: color.withValues(alpha: 0.3), width: 1),
              ),
              child: Center(
                child: SelectableText(
                  otp,
                  style: TextStyle(
                      color: color,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4),
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }

  // New System Card (Green for Start, Grey for Stop)
  Widget _buildSystemCard(Map<String, dynamic> notif, bool isDark,
      {required bool isStart}) {
    final label = notif['label'] ?? 'System';
    final message = notif['sentence'] ?? '';
    final time = notif['display_time'] ?? notif['timestamp'] ?? '';

    final color = isStart ? Colors.green : Colors.grey;
    final icon = isStart
        ? HugeIcons.strokeRoundedPlayCircle
        : HugeIcons.strokeRoundedStopCircle;

    final bgColor = isStart
        ? (isDark ? const Color(0xFF1B2E1E) : const Color(0xFFF0FDF4))
        : (isDark ? const Color(0xFF262626) : const Color(0xFFF3F4F6));

    final borderColor = isStart
        ? (isDark ? Colors.green.withValues(alpha: 0.3) : Colors.green.shade100)
        : (isDark ? Colors.grey.withValues(alpha: 0.3) : Colors.grey.shade300);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(icon: icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              Text(
                time,
                style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                    fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildGenericCard(Map<String, dynamic> notif, bool isDark) {
    final label = notif['label'] ?? 'System';
    final message = notif['sentence'] ?? '';
    final time = notif['display_time'] ?? notif['timestamp'] ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).cardColor
            : Colors.white, // Standard card
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2))
              ],
        border: isDark
            ? Border.all(color: Colors.white10)
            : Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(
              icon: HugeIcons.strokeRoundedNotificationCircle,
              color: isDark ? Colors.white54 : Colors.grey,
              size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color:
                            isDark ? Colors.white : const Color(0xFF1E293B))),
                const SizedBox(height: 2),
                Text(message,
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black54)),
              ],
            ),
          ),
          Text(time,
              style: TextStyle(
                  color: isDark ? Colors.white30 : Colors.grey.shade400,
                  fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildInfoChip(dynamic icon, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF6366F1).withValues(alpha: 0.1)
            : const Color(0xFF6366F1).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
              icon: icon,
              size: 13,
              color: isDark ? Colors.white60 : Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
                color: isDark ? Colors.white60 : Colors.grey.shade700,
                fontSize: 11,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(
      String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.1)
            : color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark
                ? color.withValues(alpha: 0.3)
                : color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey.shade700,
                fontSize: 11),
          ),
          Text(
            value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
