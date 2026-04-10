import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';

class ServerDiscoveryService {
  static const int udpPort = 50000;
  static const Duration timeout = Duration(seconds: 2);

  /// Discover the Cyber Owl server on the local network
  static Future<Map<String, dynamic>?> discoverServer() async {
    RawDatagramSocket? socket;
    try {
      debugPrint('🔍 [Discovery] Starting UDP Broadcast on port $udpPort...');

      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final completer = Completer<Map<String, dynamic>?>();

      // Listen for response
      final subscription = socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket?.receive();
          if (datagram != null) {
            try {
              final message = utf8.decode(datagram.data);
              debugPrint('📩 [Discovery] Received: $message');
              final json = jsonDecode(message);

              if (json['service'] == 'CyberOwl' && json['ip'] != null) {
                if (!completer.isCompleted) {
                  debugPrint('✅ [Discovery] Server found at ${json['ip']}');
                  completer.complete(json);
                }
              }
            } catch (e) {
              debugPrint('⚠️ [Discovery] Malformed packet: $e');
            }
          }
        }
      });

      // Send Broadcast Message multiple times
      int attempts = 0;
      const maxAttempts = 3;

      while (attempts < maxAttempts && !completer.isCompleted) {
        attempts++;
        debugPrint(
            '📡 [Discovery] Sending broadcast attempt $attempts/$maxAttempts...');

        try {
          final data = utf8.encode('DISCOVER_CYBER_OWL_SERVER');
          socket.send(data, InternetAddress('255.255.255.255'), udpPort);
        } catch (e) {
          debugPrint('⚠️ [Discovery] Send failed: $e');
        }

        // Wait for response or next attempt
        await Future.any([
          completer.future,
          Future.delayed(const Duration(milliseconds: 1500))
        ]);

        if (completer.isCompleted) break;
      }

      if (!completer.isCompleted) {
        debugPrint(
            '❌ [Discovery] Timeout - No server found after $maxAttempts attempts.');
        completer.complete(null);
      }

      final result = await completer.future;
      await subscription.cancel();
      return result;
    } catch (e) {
      debugPrint('❌ [Discovery] Error: $e');
      return null;
    } finally {
      socket?.close();
    }
  }
}
