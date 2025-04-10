import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:mindtrack/utils/debug_helper.dart';
import 'dart:io';

class ConnectionChecker {
  // Update URLs to include the hosted backend
  static const String _hostedBackendUrl = 'https://mindtrack-backend.onrender.com/health';
  static const String _emulatorBackendUrl = 'http://10.0.2.2:5000/health';  // For emulator (fallback)
  static const String _localBackendUrl = 'http://127.0.0.1:5000/health';    // For local testing (fallback)
  static const String _pcNetworkUrl = 'http://192.168.1.41:5000/health';    // PC's actual IP (fallback)

  /// Check if the device has an internet connection
  static Future<bool> hasConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Check if the backend server is reachable
  /// Returns the working URL, or null if neither works
  static Future<String?> checkBackendConnection() async {
    DebugHelper.log("Checking backend connection...");
    
    // Create a combined future that returns the first successful result
    List<Future<String?>> connectionAttempts = [
      _checkUrl(_hostedBackendUrl),      // Try hosted URL first
      _checkUrl(_pcNetworkUrl),          // Then try PC's actual IP (for physical device)
      _checkUrl(_emulatorBackendUrl),    // Then try emulator address
      _checkUrl(_localBackendUrl),       // Finally try localhost
    ];
    
    try {
      // Try all URLs simultaneously and take the first successful one
      return await Future.any(connectionAttempts)
        .timeout(const Duration(seconds: 5), onTimeout: () {
          DebugHelper.log("All connection attempts timed out");
          return null;
        });
    } catch (e) {
      DebugHelper.error("Error checking connection", e);
      return null;
    }
  }
  
  static Future<String?> _checkUrl(String url) async {
    try {
      DebugHelper.log("Trying to connect to: $url");
      final response = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final baseUrl = url.substring(0, url.lastIndexOf('/'));
        DebugHelper.log("Connection successful to $baseUrl");
        return baseUrl;
      }
    } catch (e) {
      // Just log and return null - we'll try other URLs
      DebugHelper.log("Failed to connect to $url: $e");
    }
    
    return null;
  }
  
  /// Checks the status of the AI service
  static Future<bool> isAIServiceAvailable(String baseUrl) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final body = response.body;
        return body.contains('"ai_status":"active"');
      }
    } catch (e) {
      DebugHelper.log("Error checking AI service: $e");
    }
    
    return false;
  }
}
