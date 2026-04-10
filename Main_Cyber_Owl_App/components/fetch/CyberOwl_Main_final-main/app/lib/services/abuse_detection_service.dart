import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'auth_service.dart';

/// Represents an abuse alert detected by the system
class AbuseAlert {
  final String timestamp;
  final String source;
  final String label;
  final double score;
  final String? sentence;
  final String type;
  final String? matched;
  final double? latencyMs;

  AbuseAlert({
    required this.timestamp,
    required this.source,
    required this.label,
    required this.score,
    this.sentence,
    required this.type,
    this.matched,
    this.latencyMs,
  });

  factory AbuseAlert.fromJson(Map<String, dynamic> json) {
    return AbuseAlert(
      timestamp: json['timestamp'] ?? '',
      source: json['source'] ?? '',
      label: json['label'] ?? '',
      score: (json['score'] ?? 0.0).toDouble(),
      sentence: json['sentence']?.toString(),
      type: json['type']?.toString() ?? 'abuse',
      matched: json['matched']?.toString(),
      latencyMs: (json['latency_ms'] ?? 0.0).toDouble(),
    );
  }

  // Helper for offline mode
  factory AbuseAlert.mock() {
    return AbuseAlert(
      timestamp: DateTime.now().toIso8601String(),
      source: 'Offline Mic',
      label: 'Toxic Language',
      score: 0.95,
      sentence: 'This is a simulated toxic sentence for testing.',
      type: 'abuse',
      matched: 'toxic',
      latencyMs: 150,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'source': source,
      'label': label,
      'score': score,
      'sentence': sentence,
      'type': type,
      'matched': matched,
      'latency_ms': latencyMs,
    };
  }

  bool get isHighConfidence => score >= 0.9;
}

/// Represents a live transcript segment
class LiveTranscript {
  final String timestamp;
  final String text;
  final String type;

  LiveTranscript(
      {required this.timestamp, required this.text, required this.type});

  factory LiveTranscript.fromJson(Map<String, dynamic> json) {
    return LiveTranscript(
      timestamp: json['timestamp'] ?? '',
      text: json['text'] ?? '',
      type: json['type'] ?? 'unknown',
    );
  }
}

/// Statistics about detected alerts
class AlertStats {
  final int total;
  final int highConfidence;
  final Map<String, int> bySource;
  final Map<String, int> byType;

  AlertStats({
    required this.total,
    required this.highConfidence,
    required this.bySource,
    required this.byType,
  });

  factory AlertStats.fromJson(Map<String, dynamic> json) {
    return AlertStats(
      total: json['total'] ?? 0,
      highConfidence: json['high_confidence'] ?? 0,
      bySource: Map<String, int>.from(json['by_source'] ?? {}),
      byType: Map<String, int>.from(json['by_type'] ?? {}),
    );
  }
}

/// Monitoring status information
class MonitoringStatus {
  final bool running;
  final String? startTime;
  final int alertsCount;
  final int uptimeSeconds;

  MonitoringStatus({
    required this.running,
    this.startTime,
    required this.alertsCount,
    required this.uptimeSeconds,
  });

  factory MonitoringStatus.fromJson(Map<String, dynamic> json) {
    return MonitoringStatus(
      running: json['running'] ?? false,
      startTime: json['start_time']?.toString(),
      alertsCount: json['alerts_count'] ?? 0,
      uptimeSeconds: json['uptime_seconds'] ?? 0,
    );
  }

  String get uptimeFormatted {
    if (uptimeSeconds < 60) return '${uptimeSeconds}s';
    if (uptimeSeconds < 3600) {
      return '${uptimeSeconds ~/ 60}m ${uptimeSeconds % 60}s';
    }
    final hours = uptimeSeconds ~/ 3600;
    final minutes = (uptimeSeconds % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  }
}

/// Represents a persistent detection log
class DetectionLog {
  final String user;
  final String timestamp;
  final String source;
  final String label;
  final double score;
  final String? sentence;
  final String type;
  final String logTime;

  DetectionLog({
    required this.user,
    required this.timestamp,
    required this.source,
    required this.label,
    required this.score,
    required this.sentence,
    required this.type,
    required this.logTime,
  });

  factory DetectionLog.fromJson(Map<String, dynamic> json) {
    return DetectionLog(
      user: json['user'] ?? 'unknown',
      timestamp: json['timestamp'] ?? '',
      source: json['source'] ?? '',
      label: json['label'] ?? '',
      score: (json['score'] ?? 0.0).toDouble(),
      sentence: json['sentence'],
      type: json['type'] ?? 'abuse',
      logTime: json['log_time'] ?? '',
    );
  }
}

/// Service for communicating with Python abuse detection API
class AbuseDetectionService {
  static final AbuseDetectionService _instance =
      AbuseDetectionService._internal();
  factory AbuseDetectionService() => _instance;
  AbuseDetectionService._internal();

  String get baseUrl => AuthService.baseUrl;
  static const Duration pollingInterval = Duration(seconds: 2);
  static const Duration requestTimeout = Duration(seconds: 3);

  static bool isOfflineMode = false;

  Timer? _pollingTimer;
  io.Socket? _socket;
  bool _isServerHealthy = true;

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final StreamController<List<AbuseAlert>> _alertsController =
      StreamController<List<AbuseAlert>>.broadcast();
  final StreamController<List<LiveTranscript>> _transcriptsController =
      StreamController<List<LiveTranscript>>.broadcast();
  final StreamController<MonitoringStatus> _statusController =
      StreamController<MonitoringStatus>.broadcast();
  final StreamController<AlertStats> _statsController =
      StreamController<AlertStats>.broadcast();
  final StreamController<List<DetectionLog>> _logsController =
      StreamController<List<DetectionLog>>.broadcast();

  Stream<bool> get connectionStream => _connectionController.stream;
  bool get isServerHealthy => _isServerHealthy;
  Stream<AlertStats> get statsStream => _statsController.stream;
  Stream<List<AbuseAlert>> get alertsStream => _alertsController.stream;
  Stream<List<LiveTranscript>> get transcriptsStream =>
      _transcriptsController.stream;
  Stream<MonitoringStatus> get statusStream => _statusController.stream;
  Stream<List<DetectionLog>> get logsStream => _logsController.stream;

  Future<bool> checkHealth() async {
    if (isOfflineMode) return true;

    try {
      final response =
          await http.get(Uri.parse('$baseUrl/health')).timeout(requestTimeout);
      final isHealthy =
          (response.statusCode == 200 && response.body.isNotEmpty);

      if (isHealthy != _isServerHealthy) {
        _isServerHealthy = isHealthy;
        _connectionController.add(isHealthy);
      }
      return isHealthy;
    } catch (e) {
      if (_isServerHealthy) {
        _isServerHealthy = false;
        if (!_connectionController.isClosed) _connectionController.add(false);
      }
      return false;
    }
  }

  Future<Map<String, dynamic>> startMonitoring({String? userEmail}) async {
    if (isOfflineMode) {
      startPolling();
      return {'success': true, 'message': 'Started (Offline Mode)'};
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/start'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'email': userEmail ?? 'guest'}),
          )
          .timeout(requestTimeout);

      if (response.body.isEmpty) {
        return {'success': false, 'error': 'Empty response from server'};
      }

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        startPolling();
        return {'success': true, 'message': data['message'] ?? 'Started'};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to start monitoring'
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> stopMonitoring(
      {String? secretCode, bool forceStop = false, String? reason}) async {
    if (isOfflineMode) {
      stopPolling();
      return {
        'success': true,
        'message': 'Stopped (Offline Mode)',
        'uptime': 120
      };
    }

    try {
      stopPolling();

      final response = await http
          .post(
            Uri.parse('$baseUrl/stop'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'secret_code': secretCode,
              'force_stop': forceStop, // Allow force stop for logout
              'reason': reason, // Pass reason (e.g., 'logout')
            }),
          )
          .timeout(requestTimeout);

      if (response.body.isEmpty) {
        return {'success': false, 'error': 'Empty response from server'};
      }

      final data = json.decode(response.body);

      if (response.statusCode == 403) {
        return {
          'success': false,
          'error': data['error'] ?? 'Invalid Secret Code'
        };
      }

      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Stopped',
        'uptime': data['uptime_seconds']
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<MonitoringStatus> getStatus({String? deviceId}) async {
    if (isOfflineMode) {
      return MonitoringStatus(
          running: _pollingTimer != null,
          startTime: DateTime.now()
              .subtract(const Duration(minutes: 5))
              .toIso8601String(),
          alertsCount: 5,
          uptimeSeconds: 300);
    }

    try {
      String url = '$baseUrl/status';
      if (deviceId != null) url += '?device_id=$deviceId';

      final response = await http.get(Uri.parse(url)).timeout(requestTimeout);

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        try {
          return MonitoringStatus.fromJson(json.decode(response.body));
        } catch (e) {
          debugPrint('Status Parse Error: $e');
        }
      }
      return MonitoringStatus(running: false, alertsCount: 0, uptimeSeconds: 0);
    } catch (e) {
      return MonitoringStatus(running: false, alertsCount: 0, uptimeSeconds: 0);
    }
  }

  Future<List<AbuseAlert>> getAlerts({int limit = 50, String? deviceId}) async {
    if (isOfflineMode) return List.generate(3, (index) => AbuseAlert.mock());

    try {
      String url = '$baseUrl/alerts?limit=$limit';
      if (deviceId != null) url += '&device_id=$deviceId';

      final uri = Uri.parse(url);
      final response = await http.get(uri).timeout(requestTimeout);

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        try {
          final data = json.decode(response.body);
          final List alertsJson = data['alerts'] ?? [];
          return alertsJson.map((json) => AbuseAlert.fromJson(json)).toList();
        } catch (e) {
          debugPrint('Alert Parse Error: $e');
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<DetectionLog>> getLogs({String? deviceId}) async {
    if (isOfflineMode) return [];
    try {
      String url = '$baseUrl/logs';
      if (deviceId != null) url += '?device_id=$deviceId';

      final response = await http.get(Uri.parse(url)).timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List list = data['logs'] ?? [];
        return list
            .map((json) => DetectionLog.fromJson(json))
            .toList()
            .reversed
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> clearAlerts({String? deviceId}) async {
    try {
      String url = '$baseUrl/alerts/clear';
      if (deviceId != null) url += '?device_id=$deviceId';

      final response = await http.post(Uri.parse(url)).timeout(requestTimeout);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<AlertStats?> getAlertStats({String? deviceId}) async {
    try {
      String url = '$baseUrl/alerts/stats';
      if (deviceId != null) url += '?device_id=$deviceId';

      final response = await http.get(Uri.parse(url)).timeout(requestTimeout);

      if (response.statusCode == 200) {
        return AlertStats.fromJson(json.decode(response.body));
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<List<LiveTranscript>> getTranscripts(
      {int limit = 100, String? deviceId}) async {
    try {
      String url = '$baseUrl/transcripts?limit=$limit';
      if (deviceId != null) url += '&device_id=$deviceId';

      final response = await http.get(Uri.parse(url)).timeout(requestTimeout);

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        try {
          final data = json.decode(response.body);
          final List list = data['transcripts'] ?? [];
          return list.map((json) => LiveTranscript.fromJson(json)).toList();
        } catch (e) {
          debugPrint('Transcript Parse Error: $e');
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getEmailConfig() async {
    try {
      final response =
          await http.get(Uri.parse('$baseUrl/config')).timeout(requestTimeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getRules() async {
    if (isOfflineMode) {
      return [
        {
          'id': 'profanity',
          'title': 'Profanity Filter',
          'isEnabled': true,
          'category': 'Content Filtering'
        },
        {
          'id': 'nudity',
          'title': 'Sensitive Content',
          'isEnabled': true,
          'category': 'Content Filtering'
        },
      ];
    }

    try {
      final response =
          await http.get(Uri.parse('$baseUrl/rules')).timeout(requestTimeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['rules']);
      }
    } catch (e) {
      debugPrint('Get Rules Error: $e');
    }
    return [];
  }

  Future<bool> updateRule(String ruleId, bool isEnabled) async {
    if (isOfflineMode) return true;

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/rules'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'id': ruleId, 'isEnabled': isEnabled}),
          )
          .timeout(requestTimeout);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateEmailConfig({
    required String receiverEmail,
  }) async {
    if (isOfflineMode) return true;

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/config'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'email_to': receiverEmail,
            }),
          )
          .timeout(requestTimeout);

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> syncState() async {
    final status = await getStatus();
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }

    if (status.running) {
      startPolling();
    } else {
      stopPolling();
    }
  }

  void startPolling({String? deviceId}) {
    stopPolling();
    _setupSocket(deviceId);

    _pollingTimer = Timer.periodic(pollingInterval, (_) async {
      await checkHealth();

      if (!_isServerHealthy) return;

      final alerts = await getAlerts(deviceId: deviceId);
      if (!_alertsController.isClosed) _alertsController.add(alerts);

      final transcripts = await getTranscripts(deviceId: deviceId);
      if (!_transcriptsController.isClosed) {
        _transcriptsController.add(transcripts);
      }

      final status = await getStatus(deviceId: deviceId);
      if (!_statusController.isClosed) _statusController.add(status);

      final stats = await getAlertStats(deviceId: deviceId);
      if (stats != null && !_statsController.isClosed) {
        _statsController.add(stats);
        _cacheStats(stats);
      }

      final logs = await getLogs(deviceId: deviceId);
      if (!_logsController.isClosed) _logsController.add(logs);
    });

    checkHealth().then((healthy) {
      if (healthy) {
        getAlerts(deviceId: deviceId).then((alerts) {
          if (!_alertsController.isClosed) _alertsController.add(alerts);
        });
        getTranscripts(deviceId: deviceId).then((transcripts) {
          if (!_transcriptsController.isClosed) {
            _transcriptsController.add(transcripts);
          }
        });
        getStatus(deviceId: deviceId).then((status) {
          if (!_statusController.isClosed) _statusController.add(status);
        });
        getAlertStats(deviceId: deviceId).then((stats) {
          if (stats != null && !_statsController.isClosed) {
            _statsController.add(stats);
          }
        });
        getLogs(deviceId: deviceId).then((logs) {
          if (!_logsController.isClosed) _logsController.add(logs);
        });
      } else {
        _loadCachedStats();
      }
    });
  }

  Future<void> _cacheStats(AlertStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'cached_alert_stats',
        jsonEncode({
          'total': stats.total,
          'high_confidence': stats.highConfidence,
          'by_source': stats.bySource,
          'by_type': stats.byType,
          'cached_at': DateTime.now().toIso8601String(),
        }));
  }

  Future<void> _loadCachedStats() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cached_alert_stats');
    if (cached != null) {
      _statsController.add(AlertStats.fromJson(jsonDecode(cached)));
    }
  }

  void _setupSocket(String? deviceId) {
    if (isOfflineMode) return;

    final serverUrl = baseUrl.replaceAll('/api', '');

    if (_socket != null) {
      _socket!.disconnect();
    }

    _socket = io.io(
        serverUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .build());

    _socket!.onConnect((_) {
      if (kDebugMode) {
        print('Socket connected to \$serverUrl');
      }
      if (deviceId != null) {
        _socket!.emit('join', {'device_id': deviceId});
      }
    });

    _socket!.on('status_update', (data) {
      if (kDebugMode) {
        print('Socket status_update rx: \$data');
      }
      if (data != null && data['running'] != null) {
        syncState(); // This gets the latest status and triggers polling appropriately
      }
    });

    _socket!.connect();
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _socket?.disconnect();
  }

  void dispose() {
    stopPolling();
    _socket?.dispose();
    _connectionController.close();
    _alertsController.close();
    _transcriptsController.close();
    _statusController.close();
    _statsController.close();
    _logsController.close();
  }
}
