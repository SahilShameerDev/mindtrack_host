import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeService {
  static const String _boxName = 'app_settings';
  static const String _darkModeKey = 'is_dark_mode';

  // Light theme colors
  static const Color primaryLight = Color(0xC4FF4000); // #FF4000 with 77% alpha
  static const Color secondaryLight = Color(0xA8FE8C00); // #FE8C00 with 66% alpha
  
  // Dark theme colors - darker versions of the same colors
  static const Color primaryDark = Color(0xC4D93600); // Darker orange
  static const Color secondaryDark = Color(0xA8D87700); // Darker amber

  // Get the theme mode from storage
  static Future<ThemeMode> getThemeMode() async {
    final box = await Hive.openBox(_boxName);
    final isDarkMode = box.get(_darkModeKey, defaultValue: false);
    return isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  // Toggle the theme mode
  static Future<ThemeMode> toggleThemeMode() async {
    final box = await Hive.openBox(_boxName);
    final isDarkMode = box.get(_darkModeKey, defaultValue: false);
    await box.put(_darkModeKey, !isDarkMode);
    return !isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  // Check if dark mode is enabled
  static Future<bool> isDarkMode() async {
    final box = await Hive.openBox(_boxName);
    return box.get(_darkModeKey, defaultValue: false);
  }

  // Get light theme data
  static ThemeData getLightTheme() {
    return ThemeData(
      primaryColor: primaryLight,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.light(
        primary: primaryLight,
        secondary: secondaryLight,
        background: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryLight,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white),
      ),
      iconTheme: IconThemeData(color: Colors.black),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: Colors.black),
        bodyMedium: TextStyle(color: Colors.black),
        bodySmall: TextStyle(color: Colors.black),
      ),
      cardColor: secondaryLight,
      fontFamily: 'Inter',
    );
  }
  
  // Get dark theme data
  static ThemeData getDarkTheme() {
    return ThemeData(
      primaryColor: primaryDark,
      scaffoldBackgroundColor: Color(0xFF121212),
      colorScheme: ColorScheme.dark(
        primary: primaryDark,
        secondary: secondaryDark,
        background: Color(0xFF121212),
        surface: Color(0xFF1E1E1E),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryDark,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white),
      ),
      iconTheme: IconThemeData(color: Colors.white),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white),
        bodySmall: TextStyle(color: Colors.white),
      ),
      cardColor: Color(0xFF2C2C2C),
      fontFamily: 'Inter',
    );
  }
}
