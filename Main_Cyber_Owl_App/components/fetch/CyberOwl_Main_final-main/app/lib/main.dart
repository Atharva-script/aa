import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import 'screens/splash_screen.dart';
import 'services/app_lifecycle_manager.dart';
import 'theme/app_theme.dart';
import 'theme/theme_manager.dart';
import 'services/abuse_detection_service.dart';
import 'theme/app_colors.dart';
import 'services/heartbeat_service.dart';
import 'services/auth_service.dart';

// Global flag for stealth mode (launched remotely from mobile app)
bool isStealthMode = false;

// Dart-define constant for stealth mode (set via flutter run --dart-define=STEALTH_MODE=true)
const bool _dartDefineStealthMode =
    bool.fromEnvironment('STEALTH_MODE', defaultValue: false);

Future<bool> _checkStealthModeFile() async {
  // Check for stealth marker file created by backend when launching remotely
  const stealthFilePath =
      r'd:\final_year\Main_Cyber_Owl_App\main_login_system\main_login_system\.stealth_mode';
  debugPrint('🔍 Checking for stealth file at: $stealthFilePath');
  final stealthFile = File(stealthFilePath);
  final exists = await stealthFile.exists();
  debugPrint('🔍 Stealth file exists: $exists');
  if (exists) {
    // Read the timestamp from the file to confirm it's recent
    try {
      final content = await stealthFile.readAsString();
      debugPrint('🔒 Stealth file content (timestamp): $content');
    } catch (e) {
      debugPrint('🔒 Could not read stealth file content: $e');
    }

    // Delete the file after a longer delay so the splash screen has time to process
    Future.delayed(const Duration(seconds: 10), () async {
      try {
        if (await stealthFile.exists()) {
          await stealthFile.delete();
          debugPrint('🔒 Stealth marker file deleted after 10 second delay');
        }
      } catch (e) {
        debugPrint('Error deleting stealth file: $e');
      }
    });
    debugPrint('🔒 STEALTH FILE FOUND - Will bypass login');
    return true;
  }
  return false;
}

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // Check for stealth mode via: 1) command-line, 2) dart-define, 3) marker file
  debugPrint(
      '🔍 Checking stealth mode - args: $args, dartDefine: $_dartDefineStealthMode');
  final fileBasedStealth = await _checkStealthModeFile();
  isStealthMode =
      args.contains('--stealth') || _dartDefineStealthMode || fileBasedStealth;
  debugPrint('🔒 isStealthMode final value: $isStealthMode');
  if (isStealthMode) {
    debugPrint('🔒 STEALTH MODE ACTIVE - Bypassing login screen');
  }

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 720),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    // Explicitly prevent close so onWindowClose is triggered properly
    await windowManager.setPreventClose(true);
  });

  // Ensure theme is loaded before showing UI
  await themeManager.init();
  await AuthService.loadBaseUrl();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WindowListener {
  final SystemTray _systemTray = SystemTray();
  final Menu _menuMain = Menu();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final HeartbeatService _heartbeatService = HeartbeatService();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initSystemTray();
    _heartbeatService.start();
  }

  @override
  void dispose() {
    _heartbeatService.stop();
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _initSystemTray() async {
    String iconPath;
    try {
      if (Platform.isWindows) {
        final directory = await getTemporaryDirectory();
        iconPath = '${directory.path}/app_icon.ico';
        final File tmpFile = File(iconPath);
        if (!await tmpFile.exists()) {
          final ByteData data = await rootBundle.load('assets/app_icon.ico');
          await tmpFile.writeAsBytes(data.buffer.asUint8List());
        }
      } else {
        iconPath = 'assets/app_icon.png';
      }

      await _systemTray.initSystemTray(
        title: "Cyber Owl",
        iconPath: iconPath,
      );

      await _menuMain.buildFrom([
        MenuItemLabel(
            label: 'Show', onClicked: (menuItem) => windowManager.show()),
        MenuItemLabel(
            label: 'Exit', onClicked: (menuItem) => _handleSecureExit()),
      ]);

      _systemTray.setContextMenu(_menuMain);

      _systemTray.registerSystemTrayEventHandler((eventName) {
        debugPrint("eventName: $eventName");
        if (eventName == kSystemTrayEventClick) {
          Platform.isWindows
              ? windowManager.show()
              : _systemTray.popUpContextMenu();
        } else if (eventName == kSystemTrayEventRightClick) {
          Platform.isWindows
              ? _systemTray.popUpContextMenu()
              : windowManager.show();
        }
      });
    } catch (e) {
      debugPrint('System Tray Init Error: $e');
    }
  }

  Future<void> _handleSecureExit() async {
    await windowManager.show(); // Bring to front

    final detectionService = AbuseDetectionService();
    final status = await detectionService.getStatus();

    if (status.running) {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        _showSecureExitDialog(context, detectionService);
      }
    } else {
      await windowManager.destroy();
      exit(0);
    }
  }

  void _showSecureExitDialog(
      BuildContext context, AbuseDetectionService detectionService) {
    final secretCodeController = TextEditingController();
    bool isProcessing = false;

    // Capture theme value for local dialog
    final t = themeManager.themeValue;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.getSurface(t),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(FluentIcons.shield_24_regular, color: AppColors.errorDark),
              SizedBox(width: 10),
              Text('Secure Exit via Tray',
                  style: TextStyle(color: AppColors.errorDark)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Live Monitoring is active. You must enter your Secret Code to force exit.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: secretCodeController,
                obscureText: true,
                style: TextStyle(color: AppColors.getTextPrimary(t)),
                decoration: const InputDecoration(
                  labelText: 'Secret Code',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(FluentIcons.lock_closed_24_regular),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed:
                  isProcessing ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isProcessing
                  ? null
                  : () async {
                      if (secretCodeController.text.isEmpty) return;
                      setState(() => isProcessing = true);

                      // Verify code
                      final result = await detectionService.stopMonitoring(
                          secretCode: secretCodeController.text,
                          reason:
                              'logout' // Treat tray exit as logout for alert purposes
                          );

                      if (result['success'] == true) {
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          await windowManager.destroy();
                          exit(0);
                        }
                      } else {
                        setState(() => isProcessing = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    result['error'] ?? 'Invalid Secret Code')),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorDark,
                foregroundColor: Colors.white,
              ),
              child: isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Exit App'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void onWindowClose() async {
    await windowManager.hide();
  }

  @override
  Widget build(BuildContext context) {
    return AppLifecycleManager(
      child: AnimatedBuilder(
        animation: themeManager,
        builder: (context, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Cyber Owl',
            debugShowCheckedModeBanner: false,
            // Always use light mode to force 'theme' usage, but 'theme' itself is dynamic
            themeMode: ThemeMode.light,
            theme: AppTheme.getTheme(themeManager.themeValue),

            // Transitions handled by AnimatedBuilder+lerp, but keep standard for other routes
            themeAnimationDuration: const Duration(milliseconds: 300),
            themeAnimationCurve: Curves.easeInOut,

            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
