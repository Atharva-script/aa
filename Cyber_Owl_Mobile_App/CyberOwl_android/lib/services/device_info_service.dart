import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class DeviceInfoService {
  static Future<String> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLoopback: false);
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback && addr.address.startsWith('192.168.')) {
            return addr.address;
          }
        }
      }
      // Fallback
      if (interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty) {
        return interfaces.first.addresses.first.address;
      }
    } catch (e) {
      debugPrint('Failed to get IP address: $e');
    }
    return 'Unknown';
  }

  static Future<String> getDeviceName() async {
    return Platform.localHostname;
  }

  static Future<void> updateDeviceTelemetry(String email) async {
    try {
      final ip = await getLocalIpAddress();
      final name = await getDeviceName();

      // Upsert into Supabase devices table
      // To effectively upsert based on user_email + device_type + device_name,
      // Supabase supports `upsert` but we can also just update if exists, else insert

      try {
        final existing = await Supabase.instance.client
            .from('devices')
            .select()
            .eq('user_email', email)
            .eq('device_type', 'mobile')
            .eq('device_name', name)
            .maybeSingle()
            .timeout(const Duration(seconds: 5)); // Added timeout

        if (existing != null) {
          await Supabase.instance.client
              .from('devices')
              .update({
                'ip_address': ip,
                'last_seen': DateTime.now().toIso8601String(),
                'status': 'online',
              })
              .eq('id', existing['id'])
              .timeout(const Duration(seconds: 5));
        } else {
          await Supabase.instance.client.from('devices').insert({
            'user_email': email,
            'device_type': 'mobile',
            'device_name': name,
            'ip_address': ip,
            'last_seen': DateTime.now().toIso8601String(),
            'status': 'online',
          }).timeout(const Duration(seconds: 5));
        }
        debugPrint('Telemetry updated - IP: $ip, Name: $name');
      } catch (e) {
        debugPrint(
            'Failed to update device telemetry to Supabase (Network issue?): $e');
        // Do not rethrow, just let the app continue locally
      }
    } catch (e) {
      debugPrint('Failed to gather device telemetry: $e');
    }
  }
}
