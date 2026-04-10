import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;

  // Stream controllers for different event types
  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  final _alertController = StreamController<Map<String, dynamic>>.broadcast();
  final _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Getters for streams
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;
  Stream<Map<String, dynamic>> get alertStream => _alertController.stream;
  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationController.stream;

  bool get isConnected => _isConnected;

  void init(String serverUrl, {String? userEmail}) {
    if (_socket != null && _socket!.connected) return;

    disconnect(); // Ensure clean state

    debugPrint('🔌 Connecting to Socket.IO at $serverUrl');

    _socket = IO.io(
        serverUrl,
        IO.OptionBuilder()
            .setTransports(['websocket']) // for Flutter or Web
            .disableAutoConnect() // disable auto-connection
            .setExtraHeaders({'origin': '*'}) // optional
            .build());

    _socket!.connect();

    _socket!.onConnect((_) {
      debugPrint('✅ Socket Connected');
      _isConnected = true;

      // Join user-specific room if email provided
      if (userEmail != null) {
        joinUserRoom(userEmail);
      }
    });

    _socket!.onDisconnect((_) {
      debugPrint('❌ Socket Disconnected');
      _isConnected = false;
    });

    _socket!.on('status', (data) {
      if (data != null && data is Map<String, dynamic>) {
        _statusController.add(data);
      }
    });

    _socket!.on('status_update', (data) {
      debugPrint('🔄 Received Status Update via Socket: $data');
      if (data != null && data is Map<String, dynamic>) {
        _statusController.add(data);
      }
    });

    _socket!.on('alert', (data) {
      debugPrint('🚨 Received Alert via Socket: $data');
      if (data != null && data is Map<String, dynamic>) {
        _alertController.add(data);
      }
    });

    _socket!.on('notification', (data) {
      debugPrint('🔔 Received Notification via Socket: $data');
      if (data != null && data is Map<String, dynamic>) {
        _notificationController.add(data);
      }
    });
  }

  void joinUserRoom(String email) {
    if (_socket != null && _socket!.connected) {
      debugPrint('🔌 Joining room for user: $email');
      _socket!.emit('join', {'email': email});
    }
  }

  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
      _isConnected = false;
    }
  }
}
