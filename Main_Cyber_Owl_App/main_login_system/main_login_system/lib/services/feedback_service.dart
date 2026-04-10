import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class FeedbackService {
  static String get baseUrl => AuthService.baseUrl;

  static Future<void> submitFeedback(String message, double rating) async {
    final token = await AuthService.getToken();
    if (token == null) {
      throw Exception('User not logged in');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/feedback'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'message': message,
        'rating': rating,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to submit feedback');
    }
  }
}
