import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

import '../utils/constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _authToken;
  String? _userEmail;

  // Getters
  String? get authToken => _authToken;
  String? get userEmail => _userEmail;
  bool get isAuthenticated => _authToken != null;

  // Set auth data
  void setAuth(String token, String email) {
    _authToken = token;
    _userEmail = email;
  }

  // Clear auth
  void clearAuth() {
    _authToken = null;
    _userEmail = null;
  }

  // Helper to ensure URL is set
  void _checkUrl() {
    if (AppConstants.apiBaseUrl.isEmpty) {
      throw Exception(
          'Server URL not set. Please wait for discovery or enter IP manually.');
    }
  }

  // Base HTTP headers
  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  // Health check (returns boolean)
  Future<bool> healthCheck() async {
    _checkUrl();
    try {
      final response = await http
          .get(Uri.parse(
              '${AppConstants.apiBaseUrl}${AppConstants.healthEndpoint}'))
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Health check failed: $e');
      return false;
    }
  }

  // Get health info at any URL (for connection testing)
  Future<Map<String, dynamic>?> getHealthInfoAtUrl(String serverUrl) async {
    try {
      final response = await http
          .get(Uri.parse('$serverUrl${AppConstants.healthEndpoint}'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get full health info including laptop status
  Future<Map<String, dynamic>?> getHealthInfo() async {
    _checkUrl();
    try {
      final response = await http
          .get(Uri.parse(
              '${AppConstants.apiBaseUrl}${AppConstants.healthEndpoint}'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Get health info failed: $e');
      return null;
    }
  }

  // Get full system status (PC Machine and PC App)
  Future<Map<String, dynamic>?> getSystemStatus() async {
    _checkUrl();
    try {
      final response = await http
          .get(Uri.parse(
              '${AppConstants.apiBaseUrl}${AppConstants.systemStatusEndpoint}'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      // debugPrint('Get system status failed: $e'); // Fail silently on frequent poll
      return null;
    }
  }

  // Get system status at a specific server URL (for multi-child support)
  Future<Map<String, dynamic>?> getSystemStatusAtUrl(String serverUrl) async {
    try {
      final response = await http
          .get(Uri.parse('$serverUrl${AppConstants.systemStatusEndpoint}'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Launch PC App Remotely (just launch, no auto-login)
  Future<bool> launchPcApp({String? childEmail}) async {
    try {
      final response = await http
          .post(
            Uri.parse(
                '${AppConstants.apiBaseUrl}${AppConstants.launchPcAppEndpoint}'),
            headers: _headers,
            body: jsonEncode({
              if (childEmail != null) 'email': childEmail,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Launch PC App failed: $e');
      return false;
    }
  }

  // Request PC App Launch via Backend (mediated through central DB)
  Future<bool> requestLaunch(String childEmail) async {
    try {
      final response = await http
          .post(
            Uri.parse(
                '${AppConstants.apiBaseUrl}${AppConstants.requestLaunchEndpoint}'),
            headers: _headers,
            body: jsonEncode({
              'email': childEmail,
            }),
          )
          .timeout(const Duration(seconds: 15));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Request Launch failed: $e');
      return false;
    }
  }

  // Launch PC App at a specific server URL (for multi-child support)
  Future<bool> launchPcAppAtUrl(String serverUrl, {String? childEmail}) async {
    try {
      final response = await http
          .post(
            Uri.parse('$serverUrl${AppConstants.launchPcAppEndpoint}'),
            headers: _headers,
            body: jsonEncode({
              if (childEmail != null) 'email': childEmail,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Launch PC App at $serverUrl failed: $e');
      return false;
    }
  }

  // Bypass Sign-In for already-running PC App
  Future<bool> bypassSignIn() async {
    try {
      final response = await http
          .post(
            Uri.parse(
                '${AppConstants.apiBaseUrl}${AppConstants.bypassSignInEndpoint}'),
            headers: _headers,
            body: jsonEncode({
              'email': _userEmail,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Bypass Sign-In failed: $e');
      return false;
    }
  }

  // Login
  // Login
  Future<Map<String, dynamic>> login(
      String email, String password, String secretCode) async {
    _checkUrl();
    try {
      final response = await http
          .post(
            Uri.parse(
                '${AppConstants.apiBaseUrl}${AppConstants.loginEndpoint}'),
            headers: _headers,
            body: jsonEncode({
              'email': email,
              'password': password,
              'secret_code': secretCode,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['access_token'] != null) {
        final token = data['access_token'];
        setAuth(token, email);
        return {
          'success': true,
          'data': {'token': token, 'access_token': token}
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? data['message'] ?? 'Login failed'
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Connection timed out. Server might be offline.'
      };
    } catch (e) {
      debugPrint('Login error: $e');
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Google Login
  Future<Map<String, dynamic>> googleLogin({
    required String? email,
    required String? googleId,
    String? idToken,
    String? accessToken,
    String? name,
    String? photoUrl,
    String? secretCode,
  }) async {
    if (email == null ||
        email.isEmpty ||
        googleId == null ||
        googleId.isEmpty) {
      return {'success': false, 'error': 'Email and Google ID are required'};
    }

    _checkUrl();
    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.apiBaseUrl}/api/google-auth'),
            headers: _headers,
            body: jsonEncode({
              'email': email,
              'google_id': googleId,
              'name': name,
              'photo_url': photoUrl,
              'secret_code': secretCode,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['access_token'] != null) {
        final token = data['access_token'];
        setAuth(token, email);
        return {
          'success': true,
          'data': {'token': token, 'access_token': token}
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Google Login failed'
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Connection timed out. Server might be offline.'
      };
    } catch (e) {
      debugPrint('Google Login error: $e');
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Get monitoring status
  Future<Map<String, dynamic>?> getStatus({String? childEmail}) async {
    try {
      String url = '${AppConstants.apiBaseUrl}${AppConstants.statusEndpoint}';
      if (childEmail != null) {
        url += '?child_email=$childEmail';
      }

      final response = await http
          .get(
            Uri.parse(url),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Get status error: $e');
      return null;
    }
  }

  // Start monitoring
  Future<Map<String, dynamic>> startMonitoring(String childEmail) async {
    try {
      final response = await http
          .post(
            Uri.parse(
                '${AppConstants.apiBaseUrl}${AppConstants.startEndpoint}'),
            headers: _headers,
            body: jsonEncode({'child_email': childEmail}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? data['error'] ?? 'Unknown response',
      };
    } catch (e) {
      debugPrint('Start monitoring error: $e');
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Stop monitoring
  Future<Map<String, dynamic>> stopMonitoring(String secretCode,
      {String? childEmail, String? reason}) async {
    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.apiBaseUrl}${AppConstants.stopEndpoint}'),
            headers: _headers,
            body: jsonEncode({
              'secret_code': secretCode,
              if (childEmail != null) 'child_email': childEmail,
              'reason': reason,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? data['error'] ?? 'Unknown response',
      };
    } catch (e) {
      debugPrint('Stop monitoring error: $e');
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get alerts
  Future<Map<String, dynamic>?> getAlerts(
      {int limit = 50, String? childEmail}) async {
    try {
      String url =
          '${AppConstants.apiBaseUrl}${AppConstants.alertsEndpoint}?limit=$limit';
      if (childEmail != null) {
        url += '&child_email=$childEmail';
      }

      final response = await http
          .get(
            Uri.parse(url),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Get alerts error: $e');
      return null;
    }
  }

  // Get alert stats
  Future<Map<String, dynamic>?> getAlertStats({String? childEmail}) async {
    try {
      String url =
          '${AppConstants.apiBaseUrl}${AppConstants.alertStatsEndpoint}';
      if (childEmail != null) {
        url += '?child_email=$childEmail';
      }

      final response = await http
          .get(
            Uri.parse(url),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Get stats error: $e');
      return null;
    }
  }

  // Clear alerts
  Future<bool> clearAlerts() async {
    try {
      final response = await http
          .post(
            Uri.parse(
                '${AppConstants.apiBaseUrl}${AppConstants.clearAlertsEndpoint}'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Clear alerts error: $e');
      return false;
    }
  }

  // Get analytics
  Future<Map<String, dynamic>?> getAnalytics({String? childEmail}) async {
    try {
      String url =
          '${AppConstants.apiBaseUrl}${AppConstants.analyticsEndpoint}';
      if (childEmail != null) {
        url += '?child_email=$childEmail';
      }

      final response = await http
          .get(
            Uri.parse(url),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Get analytics error: $e');
      return null;
    }
  }

  // Get config
  Future<Map<String, dynamic>?> getConfig() async {
    try {
      final response = await http
          .get(
            Uri.parse(
                '${AppConstants.apiBaseUrl}${AppConstants.configEndpoint}'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Get config error: $e');
      return null;
    }
  }

  // Update config
  Future<bool> updateConfig(Map<String, dynamic> config) async {
    try {
      final response = await http
          .post(
            Uri.parse(
                '${AppConstants.apiBaseUrl}${AppConstants.configEndpoint}'),
            headers: _headers,
            body: jsonEncode(config),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Update config error: $e');
      return false;
    }
  }

  // Get User Profile
  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final response = await http
          .get(
            Uri.parse(
                '${AppConstants.apiBaseUrl}${AppConstants.userProfileEndpoint}'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Get profile error: $e');
      return null;
    }
  }

  // Update User Profile
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await http
          .put(
            Uri.parse(
                '${AppConstants.apiBaseUrl}${AppConstants.userUpdateEndpoint}'),
            headers: _headers,
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 15));

      final responseData = jsonDecode(response.body);

      return {
        'success': response.statusCode == 200,
        'message': responseData['message'] ??
            responseData['error'] ??
            'Unknown response',
        'user': responseData['user']
      };
    } catch (e) {
      debugPrint('Update profile error: $e');
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Upload Profile Photo
  Future<Map<String, dynamic>> uploadProfilePhoto(File file) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(
            '${AppConstants.apiBaseUrl}${AppConstants.uploadPhotoEndpoint}'),
      );

      // Add Headers
      request.headers.addAll(_headers);

      // Add File
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
      ));

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
          'photo_url': data['photo_url']
        };
      } else {
        return {'success': false, 'message': data['error'] ?? 'Upload failed'};
      }
    } catch (e) {
      debugPrint('Upload photo error: $e');
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get Secret Code Schedule
  Future<Map<String, dynamic>?> getSecretCodeSchedule() async {
    try {
      final response = await http
          .get(
            Uri.parse(
                '${AppConstants.apiBaseUrl}${AppConstants.secretCodeScheduleEndpoint}'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Get schedule error: $e');
      return null;
    }
  }

  // Update Secret Code Schedule
  Future<bool> updateSecretCodeSchedule(Map<String, dynamic> schedule) async {
    try {
      final response = await http
          .post(
            Uri.parse(
                '${AppConstants.apiBaseUrl}${AppConstants.secretCodeScheduleEndpoint}'),
            headers: _headers,
            body: jsonEncode(schedule),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Update schedule error: $e');
      return false;
    }
  }

  // Toggle Biometric
  Future<bool> toggleBiometric(bool enabled) async {
    try {
      final response = await http
          .post(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/api/user/biometric-toggle'), // Hardcoded path or add to constant
            headers: _headers,
            body: jsonEncode({
              'email': _userEmail,
              'enabled': enabled,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      return response.statusCode == 200 && data['success'] == true;
    } catch (e) {
      debugPrint('Toggle biometric error: $e');
      return false;
    }
  }

  // Get Pending Verification Requests
  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    try {
      final response = await http
          .get(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/api/auth/pending-requests?email=$_userEmail'),
            headers: _headers,
          )
          .timeout(
              const Duration(seconds: 5)); // Fast timeout for auth requests

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['requests'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      }
      return [];
    } catch (e) {
      // debugPrint('Get pending requests error: $e');
      return [];
    }
  }

  // Get Parent's Children (PCs)
  static Future<List<dynamic>?> getParentChildren(String parentEmail) async {
    try {
      final response = await http
          .get(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/api/parent/children?email=$parentEmail'),
            headers: _instance._headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['children'] ?? [];
      }
      return null;
    } catch (e) {
      debugPrint('Get parent children error: $e');
      return null;
    }
  }

  // Get Parent's Notifications (Unified for all children or specific child)
  static Future<List<dynamic>?> getParentNotifications(String parentEmail,
      {String? childEmail, int limit = 50}) async {
    try {
      String url =
          '${AppConstants.apiBaseUrl}/api/parent/notifications?email=$parentEmail&limit=$limit';
      if (childEmail != null) {
        url += '&child_email=$childEmail';
      }

      final response = await http
          .get(
            Uri.parse(url),
            headers: _instance._headers,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['notifications'] ?? [];
      }
      return null;
    } catch (e) {
      debugPrint('Get parent notifications error: $e');
      return null;
    }
  }

  // Unlink Child Account
  static Future<bool> unlinkChildAccount(
      String parentEmail, String childEmail) async {
    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.apiBaseUrl}/api/parent/children/unlink'),
            headers: _instance._headers,
            body: jsonEncode({
              'parent_email': parentEmail,
              'child_email': childEmail,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Unlink child error: $e');
      rethrow;
    }
  }

  // Approve Request
  Future<bool> approveRequest(String requestId, String status) async {
    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.apiBaseUrl}/api/auth/approve-request'),
            headers: _headers,
            body: jsonEncode({
              'request_id': requestId,
              'status': status,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Approve request error: $e');
      return false;
    }
  }
}
