class BackendService {
  static final BackendService _instance = BackendService._internal();

  factory BackendService() => _instance;

  BackendService._internal();

  // The backend is now strictly expected to be running externally on port 5000
  static const int _backendPort = 5000;

  int get port => _backendPort;

  // Dummy getter to maintain interface compatibility if needed transiently
  int? get pid => null;

  Future<void> dispose() async {
    // No cleanup needed
  }
}
