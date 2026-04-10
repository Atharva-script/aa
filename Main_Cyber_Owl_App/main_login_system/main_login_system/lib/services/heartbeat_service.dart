import 'dart:async';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class HeartbeatService {
  Timer? _timer;
  String get _baseUrl => AuthService.baseUrl; // Using standard backend URL

  void start() {
    _timer?.cancel();
    _sendHeartbeat(); // Immediate send
    // Send every 30 seconds
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _sendHeartbeat();
    });
  }

  void stop() {
    _timer?.cancel();
  }

  Future<void> _sendHeartbeat() async {
    try {
      await http
          .post(
            Uri.parse('$_baseUrl/pc-client/heartbeat'),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      // Silently fail - network might be down, normal behavior
      print('Heartbeat failed: $e');
    }
  }
}
