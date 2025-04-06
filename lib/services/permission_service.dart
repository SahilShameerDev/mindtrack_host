import 'package:flutter/services.dart';
import 'dart:developer' as developer;

class PermissionService {
  static const platform = MethodChannel('com.example.screen_time_tracker/screen_time');

  // Check if usage stats permission is granted
  static Future<bool> hasUsageStatsPermission() async {
    try {
      final bool hasPermission = await platform.invokeMethod('checkUsageStatsPermission');
      developer.log("Permission check result: $hasPermission", name: "PermissionService");
      return hasPermission;
    } on PlatformException catch (e) {
      developer.log("Failed to check usage stats permission: ${e.message}", name: "PermissionService");
      return false;
    }
  }

  // Open usage stats settings page
  static Future<void> openUsageStatsSettings() async {
    try {
      developer.log("Attempting to open usage stats settings", name: "PermissionService");
      await platform.invokeMethod('openUsageStatsSettings');
      developer.log("Settings opened successfully", name: "PermissionService");
    } on PlatformException catch (e) {
      developer.log("Failed to open usage stats settings: ${e.message}", name: "PermissionService", error: e);
      throw e; // Rethrow the exception so the UI can handle it
    }
  }
}
