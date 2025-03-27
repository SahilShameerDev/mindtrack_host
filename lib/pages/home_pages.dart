import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mindtrack/pages/profile_page.dart';
import 'package:mindtrack/pages/mental_health_insights_page.dart';
import 'package:mindtrack/utils/connection_checker.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  static const platform = MethodChannel('com.example.screen_time_tracker/screen_time');
  
  // Hive box for storing mood data
  late Box moodBox;
  
  // Map to store day-mood pairs
  Map<String, int> weeklyMoods = {
    'Monday': 0,
    'Tuesday': 0,
    'Wednesday': 0,
    'Thursday': 0, 
    'Friday': 0,
    'Saturday': 0,
    'Sunday': 0
  };

  String _screenTime = 'Loading...';
  String _unlockCount = 'Loading...';
  String _mostUsedApp = 'Loading...';
  int _selectedMoodIndex = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  bool _isDrawerOpen = false;

  // Add these new fields for mood description
  final TextEditingController _moodDescriptionController = TextEditingController();
  String _todayMoodDescription = '';
  bool _isEditing = false;

  // Add these state variables to your class
  List<String> _mentalHealthSuggestions = [];
  bool _isLoadingSuggestions = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _initHive();
    _fetchData();
    _loadMoodDescription();
    _loadMentalHealthSuggestions(); // Add this line
    
    // Start the animation after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _moodDescriptionController.dispose();
    super.dispose();
  }
  
  // Initialize Hive and load saved mood data
  Future<void> _initHive() async {
    moodBox = await Hive.openBox('mood_data');
    _loadMoodData();
  }
  
  // Load saved mood data from Hive
  void _loadMoodData() {
    final savedMoods = moodBox.get('weekly_moods');
    if (savedMoods != null) {
      setState(() {
        weeklyMoods = Map<String, int>.from(savedMoods);
      });
    }
    
    // Get today's selected mood if available
    final today = _getCurrentDayName();
    setState(() {
      _selectedMoodIndex = weeklyMoods[today] ?? 0;
    });
  }
  
  // Load saved mood description from Hive
  Future<void> _loadMoodDescription() async {
    final today = _getCurrentDayName();
    final savedDescription = moodBox.get('mood_description_$today');
    
    if (savedDescription != null) {
      setState(() {
        _todayMoodDescription = savedDescription;
        _moodDescriptionController.text = savedDescription;
      });
    }
  }
  
  // Save mood description to Hive
  Future<void> _saveMoodDescription(String description) async {
    final today = _getCurrentDayName();
    await moodBox.put('mood_description_$today', description);
    
    setState(() {
      _todayMoodDescription = description;
      _isEditing = false;
    });
    
    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mood description saved!'),
        duration: Duration(seconds: 1),
        backgroundColor: Color.fromARGB(255, 255, 100, 0),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
  
  // Use a suggested mood description
  void _useSuggestedMood(String suggestion) {
    _moodDescriptionController.text = suggestion;
    if (!_isEditing) {
      setState(() {
        _isEditing = true;
      });
    } else {
      _saveMoodDescription(suggestion);
    }
  }
  
  // Get current day of week as string
  String _getCurrentDayName() {
    final now = DateTime.now();
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    // DateTime weekday is 1-7 where 1 is Monday, so subtract 1 for zero-indexed array
    return days[now.weekday - 1];
  }
  
  // Save mood for today
  Future<void> _saveMood(int moodIndex) async {
    final today = _getCurrentDayName();
    setState(() {
      _selectedMoodIndex = moodIndex;
      weeklyMoods[today] = moodIndex;
    });
    
    // Save to Hive
    await moodBox.put('weekly_moods', weeklyMoods);
  }

  Future<void> _fetchData() async {
    try {
      // Fetch screen time
      final screenTimeData = await platform.invokeMethod<Map>('getScreenTimeData');
      final totalUsageTime = screenTimeData?['totalUsageTime'] ?? 0;
      setState(() {
        // Convert minutes to hours and minutes format
        if (totalUsageTime < 60) {
          _screenTime = '${totalUsageTime}m';
        } else {
          final hours = (totalUsageTime / 60).floor();
          final minutes = totalUsageTime % 60;
          if (minutes == 0) {
            _screenTime = '${hours}h';
          } else {
            _screenTime = '${hours}h ${minutes}m';
          }
        }
      });

      // Fetch unlock count
      final unlockCountData = await platform.invokeMethod<Map>('getPhoneUnlockCount');
      final totalUnlocks = unlockCountData?['totalUnlocks'] ?? 0;
      setState(() {
        _unlockCount = '$totalUnlocks';
      });

      // Fetch most used app
      final appUsage = screenTimeData?['appUsage'] as List<dynamic>? ?? [];
      if (appUsage.isNotEmpty) {
        final appPackageName = appUsage.first['appName'] ?? 'Unknown';
        
        // Extract clean app name from package name
        final String cleanAppName = _formatAppName(appPackageName);
        
        setState(() {
          _mostUsedApp = cleanAppName;
        });
      } else {
        setState(() {
          _mostUsedApp = 'No data';
        });
      }
    } catch (e) {
      setState(() {
        _screenTime = 'Error';
        _unlockCount = 'Error';
        _mostUsedApp = 'Error';
      });
    }
  }

  bool _isExpanded = false;
  final double _collapsedHeight = 300;
  final double _expandedHeight = 400;

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  // Widget for emoji button with selection indicator and feedback
  Widget _moodEmojiButton(int index, String imagePath, {double size = 60}) {
    final isSelected = _selectedMoodIndex == index;
    
    return GestureDetector(
      onTap: () {
        // Add haptic feedback
        HapticFeedback.mediumImpact();
        
        // Save mood
        _saveMood(index);
        
        // Show feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mood updated!'),
            duration: Duration(seconds: 1),
            backgroundColor: Color.fromARGB(255, 255, 100, 0),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      },
      child: TweenAnimationBuilder(
        duration: Duration(milliseconds: isSelected ? 300 : 0),
        tween: Tween<double>(begin: 1.0, end: isSelected ? 1.2 : 1.0),
        builder: (context, double scale, child) {
          return Transform.scale(
            scale: scale,
            child: Container(
              width: size,
              height: size,
              decoration: isSelected 
                ? BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(size / 2),
                  )
                : null,
              child: Padding(
                padding: isSelected ? const EdgeInsets.all(3.0) : EdgeInsets.zero,
                child: Image.asset(imagePath),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F8F8), // Slightly off-white background for less harsh contrast
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: BouncingScrollPhysics(), // Add smooth scrolling
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                GestureDetector(
                  onVerticalDragEnd: (details) {
                    // If dragged up with significant velocity, collapse the bar
                    if (details.primaryVelocity != null && details.primaryVelocity! < -300) {
                      setState(() {
                        _isExpanded = false;
                      });
                    }
                    // If dragged down with significant velocity, expand the bar
                    else if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
                      setState(() {
                        _isExpanded = true;
                      });
                    }
                  },
                  // Allow tapping anywhere on the bar to toggle
                  onTap: _toggleExpanded,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: Color.fromARGB(192, 255, 64, 0),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(45),
                        bottomRight: Radius.circular(45),
                      ),
                    ),
                    height: _isExpanded ? _expandedHeight : _collapsedHeight,
                    width: double.infinity,
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5), // Prevent overflow
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title Section
                            SizedBox(height: 15),
                            Row(
                              children: [
                                Text(
                                  'Welcome,',
                                  style: TextStyle(
                                    color: Color(0xFFFFFFFF),
                                    fontSize: 24, // Reduced from 30
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                Spacer(),
                                IconButton(
                                  icon: Icon(Icons.menu, color: Color(0xFFFFFFFF)),
                                  onPressed: () => setState(() => _isDrawerOpen = !_isDrawerOpen),
                                ),
                              ],
                            ),
                            Text(
                              'Select Today\'s Mood',
                              style: TextStyle(
                                color: Color(0xFFFFFFFF),
                                fontSize: 16, // Reduced from 20
                                fontWeight: FontWeight.w400,
                                fontFamily: 'Inter',
                              ),
                            ),
                            // First row of Emojis
                            SizedBox(height: 30), // Reduced from 25
                            Row(
                              children: [
                                SizedBox(width: 10),
                                _moodEmojiButton(1, 'lib/icons/1.png', size: 50), // Reduced size
                                SizedBox(width: 30), // Reduced gap
                                _moodEmojiButton(2, 'lib/icons/2.png', size: 50),
                                SizedBox(width: 30),
                                _moodEmojiButton(3, 'lib/icons/3.png', size: 50),
                                SizedBox(width: 30),
                                _moodEmojiButton(4, 'lib/icons/4.png', size: 50),
                              ],
                            ),
                            // Second row of Emojis - Only visible when expanded
                            AnimatedOpacity(
                              opacity: _isExpanded ? 1.0 : 0.0,
                              duration: Duration(milliseconds: 300),
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 300),
                                height: _isExpanded ? 80 : 0,
                                child:
                                    _isExpanded
                                        ? Padding(
                                          padding: const EdgeInsets.only(top: 20),
                                          child: Row(
                                            children: [
                                              SizedBox(width: 10),
                                              _moodEmojiButton(5, 'lib/icons/5.png', size: 50), // Reduced size
                                              SizedBox(width: 30), // Reduced gap
                                              _moodEmojiButton(6, 'lib/icons/6.png', size: 50),
                                              SizedBox(width: 30),
                                              _moodEmojiButton(7, 'lib/icons/7.png', size: 50),
                                              SizedBox(width: 30),
                                              _moodEmojiButton(8, 'lib/icons/8.png', size: 50),
                                            ],
                                          ),
                                        )
                                        : SizedBox(),
                              ),
                            ),
                            Spacer(),
                            // Expand/collapse button
                            Align(
                              alignment: Alignment.center,
                              child: Container(
                                width: 120,
                                height: 5, // Increased from 5 to 8 for better visibility
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                margin: EdgeInsets.only(bottom: 10), // Add margin for larger tap area
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 10),
                // User Mood Description Input
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'How Was Your Day?',
                          style: TextStyle(
                            color: Color(0xFF000000),
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      Container(
                        width: 400, // Reduced from 720
                        constraints: BoxConstraints(
                          minHeight: 50, // Reduced from 60
                        ),
                        decoration: BoxDecoration(
                          color: Color.fromARGB(168, 254, 140, 0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: _isEditing
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _moodDescriptionController,
                                        decoration: InputDecoration(
                                          hintText: 'How are you feeling today?',
                                          hintStyle: TextStyle(color: Colors.white70, fontSize: 14), // Reduced font size
                                          border: InputBorder.none,
                                        ),
                                        style: TextStyle(color: Colors.white, fontSize: 14), // Reduced font size
                                        maxLines: null,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.check, color: Colors.white),
                                      onPressed: () {
                                        _saveMoodDescription(_moodDescriptionController.text);
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.close, color: Colors.white),
                                      onPressed: () {
                                        setState(() {
                                          _moodDescriptionController.text = _todayMoodDescription;
                                          _isEditing = false;
                                        });
                                      },
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: _todayMoodDescription.isEmpty
                                          ? Text(
                                              'Tap to add how you feel today...',
                                              style: TextStyle(color: Colors.white70, fontSize: 14), // Reduced font size
                                            )
                                          : Text(
                                              _todayMoodDescription,
                                              style: TextStyle(color: Colors.white, fontSize: 14), // Reduced font size
                                            ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.edit, color: Colors.white),
                                      onPressed: () {
                                        setState(() {
                                          _isEditing = true;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      SizedBox(height: 20),
                      // User Mood Description Suggestions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _moodSuggestionButton('Feeling Good'),
                          SizedBox(width: 10),
                          _moodSuggestionButton('Not Bad'),
                          SizedBox(width: 10),
                          _moodSuggestionButton('It\'s Okay'),
                        ],
                      ),
                      SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        //Screen Time Card
                        _fadeInWidget(
                          delay: 0.2,
                          child: _animatedCard(
                            width: 140, // Redu3ed from 149
                            height: 110, // Reduced from 131
                            onTap: () {
                              Navigator.pushNamed(context, '/screen-time');
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Text(
                                      'Screen Time',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 12,
                                        fontWeight: FontWeight.normal,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Text(
                                      _screenTime,
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 29,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 40),
                        // Unlock Count Card
                          _fadeInWidget(
                            delay: 0.3,
                            child: _animatedCard(
                              width: 140, // Reduced from 149
                              height: 110, // Reduced from 131
                              onTap: () {
                                Navigator.pushNamed(context, '/unlock-count');
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: Text(
                                        'Unlock Count',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 12,
                                          fontWeight: FontWeight.normal,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: Text(
                                        _unlockCount,
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 29,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                      
                    ],
                  ),
                  
                ),

                //MOST USED APPS
                SizedBox(height: 25),
                _fadeInWidget(
                  delay: 0.4,
                  child: _animatedCard(
                    width: 320, // Reduced from 340
                    height: 110, // Reduced from 120
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Text(
                              'Most used apps',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16, // Reduced from 18
                                fontWeight: FontWeight.w400,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Align(alignment: Alignment.center,
                              child: Text(
                                _mostUsedApp,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w400,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                // Weekly Mood Board
                _fadeInWidget(
                  delay: 0.5,
                  child: _animatedCard(
                    width: 320, // Reduced from 340
                    height: 250, // Reduced from 270
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Weekly Mood Board',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'Inter',
                            ),
                          ),
                          SizedBox(height: 20),
                          Expanded(
                            child: _buildMoodChart(),
                          ),
                          SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildDayMoodColumn('Mon', weeklyMoods['Monday'] ?? 0, emojiSize: 30), // Reduced size
                              SizedBox(width: 10), // Added gap
                              _buildDayMoodColumn('Tue', weeklyMoods['Tuesday'] ?? 0, emojiSize: 30),
                              SizedBox(width: 10),
                              _buildDayMoodColumn('Wed', weeklyMoods['Wednesday'] ?? 0, emojiSize: 30),
                              SizedBox(width: 10),
                              _buildDayMoodColumn('Thu', weeklyMoods['Thursday'] ?? 0, emojiSize: 30),
                              SizedBox(width: 10),
                              _buildDayMoodColumn('Fri', weeklyMoods['Friday'] ?? 0, emojiSize: 30),
                              SizedBox(width: 10),
                              _buildDayMoodColumn('Sat', weeklyMoods['Saturday'] ?? 0, emojiSize: 30),
                              SizedBox(width: 10),
                              _buildDayMoodColumn('Sun', weeklyMoods['Sunday'] ?? 0, emojiSize: 30),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                _fadeInWidget(
                  delay: 0.6,
                  child: _animatedCard(
                    width: 320, // Reduced from 340
                    height: 200, // Reduced from 220
                    onTap: () async {
                      // Get user data from Hive first - this doesn't need to wait for connection check
                      final userBox = Hive.box('user_data');
                      
                      // Prepare the data to send to backend
                      Map<String, dynamic> userData = {
                        'weekly_moods': weeklyMoods,
                        'screen_time': _screenTime,
                        'unlock_count': _unlockCount,
                        'most_used_app': _mostUsedApp,
                        'mood_description': _todayMoodDescription,
                        'profession': userBox.get('profession', defaultValue: 'Not specified'),
                        'gender': userBox.get('gender', defaultValue: 'Not specified'),
                        'age': userBox.get('age', defaultValue: 'Not specified')
                      };
                      
                      // Navigate directly to insights page - it will handle connection internally
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MentalHealthInsightsPage(userData: userData),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Mental Health Suggestions',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400,
                                  fontFamily: 'Inter',
                                ),
                              ),
                              _isLoadingSuggestions 
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : IconButton(
                                    icon: Icon(Icons.refresh, color: Colors.white),
                                    onPressed: _loadMentalHealthSuggestions,
                                  ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Color.fromARGB(255, 255, 255, 255),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: _isLoadingSuggestions
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Color.fromARGB(255, 255, 100, 0),
                                          ),
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'Loading suggestions...',
                                          style: TextStyle(
                                            color: Colors.black54,
                                            fontSize: 14,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: _mentalHealthSuggestions.length,
                                    physics: NeverScrollableScrollPhysics(),
                                    itemBuilder: (context, index) {
                                      return Padding(
                                        padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(top: 3),
                                              child: Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: Color.fromARGB(255, 255, 100, 0),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _mentalHealthSuggestions[index],
                                                style: TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w400,
                                                  fontFamily: 'Inter',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                    
              ],
            ),
          ),
          _buildDrawer(),
          _buildDrawerBackdrop(),
        ],
      ),
    );
  }
  
  // Helper method to build a day column with mood indicator
  Widget _buildDayMoodColumn(String day, int moodIndex, {double emojiSize = 40}) {
    String imagePath = moodIndex > 0 && moodIndex <= 8 
        ? 'lib/icons/$moodIndex.png' 
        : 'lib/icons/empty.png';
    
    // Check if this is today
    final today = _getCurrentDayName().substring(0, 3);
    final isToday = day == today.substring(0, 3);
    
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.all(isToday ? 4 : 0),
      decoration: isToday ? BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ) : null,
      child: Column(
        children: [
          Text(
            day,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
              color: isToday ? Colors.black : null,
            ),
          ),
          SizedBox(height: 8),
          // Animated appearance when mood changes
          AnimatedSwitcher(
            duration: Duration(milliseconds: 500),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return ScaleTransition(
                scale: animation,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            child: Container(
              key: ValueKey<int>(moodIndex),
              width: emojiSize,
              height: emojiSize,
              decoration: isToday ? BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ],
              ) : null,
              child: moodIndex > 0 
                  ? Image.asset(imagePath)
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.white54,
                        shape: BoxShape.circle,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // Add this method to fetch custom tips
  Future<String> _fetchCustomTip() async {
    try {
      // Check internet connection first
      bool hasConnection = await ConnectionChecker.hasConnection();
      if (!hasConnection) {
        return 'No internet connection. Check your connection and try again.';
      }
      
      // Get user data from Hive
      final userBox = Hive.box('user_data');
      
      // Prepare request payload
      Map<String, dynamic> requestData = {
        'anxiety_level': userBox.get('stressLevel', defaultValue: 5),
        'stress_level': weeklyMoods[_getCurrentDayName()] ?? 5,
        'screen_time': _screenTime,
        'unlock_count': _unlockCount,
        // Add any additional data needed by your model
      };
      
      // Make API request
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/get_custom_tip'), // Use 10.0.2.2 for Android emulator
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 10)); // Add a timeout
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return data['tip'];
        } else {
          return 'Failed to get suggestion. Please try again.';
        }
      } else {
        return 'Server error. Please try again later.';
      }
    } catch (e) {
      print('Error fetching custom tip: $e');
      return 'Unable to connect to suggestion service.';
    }
  }

  // Add this method to load suggestions
  Future<void> _loadMentalHealthSuggestions() async {
    if (_isLoadingSuggestions) return; // Prevent multiple simultaneous calls
    
    setState(() {
      _isLoadingSuggestions = true;
    });
    
    try {
      // Fetch a suggestion from custom model
      final tip = await _fetchCustomTip();
      
      // Create a list with the fetched suggestion and some backup ones
      final suggestions = [
        tip,
        'Practice mindfulness or meditation for 10 minutes daily.',
        'Talk to someone you trust about how you feel.',
      ];
      
      setState(() {
        _mentalHealthSuggestions = suggestions;
        _isLoadingSuggestions = false;
      });
    } catch (e) {
      setState(() {
        _mentalHealthSuggestions = [
          'Identify stress triggers and address them one at a time.',
          'Practice mindfulness or meditation for 10 minutes daily.',
          'Talk to someone you trust about how you feel.'
        ];
        _isLoadingSuggestions = false;
      });
    }
  }

  // Add this method to your class
  Widget _fadeInWidget({required Widget child, double delay = 0.0}) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            delay,
            delay + 0.4,
            curve: Curves.easeInOut,
          ),
        ),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, 0.2),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Interval(
              delay,
              delay + 0.4,
              curve: Curves.easeInOut,
            ),
          ),
        ),
        child: child,
      ),
    );
  }

  // Add this method to your class
  Widget _buildMoodChart() {
    // List of weekdays in order
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
    // Generate data points for the chart
    List<FlSpot> spots = [];
    for (int i = 0; i < days.length; i++) {
      final moodValue = weeklyMoods[days[i]] ?? 0;
      if (moodValue > 0) {
        // Only add spots for days that have mood data
        spots.add(FlSpot(i.toDouble(), moodValue.toDouble()));
      }
    }
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value >= days.length) {
                  return const Text('');
                }
                
                // Use abbreviated day names
                final abbreviations = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    abbreviations[value.toInt()],
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 6,
        minY: 0,
        maxY: 8,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.white,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                // Highlight today's dot
                final today = _getCurrentDayName();
                final dayIndex = days.indexOf(today);
                final isToday = dayIndex == spot.x.toInt();
                
                return FlDotCirclePainter(
                  radius: isToday ? 8 : 6,
                  color: Colors.white,
                  strokeWidth: isToday ? 3 : 2,
                  strokeColor: isToday 
                    ? Color.fromARGB(255, 255, 0, 0)
                    : Color.fromARGB(255, 255, 64, 0),
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Color.fromARGB(100, 255, 255, 255),
              gradient: LinearGradient(
                colors: [
                  Color.fromARGB(150, 255, 255, 255),
                  Color.fromARGB(50, 255, 255, 255),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            curveSmoothness: 0.35,
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
          
            tooltipRoundedRadius: 12,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final dayName = days[spot.x.toInt()];
                final moodIndex = spot.y.toInt();
                
                // Map mood index to descriptive text
                String moodText = 'Unknown';
                switch(moodIndex) {
                  case 1: moodText = 'Happy'; break;
                  case 2: moodText = 'Sad'; break;
                  case 3: moodText = 'Angry'; break;
                  case 4: moodText = 'Anxious'; break;
                  case 5: moodText = 'Sleepy'; break;
                  case 6: moodText = 'Awkward'; break;
                  case 7: moodText = 'Disappointed'; break;
                  case 8: moodText = 'Content'; break;
                }
                
                return LineTooltipItem(
                  '$dayName: $moodText',
                  TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
      duration: Duration(milliseconds: 800),
      curve: Curves.easeInOutCubic,
    );
  }
  // Add this widget to create animatable cards
  Widget _animatedCard({
    required double width,
    required double height,
    required Widget child,
    VoidCallback? onTap,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isHovered = false;
        
        return GestureDetector(
          onTap: onTap,
          onTapDown: (_) => setState(() => isHovered = true),
          onTapUp: (_) => setState(() => isHovered = false),
          onTapCancel: () => setState(() => isHovered = false),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 150),
            width: width,
            height: height,
            transform: isHovered 
                ? (Matrix4.identity()..scale(1.02))
                : Matrix4.identity(),
            decoration: BoxDecoration(
              color: Color.fromARGB(168, 254, 140, 0),
              borderRadius: BorderRadius.circular(16),
              boxShadow: isHovered
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: child,
          ),
        );
      }
    );
  }

  // Helper method to build the drawer
  Widget _buildDrawer() {
    return AnimatedPositioned(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      left: _isDrawerOpen ? 0 : -250,
      top: 0,
      bottom: 0,
      width: 250,
      child: Container(
        decoration: BoxDecoration(
          color: Color.fromARGB(245, 255, 128, 64),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'MindTrack',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              Divider(color: Colors.white.withOpacity(0.5)),
              SizedBox(height: 20),
              // Profile Button
              _drawerButton(
                icon: Icons.person,
                title: 'Profile',
                onTap: () {
                  setState(() => _isDrawerOpen = false);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProfilePage()),
                  );
                },
              ),
              SizedBox(height: 15),
              // Settings Button
              _drawerButton(
                icon: Icons.settings,
                title: 'Settings',
                onTap: () {
                  setState(() => _isDrawerOpen = false);
                  // Navigator.pushNamed(context, '/settings');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget for drawer buttons
  Widget _drawerButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method for drawer backdrop
  Widget _buildDrawerBackdrop() {
    // Only show backdrop when drawer is open
    if (!_isDrawerOpen) {
      return const SizedBox.shrink();
    }
    
    return Positioned.fill(
      // Position the tap area to start after the drawer
      left: 250, // Same width as the drawer
      child: GestureDetector(
        onTap: () => setState(() => _isDrawerOpen = false),
        child: Container(
          color: Colors.black.withOpacity(0),
        ),
      ),
    );
  }

  // Add this missing method to your class
  Widget _moodSuggestionButton(String text) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        _saveMoodDescription(text);
      },
      child: Container(
        width: text.length > 10 ? 120 : 90,
        height: 30,
        decoration: BoxDecoration(
          color: _todayMoodDescription == text 
            ? Color.fromARGB(168, 255, 110, 0)
            : Color.fromARGB(118, 255, 140, 0),
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: _todayMoodDescription == text 
                ? FontWeight.bold
                : FontWeight.normal,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ),
    );
  }

  // Add this helper method to format app names
  String _formatAppName(String packageName) {
    // Common app package to display name mapping
    final Map<String, String> knownApps = {
      'com.instagram.android': 'Instagram',
      'com.facebook.katana': 'Facebook',
      'com.google.android.youtube': 'YouTube',
      'com.whatsapp': 'WhatsApp',
      'com.spotify.music': 'Spotify',
      'com.netflix.mediaclient': 'Netflix',
      'com.google.android.gm': 'Gmail',
      'com.android.chrome': 'Chrome',
      'com.twitter.android': 'Twitter',
      'com.snapchat.android': 'Snapchat',
      'com.tiktok.android': 'TikTok',
      'com.pinterest': 'Pinterest',
      'com.linkedin.android': 'LinkedIn',
    };

    // If it's a known app, return its display name
    if (knownApps.containsKey(packageName)) {
      return knownApps[packageName]!;
    }

    // Otherwise, attempt to extract app name from package name
    final parts = packageName.split('.');
    if (parts.length > 1) {
      final lastPart = parts.last;
      // Capitalize first letter
      if (lastPart.length > 1) {
        return lastPart[0].toUpperCase() + lastPart.substring(1);
      }
      return lastPart;
    }
    
    // Fallback if unable to extract meaningful name
    return packageName;
  }
}