import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Dashboard Analytics Models and Service
/// Provides enhanced analytics data for the premium dashboard

class DashboardAnalytics {
  final int totalDetections;
  final int nudityCount;
  final int abuseCount;
  final double avgConfidence;
  final double threatLevel;
  final List<int> detectionTrend;
  final List<int> nudityTrend;
  final List<int> abuseTrend;
  final List<double> accuracyTrend;
  final Map<String, double> categoryBreakdown;
  final Map<String, int> sourceBreakdown;
  final List<SeverityItem> severityGrid;
  final bool isMonitoring;

  DashboardAnalytics({
    required this.totalDetections,
    required this.nudityCount,
    required this.abuseCount,
    required this.avgConfidence,
    required this.threatLevel,
    required this.detectionTrend,
    required this.nudityTrend,
    required this.abuseTrend,
    required this.accuracyTrend,
    required this.categoryBreakdown,
    required this.sourceBreakdown,
    required this.severityGrid,
    required this.isMonitoring,
  });

  factory DashboardAnalytics.fromJson(Map<String, dynamic> json) {
    return DashboardAnalytics(
      totalDetections: json['total_detections'] ?? 0,
      nudityCount: json['nudity_count'] ?? 0,
      abuseCount: json['abuse_count'] ?? 0,
      avgConfidence: (json['avg_confidence'] ?? 0.0).toDouble(),
      threatLevel: (json['threat_level'] ?? 0.0).toDouble(),
      detectionTrend: List<int>.from(json['detection_trend'] ?? []),
      nudityTrend: List<int>.from(json['nudity_trend'] ?? []),
      abuseTrend: List<int>.from(json['abuse_trend'] ?? []),
      accuracyTrend: (json['accuracy_trend'] as List?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      categoryBreakdown: Map<String, double>.from(
        (json['category_breakdown'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
            ) ??
            {},
      ),
      sourceBreakdown: Map<String, int>.from(
        (json['source_breakdown'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()),
            ) ??
            {},
      ),
      severityGrid: (json['severity_grid'] as List?)
              ?.map((e) => SeverityItem.fromJson(e))
              .toList() ??
          [],
      isMonitoring: json['is_monitoring'] ?? false,
    );
  }

  factory DashboardAnalytics.empty() {
    return DashboardAnalytics(
      totalDetections: 0,
      nudityCount: 0,
      abuseCount: 0,
      avgConfidence: 0,
      threatLevel: 0,
      detectionTrend: List.filled(12, 0),
      nudityTrend: List.filled(12, 0),
      abuseTrend: List.filled(12, 0),
      accuracyTrend: List.filled(12, 0.0),
      categoryBreakdown: {'nudity': 0, 'abuse': 0},
      sourceBreakdown: {},
      severityGrid: [],
      isMonitoring: false,
    );
  }
}

class SeverityItem {
  final double score;
  final String label;
  final String timestamp;

  SeverityItem({
    required this.score,
    required this.label,
    required this.timestamp,
  });

  factory SeverityItem.fromJson(Map<String, dynamic> json) {
    return SeverityItem(
      score: (json['score'] ?? 0.0).toDouble(),
      label: json['label'] ?? 'unknown',
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class HourlyData {
  final String hour;
  final int hourIndex;
  final int abuseCount;
  final int nudityCount;
  final int totalCount;
  final double avgScore;

  HourlyData({
    required this.hour,
    required this.hourIndex,
    required this.abuseCount,
    required this.nudityCount,
    required this.totalCount,
    required this.avgScore,
  });

  factory HourlyData.fromJson(Map<String, dynamic> json) {
    return HourlyData(
      hour: json['hour'] ?? '',
      hourIndex: json['hour_index'] ?? 0,
      abuseCount: json['abuse_count'] ?? 0,
      nudityCount: json['nudity_count'] ?? 0,
      totalCount: json['total_count'] ?? 0,
      avgScore: (json['avg_score'] ?? 0.0).toDouble(),
    );
  }
}

class TimelineData {
  final List<HourlyData> timeline;
  final int totalRecords;

  TimelineData({
    required this.timeline,
    required this.totalRecords,
  });

  factory TimelineData.fromJson(Map<String, dynamic> json) {
    return TimelineData(
      timeline: (json['timeline'] as List?)
              ?.map((e) => HourlyData.fromJson(e))
              .toList() ??
          [],
      totalRecords: json['total_records'] ?? 0,
    );
  }

  factory TimelineData.empty() {
    return TimelineData(timeline: [], totalRecords: 0);
  }
}

class HeatmapData {
  final List<List<int>> heatmap;
  final List<List<int>> rawHeatmap;
  final List<String> dayLabels;
  final int maxValue;

  HeatmapData({
    required this.heatmap,
    required this.rawHeatmap,
    required this.dayLabels,
    required this.maxValue,
  });

  factory HeatmapData.fromJson(Map<String, dynamic> json) {
    return HeatmapData(
      heatmap: (json['heatmap'] as List?)
              ?.map((row) => List<int>.from(row))
              .toList() ??
          [],
      rawHeatmap: (json['raw_heatmap'] as List?)
              ?.map((row) => List<int>.from(row))
              .toList() ??
          [],
      dayLabels: List<String>.from(json['day_labels'] ?? []),
      maxValue: json['max_value'] ?? 0,
    );
  }

  factory HeatmapData.empty() {
    return HeatmapData(
      heatmap: List.generate(7, (_) => List.filled(24, 0)),
      rawHeatmap: List.generate(7, (_) => List.filled(24, 0)),
      dayLabels: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
      maxValue: 0,
    );
  }
}

/// Service for fetching dashboard analytics
class DashboardAnalyticsService {
  static final DashboardAnalyticsService _instance =
      DashboardAnalyticsService._internal();
  factory DashboardAnalyticsService() => _instance;
  DashboardAnalyticsService._internal();

  String get baseUrl => AuthService.baseUrl;
  static const Duration requestTimeout = Duration(seconds: 5);

  Timer? _pollingTimer;

  final StreamController<DashboardAnalytics> _analyticsController =
      StreamController<DashboardAnalytics>.broadcast();
  final StreamController<TimelineData> _timelineController =
      StreamController<TimelineData>.broadcast();
  final StreamController<HeatmapData> _heatmapController =
      StreamController<HeatmapData>.broadcast();

  Stream<DashboardAnalytics> get analyticsStream => _analyticsController.stream;
  Stream<TimelineData> get timelineStream => _timelineController.stream;
  Stream<HeatmapData> get heatmapStream => _heatmapController.stream;

  Future<DashboardAnalytics> fetchAnalytics({String? deviceId}) async {
    try {
      String url = '$baseUrl/analytics/overview';
      if (deviceId != null) url += '?device_id=$deviceId';

      final token = await AuthService.getToken();
      final headers = {
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final analytics = DashboardAnalytics.fromJson(data);
        if (!_analyticsController.isClosed) {
          _analyticsController.add(analytics);
        }
        return analytics;
      }
    } catch (e) {
      debugPrint('Error fetching analytics overview: $e');
    }
    return DashboardAnalytics.empty();
  }

  /// Fetch timeline data
  Future<TimelineData> fetchTimeline({String? deviceId}) async {
    try {
      String url = '$baseUrl/analytics/timeline';
      if (deviceId != null) url += '?device_id=$deviceId';

      final token = await AuthService.getToken();
      final headers = {
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final timeline = TimelineData.fromJson(data);
        if (!_timelineController.isClosed) {
          _timelineController.add(timeline);
        }
        return timeline;
      }
    } catch (e) {
      debugPrint('Error fetching timeline data: $e');
    }
    return TimelineData.empty();
  }

  /// Fetch heatmap data
  Future<HeatmapData> fetchHeatmap({String? deviceId}) async {
    try {
      String url = '$baseUrl/analytics/heatmap';
      if (deviceId != null) url += '?device_id=$deviceId';

      final token = await AuthService.getToken();
      final headers = {
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final heatmap = HeatmapData.fromJson(data);
        if (!_heatmapController.isClosed) {
          _heatmapController.add(heatmap);
        }
        return heatmap;
      }
    } catch (e) {
      debugPrint('Error fetching heatmap data: $e');
    }
    return HeatmapData.empty();
  }

  /// Start polling all analytics data
  void startPolling(
      {Duration interval = const Duration(seconds: 3), String? deviceId}) {
    stopPolling();

    // Initial fetch
    fetchAnalytics(deviceId: deviceId);
    fetchTimeline(deviceId: deviceId);
    fetchHeatmap(deviceId: deviceId);

    _pollingTimer = Timer.periodic(interval, (_) {
      fetchAnalytics(deviceId: deviceId);
      fetchTimeline(deviceId: deviceId);
      fetchHeatmap(deviceId: deviceId);
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void dispose() {
    stopPolling();
    _analyticsController.close();
    _timelineController.close();
    _heatmapController.close();
  }
}
