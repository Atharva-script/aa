import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'device_info_helper.dart';

class AuthService {
  // Production Backend URL (Change this to your VPS IP or Domain)
  static String baseUrl = 'https://backend.cyberowll.in/api';

  static void setBaseUrl(String ipAddress) {
    if (ipAddress.startsWith('http')) {
      baseUrl = ipAddress.endsWith('/api') ? ipAddress : '$ipAddress/api';
    } else {
      baseUrl = 'https://$ipAddress';
    }
  }

  static Future<void> loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('custom_base_url');
    
    if (savedUrl != null && savedUrl.isNotEmpty) {
      setBaseUrl(savedUrl);
    } else if (Platform.isWindows) {
      // On Windows, the PC app is bundled with the local backend.
      // We unconditionally set the base URL to localhost to allow BackendMonitor
      // to retry connecting while the ML models load (which takes >500ms).
      print('🚀 [AuthService] Windows Platform detected. Defaulting to local backend on port 5000.');
      baseUrl = 'http://127.0.0.1:5000/api';
    }
  }

  static Future<void> saveBaseUrl(String ipAddress) async {
    final prefs = await SharedPreferences.getInstance();
    if (ipAddress.isEmpty) {
      await prefs.remove('custom_base_url');
      baseUrl = 'http://127.0.0.1:5000/api'; // reset to default
    } else {
      await prefs.setString('custom_base_url', ipAddress);
      setBaseUrl(ipAddress);
    }
  }

  // In-memory token for current session (persists even if Remember Me is false)
  static String? _sessionToken;
  static Map<String, dynamic>? _currentUser;

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    params: const GoogleSignInParams(
      clientId:
          '727101598680-suvrhiu65tl5a9lq4s32ls4spf4u34ck.apps.googleusercontent.com',
      clientSecret:
          'GOCSPX-MASKED-FOR-GITHUB-PUSH', // Masked for security. Replace with your actual secret.
      scopes: ['email', 'profile'],
    ),
  );

  static bool isOfflineMode = false;

  // Machine-specific remember me storage key
  static const String _machineRememberMeKey = 'machine_remember_me';

  /// Set machine-specific remember me preference
  static Future<void> setMachineRememberMe(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_machineRememberMeKey, enabled);
  }

  /// Get machine-specific remember me preference (defaults to false)
  static Future<bool> getMachineRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_machineRememberMeKey) ?? false;
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    String? secretCode,
    bool rememberMe = false,
  }) async {
    if (isOfflineMode) {
      // Mock login for offline mode
      _sessionToken = 'mock_offline_token';
      return {
        'access_token': 'mock_offline_token',
        'user': {'email': email, 'name': 'Test User'}
      };
    }

    final ip = await DeviceInfoHelper.getLocalIpAddress();
    final mac = await DeviceInfoHelper.getMacAddress();
    final hostname = await DeviceInfoHelper.getHostname();

    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'secret': secretCode, // The param name in Dart is secretCode
        'secret_code': secretCode, // Backend expects secret_code
        'ip_address': ip,
        'mac_address': mac,
        'hostname': hostname,
        'device_name': hostname,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['access_token'];

      // Always cache in memory for this session
      _sessionToken = token;
      _currentUser = data['user'];

      print('🔐 [AuthService] Login successful, rememberMe=$rememberMe');

      // If rememberMe is true, save the token locally and enable machine remember me
      if (rememberMe) {
        print(
            '🔐 [AuthService] Saving user and setting machine remember me...');
        await saveUser(token, data['user']);
        await setMachineRememberMe(true); // Save machine-specific preference
        print('🔐 [AuthService] ✓ Machine remember me saved!');
      } else {
        print('🔐 [AuthService] rememberMe is false, not saving preference');
        await clearUser();
        // Re-set in-memory because clearUser wipes it
        _currentUser = data['user'];
        _sessionToken = token;
      }
      return data;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Login failed');
    }
  }

  // Google Sign In - Step 1: Get Details
  static Future<Map<String, dynamic>?> getGoogleUserDetails() async {
    if (isOfflineMode) {
      await Future.delayed(const Duration(seconds: 1));
      return {
        'email': 'google_user@example.com',
        'google_id': 'mock_google_id',
        'name': 'Google User',
        'photo_url': null
      };
    }

    try {
      await _googleSignIn.signOut(); // Force account picker
      final credentials = await _googleSignIn.signIn();
      if (credentials == null) {
        throw Exception('Google Sign In Aborted');
      }

      String? email;
      String? googleId;
      String? name;
      String? photoUrl;

      if (credentials.idToken != null && credentials.idToken!.isNotEmpty) {
        try {
          final payload = _parseJwt(credentials.idToken!);
          email = payload['email'];
          googleId = payload['sub'];
          name = payload['name'];
          photoUrl = payload['picture'];
        } catch (e) {
          print('Failed to decode ID token: $e');
        }
      }

      if (email == null) {
        throw Exception(
            'Could not retrieve user details from Google ID Token.');
      }

      return {
        'email': email,
        'google_id': googleId ?? '',
        'name': name ?? '',
        'photo_url': photoUrl ?? '',
      };
    } catch (e) {
      throw Exception('Google Sign In Error: $e');
    }
  }

  // Google Sign In - Step 2: Finalise with Secret Code
  static Future<Map<String, dynamic>> finaliseGoogleAuth({
    required String email,
    required String googleId,
    required String name,
    required String photoUrl,
    required String secretCode,
    bool isRegister = false,
    bool rememberMe = false,
  }) async {
    if (isOfflineMode) {
      _sessionToken = 'mock-google-token';
      // Mock for offline
      final mockUser = {'email': email, 'name': name, 'profile_pic': photoUrl};
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _sessionToken!);
      await prefs.setString('user_data', jsonEncode(mockUser));
      if (rememberMe) {
        await setMachineRememberMe(true);
      }
      return {'message': 'Google Login Success (Offline)', 'user': mockUser};
    }

    try {
      // Get device info for tracking
      final ip = await DeviceInfoHelper.getLocalIpAddress();
      final mac = await DeviceInfoHelper.getMacAddress();
      final hostname = await DeviceInfoHelper.getHostname();

      final response = await http.post(
        Uri.parse('$baseUrl/google-auth'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'google_id': googleId,
          'name': name,
          'photo_url': photoUrl,
          'secret_code': secretCode,
          'is_register': isRegister,
          'ip_address': ip,
          'mac_address': mac,
          'hostname': hostname,
          'device_name': hostname,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _sessionToken = data['access_token'];

        // Use user data from backend, or construct from Google details as fallback
        _currentUser = data['user'] ??
            {
              'email': email,
              'name': name,
              'photo_url': photoUrl,
              'profile_pic': photoUrl,
            };

        print(
            '🔐 [AuthService] Google auth successful, rememberMe=$rememberMe');
        print('🔐 [AuthService] User data: $_currentUser');

        if (_sessionToken != null) {
          // Clear old user cache before saving new user
          await clearAllUserCache();

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', _sessionToken!);
          await prefs.setString('user_data', jsonEncode(_currentUser));

          if (rememberMe) {
            print(
                '🔐 [AuthService] Saving machine remember me for Google auth...');
            await setMachineRememberMe(true);
            print(
                '🔐 [AuthService] ✓ Machine remember me saved for Google auth!');
          }
        }
        return data;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(
            error['error'] ?? error['detail'] ?? 'Google Auth Failed');
      }
    } catch (e) {
      throw Exception('Google Auth Error: $e');
    }
  }

  static Map<String, dynamic> _parseJwt(String token) {
    if (token.isEmpty) return {};
    final parts = token.split('.');
    if (parts.length != 3) {
      return {};
    }
    final payload = _decodeBase64(parts[1]);
    final payloadMap = json.decode(payload);
    if (payloadMap is! Map<String, dynamic>) {
      return {};
    }
    return payloadMap;
  }

  static String _decodeBase64(String str) {
    String output = str.replaceAll('-', '+').replaceAll('_', '/');
    switch (output.length % 4) {
      case 0:
        break;
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
      default:
        throw Exception('Illegal base64url string!"');
    }
    return utf8.decode(base64Url.decode(output));
  }

  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String country,
    required String age,
    required String parentEmail,
    required String secretCode,
  }) async {
    // Strict Registration via dedicated endpoint
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'secret_code': secretCode,
        'name': name,
        'phone': phone,
        'country': country,
        'age': age,
        'parent_email': parentEmail,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['access_token'];

      // Always cache in memory
      _sessionToken = token;

      await saveUser(token, data['user']);
      return {'message': 'User registered successfully', ...data};
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Registration failed');
    }
  }

  // --- Account Management ---

  static Future<void> deleteAccount(String secretCode) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.delete(
      Uri.parse('$baseUrl/user/delete'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'secret_code': secretCode}),
    );

    if (response.statusCode == 200) {
      await clearUser();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to delete account');
    }
  }

  // --- Helper Methods ---

  static Future<void> saveUser(String token,
      [Map<String, dynamic>? userData]) async {
    // Clear old cached data before saving new user (ensures data isolation)
    await clearAllUserCache();

    _sessionToken = token;
    _currentUser = userData; // Update memory
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    if (userData != null) {
      prefs.setString('user_data', jsonEncode(userData));
    }
  }

  /// Clear all user-specific cached data (for logout or new login)
  static Future<void> clearAllUserCache() async {
    final prefs = await SharedPreferences.getInstance();
    // Clear all user-specific cached data
    await prefs.remove('cached_alert_stats');
    await prefs.remove('theme_value');
    print('🧹 [AuthService] Cleared all user-specific cache');
  }

  static Future<void> clearUser() async {
    _sessionToken = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
    await prefs
        .remove(_machineRememberMeKey); // Clear machine remember me on logout
    // Also clear all user-specific cached data
    await clearAllUserCache();
  }

  static Future<Map<String, dynamic>?> getLocalUser() async {
    if (_currentUser != null) return _currentUser;
    final prefs = await SharedPreferences.getInstance();
    final dataString = prefs.getString('user_data');
    if (dataString != null) {
      _currentUser = jsonDecode(dataString); // Sync back to memory
      return _currentUser;
    }
    return null;
  }

  static Future<String?> getToken() async {
    if (_sessionToken != null) return _sessionToken;
    final prefs = await SharedPreferences.getInstance();
    _sessionToken = prefs.getString('auth_token');
    return _sessionToken;
  }

  static Future<Map<String, dynamic>> getCurrentUser(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final user = data['user'] ?? data;

      // Update local cache and memory sync
      await saveUser(token, user);

      return user;
    } else {
      final error = jsonDecode(response.body);
      print('DEBUG: /me error: $error'); // Added Debug Log
      throw Exception(error['detail'] ?? 'Failed to get user');
    }
  }

  static Future<Map<String, dynamic>> updateProfile(
    String token,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/user/update'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Update failed');
    }
  }

  static Future<void> updateTheme(double themeValue) async {
    final token = await getToken();
    if (token == null) return;
    try {
      await updateProfile(token, {'theme_value': themeValue});
    } catch (e) {
      print('Failed to sync theme to DB: $e');
    }
  }

  static Future<Map<String, dynamic>> uploadProfilePhoto(
    String token,
    String filePath,
  ) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/user/upload-photo'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Photo upload failed');
    }
  }

  static Future<List<dynamic>> getDetections(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/detections/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to get detections');
    }
  }

  static Future<void> logout(String token) async {
    await clearUser(); // Clear local token
    try {
      await http.post(
        Uri.parse('$baseUrl/logout'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
    } catch (e) {
      // Ignore network errors on logout, just ensure local cleanup
    }
  }

  static Future<void> requestPasswordReset(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/forgot-password/request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to request OTP');
    }
  }

  static Future<void> confirmPasswordReset({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'otp': otp,
        'new_password': newPassword,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to reset password');
    }
  }

  // --- Secret Code Management ---

  static Future<void> requestSecretCodeReset(String email) async {
    if (isOfflineMode) return; // Mock success

    final response = await http.post(
      Uri.parse('$baseUrl/forgot-code/request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to request OTP');
    }
  }

  static Future<void> confirmSecretCodeReset({
    required String email,
    required String otp,
    required String newCode,
  }) async {
    if (isOfflineMode) return; // Mock success

    final response = await http.post(
      Uri.parse('$baseUrl/forgot-code/reset'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'otp': otp,
        'new_secret_code': newCode,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to reset secret code');
    }
  }

  static Future<void> changeSecretCode({
    required String email,
    required String oldCode,
    required String newCode,
  }) async {
    if (isOfflineMode) return; // Mock success

    final response = await http.post(
      Uri.parse('$baseUrl/change-secret-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'old_code': oldCode,
        'new_code': newCode,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to change secret code');
    }
  }

  static Future<Map<String, dynamic>> getSecretCodeSchedule() async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/secret-code/schedule'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to get schedule');
    }
  }

  static Future<Map<String, dynamic>> createVerifyRequest({
    required String email,
    required String deviceInfo,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/verify-request'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'device_info': deviceInfo,
            }),
          )
          .timeout(const Duration(seconds: 5)); // Fast timeout

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        // Special case for Biometric disabled
        if (error['code'] == 'BIO_DISABLED') {
          throw Exception('BIO_DISABLED');
        }
        throw Exception(error['error'] ?? 'Verification request failed');
      }
    } catch (e) {
      if (e.toString().contains('BIO_DISABLED')) rethrow;
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> checkRequestStatus(
      String requestId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/request-status?request_id=$requestId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5)); // Fast timeout for auth polling

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to check status');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Check if biometric verification is required
  static Future<Map<String, dynamic>> checkAuthStatus(String email) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/check-status?email=$email'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        // Fallback for safety: assume false if endpoint fails?
        // Or throw error?
        // Let's return a safe default to avoid blocking login if server issues
        return {
          'exists': false,
          'requires_biometric': false,
          'parent_registered': false
        };
      }
    } catch (e) {
      print('Check status error: $e');
      return {
        'exists': false,
        'requires_biometric': false,
        'parent_registered': false
      };
    }
  }

  static Future<void> setSecretCodeSchedule({
    required String frequency,
    required String rotationTime,
    required int dayOfWeek,
    required bool isActive,
  }) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/secret-code/schedule'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'frequency': frequency,
        'rotation_time': rotationTime,
        'day_of_week': dayOfWeek,
        'is_active': isActive,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to update schedule');
    }
  }
}
