import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mindtrack/pages/home_pages.dart';
import 'package:mindtrack/pages/profile_page.dart';
import 'package:mindtrack/pages/screen_time.dart';
import 'package:mindtrack/pages/settings_page.dart';
import 'package:mindtrack/pages/unlock_count.dart';
import 'package:mindtrack/pages/register_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' as dotenv;
import 'dart:developer' as developer;
import 'package:mindtrack/utils/debug_helper.dart';
import 'package:mindtrack/services/theme_service.dart';

void main() async {
  // Add a try-catch block to handle any initialization errors
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Print a debug message to show we're starting initialization
    DebugHelper.log("Starting app initialization");
    
    // Try to load the .env file, but don't fail if it doesn't exist
    try {
      // Specify asset path if loading from assets
      await dotenv.dotenv.load(fileName: ".env");
      DebugHelper.log("Env file loaded successfully");
    } catch (e) {
      DebugHelper.error("Failed to load .env file", e);
      // Continue anyway - we'll handle the API key missing later
    }
    
    // Initialize Hive
    await Hive.initFlutter();
    DebugHelper.log("Hive initialized successfully");
    
    // Ensure boxes are properly initialized
    await Future.wait([
      Hive.openBox('user_data'),
      Hive.openBox('mood_data'),
      Hive.openBox('app_settings'),
    ]);
    DebugHelper.log("Hive boxes opened successfully");
    
    runApp(const MyApp());
  } catch (e, stackTrace) {
    developer.log("Error during initialization: $e\n$stackTrace", name: "MindTrack");
    // Run a minimal error reporting app if initialization fails
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 48),
                  SizedBox(height: 16),
                  Text(
                    'Failed to initialize app',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      // Force app restart
                      SystemNavigator.pop();
                    },
                    child: Text('Close App'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;
  bool _isLoading = true;
  bool _isRegistered = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Load user registration status
      final userBox = Hive.box('user_data');
      final isRegistered = userBox.get('isRegistered', defaultValue: false);
      
      // Load theme mode
      final themeMode = await ThemeService.getThemeMode();
      
      if (mounted) {
        setState(() {
          _isRegistered = isRegistered;
          _themeMode = themeMode;
          _isLoading = false;
        });
      }
      
      DebugHelper.log("User registered status: $_isRegistered");
      DebugHelper.log("Theme mode: ${_themeMode == ThemeMode.dark ? 'dark' : 'light'}");
    } catch (e, stackTrace) {
      DebugHelper.error("Error initializing app", e, stackTrace);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Update theme mode
  void _updateThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // Show loading screen while initializing
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: ThemeService.primaryLight,
          body: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }
  
    try {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: _themeMode,
        theme: ThemeService.getLightTheme(),
        darkTheme: ThemeService.getDarkTheme(),
        home: _isRegistered ? const HomePage() : const RegisterPage(),
        routes: {
          '/screen-time': (context) => ScreenTimePage(
                platform: const MethodChannel('com.example.screen_time_tracker/screen_time'),
              ),
          '/unlock-count': (context) => UnlockCountPage(
                platform: const MethodChannel('com.example.screen_time_tracker/screen_time'),
              ),
          '/profile': (context) => const ProfilePage(),
          '/settings': (context) => SettingsPage(
                onThemeChanged: _updateThemeMode,
              ),
        },
      );
    } catch (e, stackTrace) {
      // Handle any errors during Hive access
      DebugHelper.error("Error accessing Hive boxes", e, stackTrace);
      
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Error accessing app data',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Force app restart
                    SystemNavigator.pop();
                  },
                  child: Text('Restart App'),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}