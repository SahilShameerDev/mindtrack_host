import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mindtrack/pages/home_pages.dart';
import 'package:mindtrack/pages/profile_page.dart';
import 'package:mindtrack/pages/screen_time.dart';
import 'package:mindtrack/pages/unlock_count.dart';
import 'package:mindtrack/pages/register_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' as dotenv;
import 'dart:developer' as developer;
import 'package:mindtrack/utils/debug_helper.dart';

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Since we already opened the box in main(), we can directly access it here
    try {
      final userBox = Hive.box('user_data');
      final isRegistered = userBox.get('isRegistered', defaultValue: false);
      DebugHelper.log("User registered status: $isRegistered");
      
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: Color.fromARGB(192, 255, 64, 0),
          colorScheme: ColorScheme.light(
            primary: Color.fromARGB(192, 255, 64, 0),
            secondary: Color.fromARGB(168, 254, 140, 0),
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: Color.fromARGB(192, 255, 64, 0),
            elevation: 0,
          ),
          fontFamily: 'Inter',
        ),
        home: isRegistered ? const HomePage() : const RegisterPage(),
        routes: {
          '/screen-time': (context) => ScreenTimePage(
                platform: const MethodChannel('com.example.screen_time_tracker/screen_time'),
              ),
          '/unlock-count': (context) => UnlockCountPage(
                platform: const MethodChannel('com.example.screen_time_tracker/screen_time'),
              ),
          '/profile': (context) => const ProfilePage(),
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