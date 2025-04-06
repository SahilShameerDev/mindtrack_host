import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ApiService {
  // Update the base URL to use the hosted endpoint
  static const String _baseUrl = 'https://mindtrack-backend.onrender.com';
  static const String _cachedTipsKey = 'cached_gemini_tips';
  static const String _lastFetchTimeKey = 'last_gemini_tips_fetch_time';
  static const Duration _cacheDuration = Duration(hours: 3);

  // Get Gemini-generated tips with 3-hour caching
  static Future<List<String>> getGeminiTips({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if we have cached tips and if they're still valid
    if (!forceRefresh) {
      final lastFetchTimeString = prefs.getString(_lastFetchTimeKey);
      final cachedTipsString = prefs.getString(_cachedTipsKey);
      
      if (lastFetchTimeString != null && cachedTipsString != null) {
        final lastFetchTime = DateTime.parse(lastFetchTimeString);
        final currentTime = DateTime.now();
        
        // Check if cache is still valid (less than 3 hours old)
        if (currentTime.difference(lastFetchTime) < _cacheDuration) {
          print('Using cached Gemini tips');
          
          try {
            final List<dynamic> decodedTips = json.decode(cachedTipsString);
            return decodedTips.map((tip) => tip.toString()).toList();
          } catch (e) {
            print('Error parsing cached tips: $e');
            // If parsing fails, continue to fetch new tips
          }
        }
      }
    }
    
    // If we reach here, either there's no cache, it's expired, or parsing failed
    // So make a new API call
    print('Fetching fresh Gemini tips from $_baseUrl');
    try {
      // Get user data from Hive
      final moodBox = Hive.box('mood_data');
      final userBox = Hive.box('user_data');
      
      // Get the current day name to fetch today's mood
      final now = DateTime.now();
      final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      final today = days[now.weekday - 1]; // weekday is 1-7, array is 0-based
      
      // Build weekly moods map
      final Map<String, dynamic> weeklyMoods = Map<String, int>.from(
          moodBox.get('weekly_moods', defaultValue: {
            'Monday': 0, 'Tuesday': 0, 'Wednesday': 0, 
            'Thursday': 0, 'Friday': 0, 'Saturday': 0, 'Sunday': 0
          }));
      
      // Get mood description for today
      final String moodDescription = moodBox.get('mood_description_$today', defaultValue: '');
      
      // Get screen time and unlock count from user data
      final String screenTime = userBox.get('screen_time', defaultValue: '240m');
      final String unlockCount = userBox.get('unlock_count', defaultValue: '50');
      final String mostUsedApp = userBox.get('most_used_app', defaultValue: 'Unknown');
      
      // Get anxiety and stress levels
      final int anxietyLevel = weeklyMoods[today] ?? 5;
      final int stressLevel = userBox.get('stress_level', defaultValue: 5);
      
      final response = await http.post(
        Uri.parse('$_baseUrl/get_gemini_tips'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'anxiety_level': anxietyLevel,
          'stress_level': stressLevel,
          'screen_time': screenTime,
          'unlock_count': unlockCount,
          'most_used_app': mostUsedApp,
          'mood_description': moodDescription,
          'weekly_moods': weeklyMoods,
        }),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success']) {
          final List<dynamic> tips = data['tips'];
          final tipsList = tips.map((tip) => tip.toString()).toList();
          
          // Save the new tips to cache
          prefs.setString(_cachedTipsKey, json.encode(tipsList));
          prefs.setString(_lastFetchTimeKey, DateTime.now().toIso8601String());
          
          return tipsList;
        } else {
          print('API returned error: ${data['error'] ?? 'Unknown error'}');
          throw Exception('Failed to get tips from API');
        }
      } else {
        print('Error status code: ${response.statusCode}');
        throw Exception('Failed to communicate with API');
      }
    } catch (e) {
      print('Error fetching Gemini tips: $e');
      
      // If we have a cached version, return that as a fallback
      final cachedTipsString = prefs.getString(_cachedTipsKey);
      if (cachedTipsString != null) {
        try {
          final List<dynamic> decodedTips = json.decode(cachedTipsString);
          return decodedTips.map((tip) => tip.toString()).toList();
        } catch (e) {
          print('Error parsing cached tips during error fallback: $e');
        }
      }
      
      // If all else fails, return default tips
      return [
        'Take regular breaks from your screen every 30 minutes.',
        'Practice deep breathing exercises when feeling stressed.',
        'Set boundaries for your device usage, especially before bedtime.'
      ];
    }
  }

  // Get last fetch time formatted for display
  static Future<String> getLastTipsFetchTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastFetchTimeString = prefs.getString(_lastFetchTimeKey);
    
    if (lastFetchTimeString != null) {
      final lastFetchTime = DateTime.parse(lastFetchTimeString);
      final currentTime = DateTime.now();
      final difference = currentTime.difference(lastFetchTime);
      
      if (difference.inMinutes < 60) {
        return '${difference.inMinutes} minutes ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} hours ago';
      } else {
        final formatter = DateFormat('MMM d, h:mm a');
        return formatter.format(lastFetchTime);
      }
    }
    
    return 'Never';
  }

  // Check if tips cache is expired
  static Future<bool> isTipsCacheExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final lastFetchTimeString = prefs.getString(_lastFetchTimeKey);
    
    if (lastFetchTimeString != null) {
      final lastFetchTime = DateTime.parse(lastFetchTimeString);
      final currentTime = DateTime.now();
      return currentTime.difference(lastFetchTime) >= _cacheDuration;
    }
    
    return true; // If no last fetch time, consider it expired
  }
  
  // Clear the tips cache
  static Future<void> clearTipsCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cachedTipsKey);
    await prefs.remove(_lastFetchTimeKey);
  }
}