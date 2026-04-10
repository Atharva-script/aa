import 'dart:io';

class DeviceInfoHelper {
  static Future<String?> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (var interface in interfaces) {
        // Filter loopback
        if (interface.name.toLowerCase().contains('loopback')) continue;

        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
      return null;
    } catch (e) {
      print('Error getting IP: $e');
      return null;
    }
  }

  static Future<String> getHostname() async {
    try {
      return Platform.localHostname;
    } catch (e) {
      print('Error getting hostname: $e');
      return 'Unknown';
    }
  }

  static Future<String?> getMacAddress() async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('getmac', ['/fo', 'csv', '/nh']);
        if (result.exitCode == 0) {
          // Output format: "00-11-22-33-44-55","Device Name"
          final parts = result.stdout.toString().split(',');
          if (parts.isNotEmpty) {
            final mac = parts[0].replaceAll('"', '').trim();
            // Simple validation
            if (mac.length >= 17 && mac.contains('-')) {
              return mac;
            }
          }
        }
      }
      return null;
    } catch (e) {
      print('Error getting MAC: $e');
      return null;
    }
  }
}
