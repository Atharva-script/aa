import 'package:flutter/material.dart';
import 'backend_monitor.dart';

class AppLifecycleManager extends StatefulWidget {
  final Widget child;

  const AppLifecycleManager({super.key, required this.child});

  @override
  State<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<AppLifecycleManager>
    with WidgetsBindingObserver {
  // Kept for consistency if needed, but not used for shutdown anymore
  final BackendMonitor _backendMonitor = BackendMonitor();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Removed _checkAndShutdown call - managing backend is external now
    _backendMonitor.shutdown(); // Stop internal health timers only
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No action needed on lifecycle changes for external backend
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
