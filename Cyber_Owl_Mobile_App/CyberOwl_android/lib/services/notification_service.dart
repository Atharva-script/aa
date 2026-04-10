import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // Notification Channel Details
  static const String _channelId = 'cyberowl_alerts';
  static const String _channelName = 'CyberOwl Alerts';
  static const String _channelDescription =
      'Detection alerts from CyberOwl monitoring';

  // System Notification Channel (auth, monitoring start/stop)
  static const String _systemChannelId = 'cyberowl_system';
  static const String _systemChannelName = 'CyberOwl System';
  static const String _systemChannelDescription =
      'System notifications for monitoring and authentication events';

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Android initialization
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    await _createNotificationChannel();

    _isInitialized = true;
    debugPrint('NotificationService initialized');
  }

  Future<void> _createNotificationChannel() async {
    const alertChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    const systemChannel = AndroidNotificationChannel(
      _systemChannelId,
      _systemChannelName,
      description: _systemChannelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(alertChannel);
    await androidPlugin?.createNotificationChannel(systemChannel);
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Navigate to alerts screen or handle tap
  }

  // Show detection alert notification
  Future<void> showDetectionAlert({
    required String title,
    required String body,
    String? payload,
    bool isHighPriority = false,
    String notificationType = 'alert', // alert, auth, rotation, system
  }) async {
    // Type-based colors for notification accent
    Color accentColor;
    switch (notificationType) {
      case 'auth':
        accentColor = const Color(0xFF3B82F6); // Blue for password/auth
        break;
      case 'rotation':
        accentColor = const Color(0xFF8B5CF6); // Purple for secret code
        break;
      case 'system':
        accentColor = const Color(0xFF10B981); // Green for system
        break;
      case 'alert':
      default:
        accentColor = const Color(0xFFEF4444); // Red for abuse/alert
        break;
    }

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: isHighPriority ? Importance.max : Importance.high,
      priority: isHighPriority ? Priority.max : Priority.high,
      ticker: 'Detection Alert',
      icon: '@mipmap/ic_launcher',
      color: accentColor,
      enableVibration: true,
      playSound: true,
      styleInformation: BigTextStyleInformation(body),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  // Show monitoring status notification
  Future<void> showStatusNotification({
    required String title,
    required String body,
    bool ongoing = false,
    String notificationType = 'system', // system, success, warning, info
  }) async {
    // Type-based colors
    Color accentColor;
    switch (notificationType) {
      case 'success':
        accentColor = const Color(0xFF10B981); // Green
        break;
      case 'warning':
        accentColor = const Color(0xFFF59E0B); // Amber
        break;
      case 'error':
        accentColor = const Color(0xFFEF4444); // Red
        break;
      case 'info':
        accentColor = const Color(0xFF3B82F6); // Blue
        break;
      case 'system':
      default:
        accentColor = const Color(0xFF6366F1); // Indigo
        break;
    }

    final androidDetails = AndroidNotificationDetails(
      _systemChannelId,
      _systemChannelName,
      channelDescription: _systemChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: ongoing,
      autoCancel: !ongoing,
      icon: '@mipmap/ic_launcher',
      color: accentColor,
      enableVibration: true,
      playSound: true,
      ticker: 'CyberOwl Status',
      styleInformation: BigTextStyleInformation(body),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
    );
  }

  // Cancel status notification
  Future<void> cancelStatusNotification() async {
    await _notifications.cancel(0);
  }

  // Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  // Request notification permissions
  Future<bool> requestPermissions() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    return true;
  }
}
