import 'dart:async';
import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wake_on_lan/wake_on_lan.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/biometric_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constants.dart';
import '../services/server_discovery_service.dart';
import '../services/socket_service.dart';
import '../services/device_info_service.dart';
import 'dart:convert'; // Added for JSON encoding/decoding

class AppProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final NotificationService _notifications = NotificationService();
  final BiometricService _biometricService = BiometricService();
  final SocketService _socketService = SocketService();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // Server client ID for authentication
    serverClientId:
        '691983497226-ivbclati5704qgd2pnbsslh7inp7vic2.apps.googleusercontent.com',
  );

  // Storage
  final _storage = const FlutterSecureStorage();

  Future<void> _safeWrite(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint("SecureStorage Write Error: $e");
      // If key mismatch, try deleting and re-writing
      if (e.toString().contains('Key mismatch') ||
          e.toString().contains('Algorithm changed')) {
        await _storage.deleteAll();
        await _storage.write(key: key, value: value);
      }
    }
  }

  Future<String?> _safeRead(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint("SecureStorage Read Error: $e");
      if (e.toString().contains('Key mismatch') ||
          e.toString().contains('Algorithm changed')) {
        await _storage.deleteAll();
      }
      return null;
    }
  }

  // State
  bool _isLoading = false;
  String? _errorMessage;
  bool _isConnected = false;
  bool _isMonitoring = false;
  Map<String, dynamic>? _discoveredServer; // Store full discovery info
  bool _isPcAppOnline = false;
  bool _laptopOnline = false;
  bool _isLaunchingPcApp = false;

  // Per-child launch state tracking (for independent wake-up calls)
  final Map<String, bool> _childLaunchingState = {};

  // Monitoring Data

  final String _laptopHostname = "Unknown";
  final String _laptopIp = "Unknown";
  final int _laptopUptimeSeconds = 0;
  int _uptimeSeconds = 0;
  DateTime? _lastSeenTime;
  bool _wasLaptopOnline = false;

  // Alerts
  // Alerts
  List<Map<String, dynamic>> _alerts = [];
  List<Map<String, dynamic>> _parentAlerts =
      []; // [NEW] Link alerts from children
  List<Map<String, dynamic>> _children = []; // [NEW] Linked children (PCs)
  int _totalAlerts = 0;
  int _criticalAlerts = 0;
  int _previousAlertCount = 0;

  // Analytics
  Map<String, dynamic>? _analytics;

  // User Info
  String? _userName;
  String? _userPhotoUrl;
  bool _biometricEnabled = false;
  bool _isPendingBiometric = false;

  // Multi-Device
  String? _selectedChildId; // ID (Email) of the currently selected child
  int _laptopOfflineCount = 0; // [NEW] Track consecutive polling failures

  // Monitoring Preferences
  bool _audioMonitoringEnabled = true;
  bool _screenMonitoringEnabled = true;
  bool _pushNotificationsEnabled = true;

  List<Map<String, dynamic>> _pendingRequests = [];

  Timer? _statusTimer;
  Timer? _alertsTimer;
  Timer? _laptopStatusTimer;
  Timer? _requestsTimer;
  Timer? _parentDataTimer;

  // Settings
  ThemeMode _themeMode = ThemeMode.system;

  // Google Login - Step 1: Sign In with Google
  Future<bool> signInWithGoogleStep1() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (Platform.isWindows) {
        // [MODIFIED] Removed Mock Login to force real auth implementation or prevent bypass
        // For now, we fall through to standard sign in or show error if not supported
        // await Future.delayed(const Duration(seconds: 1));
        // _userName = "Muhammad Saqlain (Admin)";
        // ...

        // Try real sign in (if supported) or throw
        try {
          final googleUser = await _googleSignIn.signIn();
          if (googleUser != null) {
            _userName = googleUser.displayName;
            _userPhotoUrl = googleUser.photoUrl;
          }
        } catch (e) {
          _errorMessage =
              "Google Sign-In not supported on Windows yet. Please use Mobile.";
          _isLoading = false;
          notifyListeners();
          return false;
        }
      } else {
        // Real Google Sign In
        GoogleSignInAccount? googleUser;
        try {
          googleUser = await _googleSignIn.signIn();
        } catch (signInError) {
          _errorMessage =
              'Google Sign-In error: ${signInError.toString().replaceAll('PlatformException', 'Error')}';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        if (googleUser == null) {
          _errorMessage = 'Sign-in cancelled';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        _userName = googleUser.displayName;
        _userPhotoUrl = googleUser.photoUrl;
      }

      _isLoading = false;
      notifyListeners();
      return true; // Step 1 Success
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Google Login - Step 2: Authenticate with Backend
  Future<bool> signInWithGoogleStep2(String secretCode) async {
    _isLoading = true;
    notifyListeners();

    try {
      String? email;
      String? googleId;
      String? displayName;
      String? photoUrl;
      String? idToken;
      String? accessToken;

      if (Platform.isWindows) {
        // [MODIFIED] Removed Mock Credentials
        // email = "naikmuhammadsaqlain@gmail.com";
        // ...

        // Use actual signed in user from Step 1 (if we enabled it)
        final googleUser = _googleSignIn.currentUser;
        if (googleUser == null) {
          _errorMessage = "Google user not found. Please sign in again.";
          _isLoading = false;
          notifyListeners();
          return false;
        }
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        idToken = googleAuth.idToken;
        accessToken = googleAuth.accessToken;
        email = googleUser.email;
        googleId = googleUser.id;
        displayName = googleUser.displayName;
        photoUrl = googleUser.photoUrl;
      } else {
        final googleUser = _googleSignIn.currentUser;
        if (googleUser == null) {
          _errorMessage = "Google user not found. Please sign in again.";
          _isLoading = false;
          notifyListeners();
          return false;
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        idToken = googleAuth.idToken;
        accessToken = googleAuth.accessToken;

        email = googleUser.email;
        googleId = googleUser.id;
        displayName = googleUser.displayName;
        photoUrl = googleUser.photoUrl;
      }

      final result = await _api.googleLogin(
        email: email,
        googleId: googleId,
        idToken: idToken,
        accessToken: accessToken,
        name: displayName,
        photoUrl: photoUrl,
        secretCode: secretCode, // Pass secret code
      );

      if (result['success']) {
        await getProfile(); // Fetch updated profile data

        // Save Credentials FIRST (before biometric check) so they persist
        if (email.isNotEmpty) {
          await _safeWrite(AppConstants.emailKey, email);
          if (secretCode.isNotEmpty) {
            await _safeWrite('secret_code', secretCode);
          }
          // Save auth token for persistence
          if (_api.authToken != null) {
            await _safeWrite(AppConstants.tokenKey, _api.authToken!);
          }
        }

        // Start polling immediately so verification requests can be received
        await _startPolling();

        if (_biometricEnabled) {
          _isPendingBiometric = true;
          _isLoading = false;
          notifyListeners();
          return true;
        }

        // Update device telemetry in background
        DeviceInfoService.updateDeviceTelemetry(email).ignore();

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['error'];
        if (!Platform.isWindows) {
          await _googleSignIn.signOut();
        }
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Getters
  bool get isAuthenticated => _api.isAuthenticated;
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  bool get isMonitoring => _isMonitoring;
  int get uptimeSeconds => _uptimeSeconds;
  String? get errorMessage => _errorMessage;
  int get totalAlerts => _totalAlerts;
  int get criticalAlerts => _criticalAlerts;

  List<Map<String, dynamic>> get alerts => _alerts;
  List<Map<String, dynamic>> get parentAlerts => _parentAlerts;
  List<Map<String, dynamic>> get children => _children;
  Map<String, dynamic>? get analytics => _analytics;
  ThemeMode get themeMode => _themeMode;
  String? get userName => _userName;
  String? get userPhotoUrl => _userPhotoUrl;
  String? get userEmail => _api.userEmail;

  bool get biometricEnabled => _biometricEnabled;
  bool get isPendingBiometric => _isPendingBiometric;

  void completeBiometricAuth() {
    _isPendingBiometric = false;
    notifyListeners();
  }

  bool get hasPendingRequests => _pendingRequests.isNotEmpty;
  List<Map<String, dynamic>> get pendingRequests => _pendingRequests;

  String? get selectedChildId => _selectedChildId;
  Map<String, dynamic>? get selectedChild {
    if (_selectedChildId == null) return null;
    try {
      return _children.firstWhere((c) => c['email'] == _selectedChildId);
    } catch (_) {
      return null;
    }
  }

  // Monitoring Prefs Getters
  bool get audioMonitoringEnabled => _audioMonitoringEnabled;
  bool get screenMonitoringEnabled => _screenMonitoringEnabled;
  bool get pushNotificationsEnabled => _pushNotificationsEnabled;

  // Laptop Status Getters (NEW)

  bool get laptopOnline => _laptopOnline;
  bool get isPcAppOnline => _isPcAppOnline;
  bool get isLaunchingPcApp => _isLaunchingPcApp;

  // Check if a specific child's PC is being launched
  bool isLaunchingChildPc(String? childEmail) {
    if (childEmail == null) return _isLaunchingPcApp;
    return _childLaunchingState[childEmail] ?? false;
  }

  // Check if current selected child is launching
  bool get isLaunchingCurrentChild => isLaunchingChildPc(_selectedChildId);
  String get laptopHostname => _laptopHostname;
  String get laptopIp => _laptopIp;
  int get laptopUptimeSeconds => _laptopUptimeSeconds;
  DateTime? get lastSeenTime => _lastSeenTime;

  String get laptopUptimeFormatted {
    if (_laptopUptimeSeconds == 0) return '0h 0m';
    final hours = _laptopUptimeSeconds ~/ 3600;
    final minutes = (_laptopUptimeSeconds % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  }

  // Initialize
  Future<void> initialize() async {
    await _notifications.initialize();
    await _notifications.requestPermissions();

    // Load Theme & Server Config
    final prefs = await SharedPreferences.getInstance();

    // 1. Load Server URL first to enable global connection
    final savedUrl = prefs.getString(AppConstants.serverUrlKey);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      AppConstants.apiBaseUrl = savedUrl;
      // Test connection in background to enable internal flags like _isConnected
      testConnection(AppConstants.apiBaseUrl);
    }

    // 2. Load Theme
    final themeIndex = prefs.getInt(AppConstants.themeModeKey);
    if (themeIndex != null) {
      _themeMode = ThemeMode.values[themeIndex];
    }

    // 3. Load Monitoring Prefs
    _audioMonitoringEnabled = prefs.getBool('pref_audio_mon') ?? true;
    _screenMonitoringEnabled = prefs.getBool('pref_screen_mon') ?? true;
    _pushNotificationsEnabled = prefs.getBool('pref_push_notif') ?? true;

    // 4. Load Biometric state & Multi-Device Prefs
    _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    _selectedChildId = prefs.getString('selected_child_id');

    notifyListeners();

    // Check if we have a valid session and fetch profile/3FA status
    if (_googleSignIn.currentUser != null || Platform.isWindows) {
      // Attempt to refresh profile to get latest biometric status
      try {
        if (Platform.isWindows) {
          _userName = "Muhammad Saqlain (Admin)";
        }
        await getProfile();
      } catch (e) {
        debugPrint("Failed to refresh profile on init: $e");
      }
    }

    // Load cached data immediately for offline/persistence support
    await _loadCachedData();
  }

  // Attempt to restore session
  Future<bool> tryAutoLogin() async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('🔄 [AUTO] Step 1: Reading saved token/email...');
      final token = await _safeRead(AppConstants.tokenKey);
      final email = await _safeRead(AppConstants.emailKey);
      await _safeRead('secret_code'); // If we save this

      debugPrint(
          '🔄 [AUTO] Step 2: token=${token != null ? "exists" : "null"}, email=$email');

      if (token != null && email != null) {
        // Restore auth in ApiService
        _api.setAuth(token, email);

        // Verify token validity by fetching profile
        try {
          debugPrint('🔄 [AUTO] Step 3: Calling getProfile to verify token...');
          final profile = await getProfile();
          debugPrint(
              '🔄 [AUTO] Step 4: getProfile returned: ${profile != null ? "valid" : "null"}');
          if (profile != null) {
            // Token is valid

            // Restore additional info
            if (Platform.isWindows) {
              _userName = "Muhammad Saqlain (Admin)";
            }

            // Load theme preference from profile if available
            if (profile['user'] != null &&
                profile['user']['theme_mode'] != null) {
              final serverTheme = profile['user']['theme_mode'];
              if (serverTheme == 'dark') {
                _themeMode = ThemeMode.dark;
              } else if (serverTheme == 'light') {
                _themeMode = ThemeMode.light;
              } else {
                _themeMode = ThemeMode.system;
              }
            }

            // Start polling immediately so verification requests can be received
            await _startPolling();

            // 3FA Check - require biometric if enabled
            if (_biometricEnabled) {
              debugPrint('🔄 [AUTO] Step 5: Biometric pending');
              _isPendingBiometric = true;
              _isLoading = false;
              notifyListeners();
              return true;
            }

            debugPrint('🔄 [AUTO] Step 6: Polling started');

            // Update device telemetry in background
            DeviceInfoService.updateDeviceTelemetry(email).ignore();

            _isLoading = false;
            notifyListeners();
            debugPrint('🔄 [AUTO] ✅ Auto-login SUCCESS');
            return true;
          }
        } catch (e) {
          // Token expired or invalid
          debugPrint("🔄 [AUTO] ❌ Auto-login token check failed: $e");
        }
      }

      debugPrint('🔄 [AUTO] Auto-login not possible, showing login form');
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('🔄 [AUTO] ❌ Exception: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // [NEW] Load Cached Data
  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load Profile
      final profileStr = prefs.getString('cached_profile');
      if (profileStr != null) {
        final user = jsonDecode(profileStr);
        _userName = user['name'];
        _userPhotoUrl = user['profile_pic'];
        _biometricEnabled = user['biometric_enabled'] ?? false;
      }

      // Load Children
      final childrenStr = prefs.getString('cached_children');
      if (childrenStr != null) {
        final List<dynamic> decoded = jsonDecode(childrenStr);
        _children = decoded.cast<Map<String, dynamic>>();
      }

      // Load Alerts
      final alertsStr = prefs.getString('cached_alerts');
      if (alertsStr != null) {
        final List<dynamic> decoded = jsonDecode(alertsStr);
        _parentAlerts = decoded.cast<Map<String, dynamic>>();
      }

      // Load Analytics
      final analyticsStr = prefs.getString('cached_analytics');
      if (analyticsStr != null) {
        _analytics = jsonDecode(analyticsStr);
      }

      notifyListeners();
      debugPrint("📦 Loaded cached dashboard data");
    } catch (e) {
      debugPrint("Failed to load cache: $e");
    }
  }

  // Set Theme Mode
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.themeModeKey, mode.index);

    // Sync to backend
    try {
      String modeStr = 'system';
      if (mode == ThemeMode.dark) modeStr = 'dark';
      if (mode == ThemeMode.light) modeStr = 'light';

      await updateProfile({'theme_mode': modeStr});
    } catch (e) {
      debugPrint("Failed to sync theme: $e");
    }
  }

  // Set Monitoring Preferences
  Future<void> setMonitoringPreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();

    if (key == 'audio') {
      _audioMonitoringEnabled = value;
      await prefs.setBool('pref_audio_mon', value);
    } else if (key == 'screen') {
      _screenMonitoringEnabled = value;
      await prefs.setBool('pref_screen_mon', value);
    } else if (key == 'push') {
      _pushNotificationsEnabled = value;
      await prefs.setBool('pref_push_notif', value);

      // Also toggle local notification permission/settings if needed
      if (!value) {
        _notifications.cancelStatusNotification();
      }
    }
    notifyListeners();
  }

  // Test server connection and get laptop info
  // [silent]: if true, does not modify _isLoading (used when called internally)
  Future<bool> testConnection(String serverUrl, {bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    // Store old URL as fallback

    try {
      final healthData = await _api.getHealthInfoAtUrl(serverUrl);

      if (healthData != null) {
        // Success! NOW we can update the global URL
        AppConstants.apiBaseUrl = serverUrl;

        _isConnected = true;
        _laptopOnline = true;
        _laptopOfflineCount = 0;
        _lastSeenTime = DateTime.now();
        _errorMessage = null;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.serverUrlKey, serverUrl);
      } else {
        // [MODIFIED] Keep the serverUrl in apiBaseUrl so user can see it in logs/UI,
        // but mark as disconnected. Only revert if we explicitly want to
        // fallback to a known-working one.
        _isConnected = false;
        _laptopOnline = false;
        _errorMessage =
            'Server at $serverUrl is reachable but health check failed (maybe wrong port or app not running).';
      }
    } catch (e) {
      _isConnected = false;
      _laptopOnline = false;
      if (e is TimeoutException) {
        _errorMessage =
            'Connection to $serverUrl timed out. Check if PC and Mobile are on the same Wi-Fi and Firewall allows port 5000.';
      } else {
        _errorMessage = 'Connection failed to $serverUrl: $e';
      }
    }

    if (!silent) {
      _isLoading = false;
      notifyListeners();
    }
    return _isConnected;
  }

  // [NEW] Discover Server on Local Network
  Future<bool> discoverServer() async {
    _isLoading = true;
    _errorMessage = null; // Clear previous errors
    notifyListeners();

    try {
      final serverInfo = await ServerDiscoveryService.discoverServer();

      if (serverInfo != null && serverInfo['ip'] != null) {
        final ip = serverInfo['ip'];
        final port = serverInfo['port'] ?? 5000;
        final serverUrl = 'http://$ip:$port';

        debugPrint(
            "Discovery successful: $serverUrl (MAC: ${serverInfo['mac_address']})");
        _discoveredServer = serverInfo;
        _discoveredServer!['url'] = serverUrl;

        // Test connection silently (so it doesn't interfere with _isLoading)
        final success = await testConnection(serverUrl, silent: true);

        if (success) {
          // Save this URL for future
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(AppConstants.serverUrlKey, serverUrl);

          // [FIX] Always clear loading before returning
          _isLoading = false;
          notifyListeners();

          // Refresh data in background (don't block loading)
          refreshStatus().ignore();
          refreshAlerts().ignore();
          refreshAnalytics().ignore();

          return true;
        } else {
          _errorMessage = "Found server at $serverUrl but connection failed.";
        }
      } else {
        _errorMessage = "No CyberOwl server found on local network.";
      }
    } catch (e) {
      _errorMessage = "Discovery failed: $e";
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Login
  Future<bool> login(String email, String password, String secretCode) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint('🔑 [LOGIN] Step 1: Calling _api.login...');
      final result = await _api.login(email, password, secretCode);
      debugPrint(
          '🔑 [LOGIN] Step 2: _api.login returned: ${result['success']}');

      if (result['success']) {
        // Fetch profile to get latest biometric status from database
        debugPrint('🔑 [LOGIN] Step 3: Calling getProfile...');
        await getProfile();
        debugPrint('🔑 [LOGIN] Step 4: getProfile completed');

        // Save Auth Data FIRST (before biometric check) so credentials persist
        if (_api.authToken != null) {
          await _safeWrite(AppConstants.tokenKey, _api.authToken!);
        }
        await _safeWrite(AppConstants.emailKey, email);
        await _safeWrite(
            'secret_code', secretCode); // Used for re-auth if needed
        debugPrint('🔑 [LOGIN] Step 5: Auth data saved');

        // Start polling immediately so verification requests can be received
        debugPrint('🔑 [LOGIN] Step 6: Starting polling...');
        await _startPolling();

        // 3FA Check - now uses value from database
        if (_biometricEnabled) {
          debugPrint('🔑 [LOGIN] Step 7: Biometric pending, returning true');
          _isPendingBiometric = true;
          _isLoading = false;
          notifyListeners();
          return true;
        }

        debugPrint('🔑 [LOGIN] Step 7: Polling started');

        // Update device telemetry in background
        DeviceInfoService.updateDeviceTelemetry(email).ignore();

        _isLoading = false;
        notifyListeners();
        debugPrint('🔑 [LOGIN] ✅ Login complete, returning true');
        return true;
      } else {
        debugPrint('🔑 [LOGIN] ❌ Login failed: ${result['error']}');
        _errorMessage = result['error'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('🔑 [LOGIN] ❌ Exception: $e');
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    _stopPolling();
    _api.clearAuth();
    _isMonitoring = false;
    _uptimeSeconds = 0;
    _alerts = [];
    _totalAlerts = 0;
    _criticalAlerts = 0;
    _previousAlertCount = 0;
    _laptopOnline = false;

    // Clear Local Storage
    try {
      await _storage.delete(key: AppConstants.tokenKey);
      await _storage.delete(key: AppConstants.emailKey);
      await _storage.delete(key: 'secret_code');
    } catch (e) {
      debugPrint("Logout storage clear error: $e");
    }

    _socketService.disconnect();

    // Sign out from Google to force account chooser on next login
    if (!Platform.isWindows) {
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        // Ignore sign out errors
      }
    }

    notifyListeners();
  }

  // Start polling for updates - ensures all data is fetched BEFORE returning
  void _setupSocketListeners() {
    if (!_socketService.isConnected) {
      // Only setup if connected/reconnected
      // But listeners should be set once ideally or managed carefully
    }

    _socketService.statusStream.listen((data) {
      // 1. General System Status
      final wasRunning = _isMonitoring;
      _isMonitoring = data['running'] ?? _isMonitoring; // Update if provided
      if (data['uptime_seconds'] != null) {
        _uptimeSeconds = data['uptime_seconds'];
      }

      // [SYNC] If monitoring just started or stopped, refresh analytics for dashboard
      if (data['running'] != null && wasRunning != _isMonitoring) {
        refreshAnalytics().ignore();
      }

      // 2. PC Server Online Status
      _laptopOnline = data['pc_online'] ?? true;

      // 3. PC App Online Status (User-Specific)
      bool isMyPcOnline = false;
      final userStatusMap = data['user_status'];
      final myEmail = _api.userEmail;

      if (myEmail != null &&
          userStatusMap is Map &&
          userStatusMap.containsKey(myEmail)) {
        final myStatus = userStatusMap[myEmail];
        if (myStatus is Map && myStatus['status'] == 'online') {
          isMyPcOnline = true;
        }
      }
      _isPcAppOnline = isMyPcOnline;

      notifyListeners();
    });

    _socketService.alertStream.listen((data) {
      // Add alert
      if (data['id'] != null && !_alerts.any((a) => a['id'] == data['id'])) {
        _alerts.insert(0, data);
        _totalAlerts++;
        if (data['severity'] == 'critical') _criticalAlerts++;

        _notifications.showStatusNotification(
            title: 'New Alert: ${data['type']}',
            body: data['message'] ?? 'Suspicious activity detected',
            notificationType: 'warning');

        // [SYNC] Refresh analytics to update dashboard graphs/KPIs in real-time
        refreshAnalytics().ignore();
        notifyListeners();
      }
    });

    _socketService.notificationStream.listen((data) {
      // Handle general notifications
      if (data['title'] != null) {
        _notifications.showStatusNotification(
            title: data['title'],
            body: data['body'] ?? '',
            notificationType: 'info');
      }
    });
  }

  Future<void> _startPolling() async {
    // Initialize Socket Connection
    final serverUrl = AppConstants.apiBaseUrl;
    final userEmail = _api.userEmail;

    if (serverUrl.isNotEmpty) {
      _socketService.init(serverUrl, userEmail: userEmail);
      _setupSocketListeners();
    }

    // Start timers IMMEDIATELY to ensure data keeps trying to load even if initial fetch fails/slows
    _statusTimer = Timer.periodic(AppConstants.statusRefreshInterval, (_) {
      refreshStatus();
    });

    _alertsTimer = Timer.periodic(AppConstants.alertsRefreshInterval, (_) {
      refreshAlerts();
    });

    // Check laptop status every 3 seconds (faster for real-time feel)
    _laptopStatusTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      checkLaptopStatus();
    });

    // Poll for verification requests every 1 second (fast response for auth)
    _requestsTimer = Timer.periodic(AppConstants.requestsRefreshInterval, (_) {
      checkPendingRequests();
    });

    // Refresh parent data (children list & alerts) regularly (faster for real-time feel)
    _parentDataTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      refreshParentData();
    });

    // Fetch all data in parallel for faster loading
    // We don't await this to block the UI, but we do notify listeners when done
    Future.wait([
      refreshStatus(),
      refreshAlerts(),
      refreshAnalytics(), // Prefetch analytics for dashboard
      refreshParentData(), // Fetch children data
      checkLaptopStatus(),
      checkPendingRequests(), // Check immediately
    ]).then((_) {
      // Notify UI that data is now loaded
      notifyListeners();
    });
  }

  // Stop polling
  void _stopPolling() {
    _statusTimer?.cancel();
    _alertsTimer?.cancel();
    _laptopStatusTimer?.cancel();
    _requestsTimer?.cancel();
    _parentDataTimer?.cancel();
  }

  // Check laptop online status
  Future<void> checkLaptopStatus() async {
    try {
      // Use new system status endpoint
      final statusData = await _api.getSystemStatus();

      if (statusData != null) {
        final wasOnline = _laptopOnline;
        final wasPcAppOnline = _isPcAppOnline;

        // Update states
        _laptopOnline =
            true; // Connection successful means machine/server is ON
        _isPcAppOnline = statusData['app_online'] == true;

        _lastSeenTime = DateTime.now();

        // Check if PC App Status Changed
        if (_isPcAppOnline && !wasPcAppOnline) {
          await _notifications.showStatusNotification(
            title: 'PC App Connected',
            body: 'CyberOwl Desktop App is now active and connected',
            notificationType: 'success',
          );
        } else if (!_isPcAppOnline && wasPcAppOnline) {
          await _notifications.showStatusNotification(
            title: 'PC App Disconnected',
            body: 'CyberOwl Desktop App has been closed or disconnected',
            notificationType: 'warning',
          );
        }

        // Notify if laptop came back online
        if (!wasOnline && _wasLaptopOnline) {
          await _notifications.showStatusNotification(
            title: 'PC Server Back Online',
            body: 'CyberOwl Backend is now reachable',
            notificationType: 'success',
          );
        }
        _wasLaptopOnline = true;
        _laptopOfflineCount = 0; // Reset counter on success
        notifyListeners();
      } else {
        _laptopOfflineCount++;
        if (_laptopOfflineCount >= 3) {
          _handleLaptopOffline();
        }
      }
    } catch (e) {
      _laptopOfflineCount++;
      if (_laptopOfflineCount >= 3) {
        _handleLaptopOffline();
      }
    }
  }

  void _handleLaptopOffline() {
    bool stateChanged = false;

    if (_laptopOnline && _wasLaptopOnline) {
      // Laptop just went offline
      _notifications.showStatusNotification(
        title: 'PC Server Offline',
        body: 'CyberOwl Backend is not reachable. Attempting to re-discover...',
        notificationType: 'error',
      );
      stateChanged = true;

      // [NEW] Trigger background discovery if connection lost
      discoverServer().ignore();
    }

    if (_laptopOnline != false) {
      _laptopOnline = false;
      stateChanged = true;
    }

    if (_isPcAppOnline != false) {
      _isPcAppOnline = false;
      stateChanged = true;
    }

    if (stateChanged) notifyListeners();
  }

  // Refresh status
  Future<void> refreshStatus() async {
    try {
      final status = await _api.getStatus(childEmail: _selectedChildId);
      if (status != null) {
        final wasMonitoring = _isMonitoring;
        _isMonitoring = status['running'] ?? false;
        _uptimeSeconds = status['uptime_seconds'] ?? 0;

        // [NEW] If connected or monitoring, clear the 'Waking up' state
        if (_isMonitoring || _isConnected) {
          if (_selectedChildId != null) {
            _childLaunchingState[_selectedChildId!] = false;
          }
        }

        // Show notification if monitoring status changed
        if (wasMonitoring != _isMonitoring) {
          if (_isMonitoring) {
            await _notifications.showStatusNotification(
              title: 'Monitoring Active',
              body: 'CyberOwl is now protecting the device',
              ongoing: true,
              notificationType: 'success',
            );
          } else {
            await _notifications.cancelStatusNotification();
            await _notifications.showStatusNotification(
              title: 'Monitoring Stopped',
              body: 'CyberOwl protection is now inactive',
              notificationType: 'warning',
            );
          }
        }

        notifyListeners();
      }
    } catch (e) {
      debugPrint('Refresh status error: $e');
    }
  }

  // Refresh alerts
  Future<void> refreshAlerts() async {
    try {
      final result =
          await _api.getAlerts(limit: 100, childEmail: _selectedChildId);
      final stats = await _api.getAlertStats(childEmail: _selectedChildId);

      if (result != null) {
        final newAlerts =
            (result['alerts'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        // Strictly filter for threats only (abuse and nudity detections)
        final filteredAlerts = newAlerts
            .where((a) => a['type'] == 'abuse' || a['type'] == 'nudity')
            .toList();

        // Check for new detection alerts and send notification
        if (filteredAlerts.length > _previousAlertCount &&
            _previousAlertCount > 0) {
          final latestAlert =
              filteredAlerts.isNotEmpty ? filteredAlerts.last : null;

          if (latestAlert != null) {
            await _notifications.showDetectionAlert(
              title: 'New Detection Alert!',
              body:
                  '${latestAlert['label'] ?? 'Alert'}: ${latestAlert['sentence'] ?? 'Potential threat detected'}',
              isHighPriority: (latestAlert['score'] ?? 0) > 0.8,
              notificationType: 'alert',
            );
          }
        }

        _previousAlertCount = filteredAlerts.length;
        _alerts = filteredAlerts.reversed.toList(); // Newest first
      }

      if (stats != null) {
        _totalAlerts = stats['total'] ?? 0;
        _criticalAlerts = stats['high_confidence'] ?? 0;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Refresh alerts error: $e');
    }
  }

  // Refresh Parent Data (Children & their Alerts)
  Future<void> refreshParentData() async {
    try {
      final email = _api.userEmail;
      if (email == null) return;

      // 1. Fetch Children
      final childrenList = await ApiService.getParentChildren(email);
      if (childrenList != null) {
        _children = childrenList.cast<Map<String, dynamic>>();
        debugPrint("DEBUG: Fetched ${_children.length} children for $email");
      } else {
        debugPrint("DEBUG: getParentChildren returned null for $email");
      }

      // 2. Fetch Parent Notifications (Alerts + System Events)
      final notifications =
          await ApiService.getParentNotifications(email, limit: 50);

      // Only process if we got valid data
      if (notifications != null) {
        // Cast to List<Map<String, dynamic>>
        final newAlerts = notifications.cast<Map<String, dynamic>>();

        // Detect new notifications by comparing latest created_at timestamp
        // (length comparison breaks once limit is reached)
        if (newAlerts.isNotEmpty && _parentAlerts.isNotEmpty) {
          final lastKnown = _parentAlerts.first['created_at'] ?? '';
          // Collect all entries newer than the last known timestamp
          final newEntries = newAlerts
              .where((n) => (n['created_at'] ?? '').compareTo(lastKnown) > 0)
              .toList();

          for (final latest in newEntries) {
            final type = latest['type'] ?? 'system';
            final source = latest['source'] ?? 'Child PC';

            if (type == 'abuse') {
              await _notifications.showDetectionAlert(
                  title: 'Alert from $source',
                  body: '${latest['label']}: ${latest['sentence'] ?? ''}',
                  isHighPriority: true,
                  notificationType: 'alert');
            } else if (type == 'auth') {
              await _notifications.showStatusNotification(
                  title: 'Password Reset — $source',
                  body: latest['sentence'] ?? 'A password reset was performed',
                  notificationType: 'info');
            } else if (type == 'rotation') {
              await _notifications.showStatusNotification(
                  title: 'Secret Code Rotated — $source',
                  body:
                      latest['sentence'] ?? 'The secret code has been changed',
                  notificationType: 'warning');
            } else if (type == 'system') {
              final msg = (latest['sentence'] ?? '').toString().toLowerCase();
              if (msg.contains('start') ||
                  msg.contains('stop') ||
                  msg.contains('active') ||
                  msg.contains('inactive') ||
                  msg.contains('online') ||
                  msg.contains('offline')) {
                await _notifications.showStatusNotification(
                    title: 'System — $source',
                    body: latest['sentence'] ?? 'System event',
                    notificationType: msg.contains('start') ||
                            msg.contains('active') ||
                            msg.contains('online')
                        ? 'success'
                        : 'warning');
              }
            }
          }
        }

        // Update parent alerts only on success
        _parentAlerts = newAlerts;
      }

      // Cache the data
      final prefs = await SharedPreferences.getInstance();
      if (_children.isNotEmpty) {
        await prefs.setString('cached_children', jsonEncode(_children));
      }
      if (_parentAlerts.isNotEmpty) {
        await prefs.setString('cached_alerts', jsonEncode(_parentAlerts));
      }

      // Auto-select first child if none is selected and children are available
      if (_selectedChildId == null && _children.isNotEmpty) {
        final firstChild = _children.first;
        final email = firstChild['email'];
        if (email != null) {
          // Use selectChild as it handles correlation and connection testing
          await selectChild(email);
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint("Refresh parent data error: $e");
    }
  }

  // [NEW] Select a child - no security verification needed for switching
  Future<bool> selectChild(String childEmail,
      {bool forceVerify = false}) async {
    // If same child selected, no need to switch unless forced
    if (childEmail == _selectedChildId && !forceVerify) {
      return true;
    }

    // NOTE: Security verification removed - biometric only used for login and PC verification

    // Clear current dashboard state to prevent data cross-contamination
    _clearCurrentChildState();

    // Persist selection immediately
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_child_id', childEmail);

    final child = _children.firstWhere((c) => c['email'] == childEmail,
        orElse: () => {}); // Find the child data
    // [NEW] Clear current metrics/status before switching to avoid showing old data
    _analytics = null;
    _alerts = [];
    _isPcAppOnline = false;
    notifyListeners();

    String? url;

    if (child.isNotEmpty &&
        (child['last_ip'] != null || child['last_seen_ip'] != null)) {
      final ip = child['last_ip'] ?? child['last_seen_ip'];
      debugPrint("Attempting to connect to Child: ${child['name']} ($ip)");

      if (ip.toString().isNotEmpty) {
        url = ip.toString().startsWith('http')
            ? ip.toString()
            : AppConstants.apiBaseUrl;
      }
    }

    // Correlation Logic: If we have a discovered server, check if it matches this child
    if (_discoveredServer != null && _discoveredServer!['url'] != null) {
      final discoveredMac = _discoveredServer!['mac_address'];
      final discoveredIp = _discoveredServer!['ip'];
      final childMac = child['mac_address'];
      final childIp = child['last_ip'] ?? child['last_seen_ip'];

      bool isMatch = false;
      final discoveredHostname = _discoveredServer!['hostname'];
      final childHostname = child['hostname'] ?? child['device_name'];

      if (discoveredMac != null &&
          childMac != null &&
          discoveredMac == childMac) {
        debugPrint(
            "📍 Correlation Success: MAC Match found ($discoveredMac). Prioritizing discovered server.");
        isMatch = true;
      } else if (discoveredIp != null &&
          childIp != null &&
          discoveredIp == childIp) {
        debugPrint(
            "📍 Correlation Success: IP Match found ($discoveredIp). Prioritizing discovered server.");
        isMatch = true;
      } else if (discoveredHostname != null &&
          childHostname != null &&
          discoveredHostname.toString().toLowerCase() ==
              childHostname.toString().toLowerCase()) {
        debugPrint(
            "📍 Correlation Success: Hostname Match found ($discoveredHostname). Prioritizing discovered server.");
        isMatch = true;
      }

      if (isMatch) {
        url = _discoveredServer!['url'];
      }
    }

    bool connected = false;
    if (url != null) {
      debugPrint("Switching server to child: $url");
      connected = await testConnection(url);
    }

    if (connected) {
      _selectedChildId = childEmail;
      // Run all refreshes in parallel for speed
      await Future.wait([
        refreshStatus(),
        refreshAlerts(),
        refreshAnalytics(),
      ]);

      notifyListeners();
      return true;
    } else {
      debugPrint("Child $childEmail is offline or unreachable at $url.");
      _selectedChildId = childEmail;

      // If unreachable, we MUST clear the volatile status data so we don't show the PREVIOUS child's data
      _isMonitoring = false;
      _uptimeSeconds = 0;
      _laptopOnline = false;
      _isPcAppOnline = false;
      _analytics = null;
      _alerts = [];

      notifyListeners();
      return true;
    }
  }

  // [NEW] Clear state for the current child
  void _clearCurrentChildState() {
    _alerts = [];
    _totalAlerts = 0;
    _criticalAlerts = 0;
    _previousAlertCount = 0;
    _analytics = null;
    _uptimeSeconds = 0;
    // Don't clear _laptopOnline immediately as it causes the UI to flicker "Offline"
    // during a fast transition. Let the next polling update it correctly.
    // _laptopOnline = false;
    _isPcAppOnline = false;
    notifyListeners();
  }

  // Launch PC App for a specific child (independent per-child wake-up)
  // If childEmail is null, launches for currently selected child
  Future<bool> launchPcApp({String? childEmail}) async {
    // Determine which child to launch for
    // If no specific child selected, default to current user email (for standalone usage)
    final targetChildEmail = childEmail ?? _selectedChildId ?? _api.userEmail;

    // Find the child data to get their server URL
    Map<String, dynamic>? targetChild;
    String? targetServerUrl;

    if (targetChildEmail != null) {
      try {
        targetChild =
            _children.firstWhere((c) => c['email'] == targetChildEmail);
        final ip = targetChild['last_ip'] ?? targetChild['last_seen_ip'];
        if (ip != null && ip.toString().isNotEmpty) {
          targetServerUrl = ip.toString().startsWith('http')
              ? ip.toString()
              : AppConstants.apiBaseUrl;
        }
      } catch (_) {
        // Child not found, use current server
      }
    }

    // Use current server URL if no specific child URL found
    targetServerUrl ??= AppConstants.apiBaseUrl;

    // Set launching state for this specific child
    if (targetChildEmail != null) {
      _childLaunchingState[targetChildEmail] = true;
    }
    _isLaunchingPcApp = true;
    notifyListeners();

    final childName = targetChild?['name'] ?? 'PC';

    // SMART WAKE LOGIC
    // 1. If machine seems offline, try WoL first
    final isMachineOnline = targetChildEmail == _selectedChildId
        ? _laptopOnline
        : (targetChild?['online_status'] == 'online');

    if (!isMachineOnline) {
      debugPrint("Machine seems offline, sending WoL packet first...");
      await wakeUpPc(childEmail: targetChildEmail);
      // Wait a bit for PC to start booting (optional, launch will poll anyway)
      await Future.delayed(const Duration(seconds: 5));
    }

    // 2. Call the launch endpoint (this will work if/when server is online)
    // We try multiple times in case it's still booting
    bool success = false;

    // BACKEND-MEDIATED LAUNCH (Reliable path via central DB)
    if (targetChildEmail != null) {
      debugPrint("Triggering backend-mediated launch for $targetChildEmail...");
      _api.requestLaunch(targetChildEmail); // Fire and forget backend trigger
    }

    for (int retry = 0; retry < 3; retry++) {
      success = await _api.launchPcAppAtUrl(targetServerUrl,
          childEmail: targetChildEmail);
      if (success) break;
      if (retry < 2) await Future.delayed(const Duration(seconds: 5));
    }

    if (success) {
      await _notifications.showStatusNotification(
        title: 'Launching $childName...',
        body: 'Starting CyberOwl Desktop. Please wait...',
        notificationType: 'info',
      );

      // Poll for app to come online (max 90 seconds)
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(seconds: 3));

        // Check status specifically for this child's server
        final statusData = await _api.getSystemStatusAtUrl(targetServerUrl);
        final isOnline = statusData?['app_online'] == true;

        if (isOnline) {
          // Clear launching state for this child
          if (targetChildEmail != null) {
            _childLaunchingState[targetChildEmail] = false;
          }
          _isLaunchingPcApp = false;

          // Update global state only if this is the current child
          if (targetChildEmail == _selectedChildId) {
            _isPcAppOnline = true;
          }

          notifyListeners();
          await _notifications.showStatusNotification(
            title: '$childName Online!',
            body: 'CyberOwl Desktop is ready and active.',
            notificationType: 'success',
          );
          return true;
        }
      }

      // Timeout - app didn't come online in time
      if (targetChildEmail != null) {
        _childLaunchingState[targetChildEmail] = false;
      }
      _isLaunchingPcApp = false;
      notifyListeners();
      await _notifications.showStatusNotification(
        title: 'Launch Timeout',
        body: '$childName is taking longer than expected. Please check the PC.',
        notificationType: 'warning',
      );
      return false;
    }

    if (targetChildEmail != null) {
      _childLaunchingState[targetChildEmail] = false;
    }
    _isLaunchingPcApp = false;
    notifyListeners();
    return false;
  }

  // Wake PC via Wake-on-LAN
  Future<bool> wakeUpPc({String? childEmail}) async {
    final targetChildEmail = childEmail ?? _selectedChildId;
    if (targetChildEmail == null) return false;

    try {
      final child = _children.firstWhere((c) => c['email'] == targetChildEmail,
          orElse: () => {});
      if (child.isEmpty) return false;

      final macAddress = child['mac_address'];
      // Standard local broadcast.
      // Note: This works on local network (same subnet).
      // For remote wake-up over internet, you'd need a relay or valid public broadcast (rarely allowed).
      String broadcastIp = '255.255.255.255';

      if (macAddress != null &&
          macAddress.toString().isNotEmpty &&
          MACAddress.validate(macAddress).state) {
        final mac = MACAddress(macAddress);
        final ipv4 = IPAddress(broadcastIp);

        // Send Magic Packet
        await WakeOnLAN(ipv4, mac).wake();

        await _notifications.showStatusNotification(
            title: 'Wake Signal Sent',
            body: 'Magic packet sent to ${child['name'] ?? "PC"}',
            notificationType: 'info');

        return true;
      }

      _errorMessage = "MAC address not available for this device";
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint("Wake on LAN error: $e");
      _errorMessage = "Failed to wake PC: $e";
      notifyListeners();
      return false;
    }
  }

  // Start monitoring
  Future<bool> startMonitoring() async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _api.startMonitoring(_selectedChildId!);

      if (result['success']) {
        // [FIX] Immediately set monitoring to true so the button shows STOP right away.
        // Don't wait for status poll which may get a stale 'false' from the backend
        // before the monitoring thread has fully registered its state.
        _isMonitoring = true;
        _isLoading = false;
        notifyListeners();

        // Send notification
        await _notifications.showStatusNotification(
          title: 'Monitoring Started',
          body: 'CyberOwl is now actively monitoring the device',
          notificationType: 'success',
        );

        // [SYNC] After a short delay, refresh status to confirm it's truly running
        Future.delayed(const Duration(seconds: 3), () {
          try {
            refreshStatus();
          } catch (_) {}
        });

        // [SYNC] Refresh analytics to ensure dashboard is up to date
        refreshAnalytics().ignore();
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return result['success'];
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Stop monitoring
  Future<bool> stopMonitoring(String secretCode) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result =
          await _api.stopMonitoring(secretCode, childEmail: _selectedChildId);

      if (result['success']) {
        await refreshStatus();
        await _notifications.cancelStatusNotification();

        // Send notification
        await _notifications.showStatusNotification(
          title: 'Monitoring Stopped',
          body: 'CyberOwl monitoring has been stopped',
          notificationType: 'warning',
        );

        // [SYNC] Refresh analytics
        refreshAnalytics().ignore();
      } else {
        _errorMessage = result['message'];
      }

      _isLoading = false;
      notifyListeners();
      return result['success'];
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Clear alerts
  Future<bool> clearAlerts() async {
    try {
      final success = await _api.clearAlerts();
      if (success) {
        _alerts = [];
        _totalAlerts = 0;
        _criticalAlerts = 0;
        _previousAlertCount = 0;
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('Clear alerts error: $e');
      return false;
    }
  }

  // Refresh analytics
  Future<void> refreshAnalytics() async {
    try {
      _analytics = await _api.getAnalytics(childEmail: _selectedChildId);

      if (_analytics != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_analytics', jsonEncode(_analytics));
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Refresh analytics error: $e');
    }
  }

  // Format uptime
  String get formattedUptime {
    if (_uptimeSeconds == 0) return '00:00:00';
    final hours = _uptimeSeconds ~/ 3600;
    final minutes = (_uptimeSeconds % 3600) ~/ 60;
    final seconds = _uptimeSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // --- Profile & Schedule ---

  Future<Map<String, dynamic>?> getProfile() async {
    final result = await _api.getProfile();
    if (result != null && result['user'] != null) {
      final user = result['user'];
      _userName = user['name'];
      _userPhotoUrl = user['profile_pic'];
      debugPrint(
          "DEBUG: getProfile success -> name: $_userName, pic: $_userPhotoUrl, email: ${user['email']}");
      _biometricEnabled =
          user['biometric_enabled'] ?? false; // Update local state

      // Cache biometric state locally for persistence
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', _biometricEnabled);
      // Cache full profile
      await prefs.setString('cached_profile', jsonEncode(user));

      notifyListeners();
    }
    return result;
  }

  // Helper to get full image URL
  String? get fullUserPhotoUrl {
    return AppConstants.resolveProfilePic(_userPhotoUrl);
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final result = await _api.updateProfile(data);
    if (result['success'] == true && result['user'] != null) {
      final user = result['user'];
      _userName = user['name'];
      _userPhotoUrl = user['profile_pic'];
      notifyListeners();
    }
    return result;
  }

  Future<bool> uploadProfilePhoto(File file) async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await _api.uploadProfilePhoto(file);
      if (result['success'] == true) {
        // Update local state with the new relative path from server
        _userPhotoUrl = result['photo_url'];
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'];
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> getSecretCodeSchedule() async {
    return await _api.getSecretCodeSchedule();
  }

  Future<bool> updateSecretCodeSchedule(Map<String, dynamic> schedule) async {
    return await _api.updateSecretCodeSchedule(schedule);
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  // ================= BIOMETRIC 3FA METHODS =================

  // Toggle Biometric 3FA
  Future<bool> toggleBiometric(bool enabled) async {
    try {
      // First check if device supports it
      if (enabled) {
        final canCheck = await _biometricService.isBiometricAvailable();
        if (!canCheck) {
          _errorMessage = "Biometrics not available on this device";
          notifyListeners();
          return false;
        }

        // Verify identity before enabling
        final bioVerified = await _biometricService.authenticate(
            localizedReason: 'Verify identity to enable Biometric 3FA');
        if (!bioVerified) {
          return false;
        }
      }

      final success = await _api.toggleBiometric(enabled);
      if (success) {
        _biometricEnabled = enabled;

        // Save locally for persistence
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('biometric_enabled', enabled);

        notifyListeners();
      }
      return success;
    } catch (e) {
      _errorMessage = "Failed to toggle biometric: $e";
      notifyListeners();
      return false;
    }
  }

  // Explicit Biometric Verification (called from UI)
  Future<bool> authenticateBiometricOnly() async {
    return await _biometricService.authenticate(
        localizedReason: 'Verify identity to complete login');
  }

  // Verify Secret Code against stored value
  Future<bool> verifySecretCode(String inputCode) async {
    final storedCode = await _storage.read(key: 'secret_code');
    return storedCode == inputCode;
  }

  // Complete Login after external verification
  Future<void> completeLogin() async {
    _isPendingBiometric = false;
    await _startPolling(); // NOW we start polling/updates
    notifyListeners();
  }

  // Legacy method - kept for compatibility if needed, but updated logic
  Future<bool> verifyBiometric() async {
    final bioSuccess = await authenticateBiometricOnly();

    if (bioSuccess) {
      await completeLogin();
      return true;
    } else {
      _errorMessage = "Biometric verification failed";
      notifyListeners();
      return false;
    }
  }

  // Check Pending Requests
  Future<void> checkPendingRequests() async {
    // [MODIFIED] If laptop is offline, check for new IP from DB or re-discover
    if (!isConnected) {
      // Periodic check while waiting for auth
      if (isAuthenticated) {
        refreshParentData().ignore();
      }
      return;
    }

    try {
      final requests = await _api.getPendingRequests();

      // Notify if new request comes in
      if (requests.isNotEmpty && requests.length > _pendingRequests.length) {
        // Show notification
        await _notifications.showDetectionAlert(
            title: 'PC Access Request',
            body: 'Tap to approve remote access',
            isHighPriority: true,
            notificationType: 'auth');
      }

      _pendingRequests = requests;
      notifyListeners();
    } catch (e) {
      debugPrint("Check pending requests error: $e");
    }
  }

  // Approve PC Request
  Future<bool> approvePcRequest(String requestId) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Verify Biometric locally
      final bioSuccess = await _biometricService.authenticate(
          localizedReason: 'Verify to unlock PC App');

      if (!bioSuccess) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // OPTIMISTIC UPDATE: Remove request locally to prevent dialog reappearing
      _pendingRequests.removeWhere((r) => r['request_id'] == requestId);
      notifyListeners();

      // 2. Call API to approve
      final success = await _api.approveRequest(requestId, 'approved');

      if (success) {
        // Refresh list
        await checkPendingRequests();
        await _notifications.showDetectionAlert(
            title: 'Request Approved',
            body: 'PC App access granted',
            notificationType: 'auth');
      } else {
        // Refresh list on fail
        await checkPendingRequests();
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Reject Request
  Future<void> rejectPcRequest(String requestId) async {
    try {
      await _api.approveRequest(requestId,
          'rejected'); // Using approve endpoint for reject too based on API logic
      await checkPendingRequests();
    } catch (e) {
      debugPrint("Reject error: $e");
    }
  }
}
