import 'dart:async';
import 'dart:io'; // Needed for SocketException
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'backend_service.dart';

enum BackendStatus {
  starting,
  running,
  reconnecting,
  failed,
}

class BackendMonitor {
  static const Duration _healthCheckInterval = Duration(seconds: 5);
  static const int _maxRetries = 60; // Wait up to 60 seconds for manual start

  final BackendService _backendService = BackendService();

  Timer? _healthCheckTimer;
  int _retryCount = 0;
  BackendStatus _status = BackendStatus.starting;

  final _statusController = StreamController<BackendStatus>.broadcast();
  Stream<BackendStatus> get statusStream => _statusController.stream;
  BackendStatus get currentStatus => _status;

  String? _lastError;
  String? get lastError => _lastError;

  static final BackendMonitor _instance = BackendMonitor._internal();
  factory BackendMonitor() => _instance;
  BackendMonitor._internal();

  String get _healthUrl => '${AuthService.baseUrl}/health';

  Future<bool> initialize() async {
    debugPrint('╔═══════════════════════════════════════╗');
    debugPrint('║   Backend Monitor: Initializing      ║');
    debugPrint('║   (External Server Mode)             ║');
    debugPrint('╚═══════════════════════════════════════╝');

    _updateStatus(BackendStatus.starting);
    _retryCount = 0;

    return await _waitForExternalServer();
  }

  Future<bool> _waitForExternalServer() async {
    while (_retryCount < _maxRetries) {
      _retryCount++;

      debugPrint(
          'Attempt $_retryCount/$_maxRetries: Checking for external server...');

      final (healthy, _) = await _checkHealthWithDetails();
      if (healthy) {
        debugPrint('✓✓✓ External Backend Connected ✓✓✓\n');
        _updateStatus(BackendStatus.running);
        _startHealthCheck();
        _lastError = null;
        return true;
      }

      // Wait before retrying
      if (_retryCount < _maxRetries) {
        _updateStatus(BackendStatus.reconnecting);
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    // All retries exhausted
    debugPrint('╔═══════════════════════════════════════╗');
    debugPrint('║   FAILED TO CONNECT TO SERVER        ║');
    debugPrint('║   Please ensure api_server_updated   ║');
    debugPrint('║   is running on port 5000            ║');
    debugPrint('╚═══════════════════════════════════════╝');

    _lastError = 'Could not connect to external server. Is it running?';
    _updateStatus(BackendStatus.failed);
    return false;
  }

  Future<(bool, String?)> _checkHealthWithDetails() async {
    try {
      final response = await http
          .get(Uri.parse(_healthUrl))
          .timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        return (true, null);
      } else {
        return (false, 'HTTP ${response.statusCode}: ${response.body}');
      }
    } on TimeoutException catch (e) {
      return (false, 'Timeout: $e');
    } on SocketException catch (e) {
      return (false, 'Connection refused: $e');
    } catch (e) {
      return (false, 'Connection failed: $e');
    }
  }

  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (timer) async {
      if (_status == BackendStatus.running) {
        final (healthy, _) = await _checkHealthWithDetails();
        if (!healthy) {
          debugPrint('⚠ Lost connection to backend server');
          timer.cancel();
          _retryCount = 0;
          _updateStatus(BackendStatus.reconnecting);
          await _waitForExternalServer();
        }
      }
    });
  }

  void _updateStatus(BackendStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(newStatus);
    }
  }

  Future<void> shutdown() async {
    debugPrint(
        'BackendMonitor: Stopping health checks (Server remains active)');
    _healthCheckTimer?.cancel();
    await _statusController.close();
  }

  Future<bool> retryConnection() async {
    debugPrint('═══ Manual Retry Requested ═══');
    _retryCount = 0;
    _lastError = null;
    return await initialize();
  }
}
