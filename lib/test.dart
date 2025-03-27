import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(ScreenTimeTrackerApp());
}

class ScreenTimeTrackerApp extends StatelessWidget {
  const ScreenTimeTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MindTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: ScreenTimeTrackerHomePage(),
    );
  }
}

class ScreenTimeTrackerHomePage extends StatefulWidget {
  const ScreenTimeTrackerHomePage({super.key});

  @override
  _ScreenTimeTrackerHomePageState createState() => _ScreenTimeTrackerHomePageState();
}

class _ScreenTimeTrackerHomePageState extends State<ScreenTimeTrackerHomePage> with SingleTickerProviderStateMixin {
  static const platform = MethodChannel('com.example.screen_time_tracker/screen_time');
  
  late TabController _tabController;
  Map<String, dynamic> _screenTimeData = {};
  Map<String, dynamic> _unlockData = {};
  bool _isLoading = false;
  bool _hasPermission = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkPermission();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final bool hasPermission = await platform.invokeMethod('checkUsageStatsPermission');
      
      setState(() {
        _hasPermission = hasPermission;
        _isLoading = false;
      });
      
      if (hasPermission) {
        _fetchScreenTimeData();
        _fetchPhoneUnlockCount();
      }
    } on PlatformException catch (e) {
      setState(() {
        _errorMessage = 'Error checking permission: ${e.message}';
        _isLoading = false;
      });
    }
  }

  Future<void> _requestPermission() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await platform.invokeMethod('requestUsageStatsPermission');
      // We don't get a result right away as the user needs to interact with the system UI
      // Wait a bit then check permission again
      await Future.delayed(Duration(seconds: 1));
      _checkPermission();
    } on PlatformException catch (e) {
      setState(() {
        _errorMessage = 'Error requesting permission: ${e.message}';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchScreenTimeData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final result = await platform.invokeMethod('getScreenTimeData');
      
      final Map<String, dynamic> screenTimeData = {};
      
      // Manually convert and cast each value
      screenTimeData['totalUsageTime'] = result['totalUsageTime'] as int;
      
      final List<Map<String, dynamic>> appUsageList = [];
      final List<dynamic> rawAppUsage = result['appUsage'] as List<dynamic>;
      
      for (final app in rawAppUsage) {
        appUsageList.add({
          'packageName': app['packageName'] as String,
          'appName': app['appName'].toString(),
          'usageTime': app['usageTime'] as int,
        });
      }
      
      screenTimeData['appUsage'] = appUsageList;
      
      setState(() {
        _screenTimeData = screenTimeData;
        _isLoading = false;
      });
    } on PlatformException catch (e) {
      setState(() {
        _errorMessage = 'Error fetching data: ${e.message}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchPhoneUnlockCount() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Changed from getUnlockCount to getPhoneUnlockCount to match native code
      final result = await platform.invokeMethod('getPhoneUnlockCount');
      
      setState(() {
        _unlockData = Map<String, dynamic>.from(result);
        _isLoading = false;
      });
    } on PlatformException catch (e) {
      setState(() {
        _errorMessage = 'Error fetching unlock count: ${e.message}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    await _fetchScreenTimeData();
    await _fetchPhoneUnlockCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MindTrack'),
        
        bottom: _hasPermission && _errorMessage.isEmpty
            ? TabBar(
                controller: _tabController,
                tabs: [
                  Tab(icon: Icon(Icons.access_time), text: 'Screen Time'),
                  Tab(icon: Icon(Icons.lock_open), text: 'Unlock Count'),
                ],
              )
            : null,
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator())
        : !_hasPermission
          ? _buildPermissionRequest()
          : _errorMessage.isNotEmpty
            ? Center(child: Text(_errorMessage, style: TextStyle(color: Colors.red)))
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildScreenTimeList(),
                  _buildUnlockCountTab(),
                ],
              ),
      floatingActionButton: _hasPermission ? FloatingActionButton(
        onPressed: _refreshData,
        tooltip: 'Refresh',
        child: Icon(Icons.refresh),
      ) : null,
    );
  }

  Widget _buildPermissionRequest() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 64, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'Permission Required',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'This app needs access to usage stats to track screen time. On the next screen:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('1. Find this app in the list'),
                Text('2. Toggle the permission to "Allow"'),
                Text('3. For Xiaomi/MI phones, you may need to enable "Show more" to see all apps'),
                Text('4. Return to this app after granting permission'),
              ],
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _requestPermission,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text('Grant Permission', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenTimeList() {
    if (_screenTimeData.isEmpty) {
      return Center(child: Text('No screen time data available'));
    }

    final totalUsageTime = _screenTimeData['totalUsageTime'] ?? 0;
    final appUsageList = _screenTimeData['appUsage'] as List<dynamic>? ?? [];
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'Total Screen Time Today',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _formatDuration(totalUsageTime),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (appUsageList.isEmpty)
          Expanded(
            child: Center(
              child: Text('No app usage data available. Please try refreshing.'),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: appUsageList.length,
              itemBuilder: (context, index) {
                final app = appUsageList[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Text(app['appName'].toString()[0], style: TextStyle(color: Colors.white)),
                  ),
                  title: Text(app['appName'].toString()),
                  subtitle: Text(app['packageName'].toString()),
                  trailing: Text(_formatDuration(app['usageTime'] as int)),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildUnlockCountTab() {
    if (_unlockData.isEmpty) {
      return Center(child: Text('No unlock data available. Please try refreshing.'));
    }

    final totalUnlocks = _unlockData['totalUnlocks'] ?? 0;
    final hourlyUnlocks = _unlockData['hourlyUnlocks'] as List<dynamic>? ?? [];
    
    // Find the peak hour
    int peakHour = 0;
    int peakCount = 0;
    for (final hourData in hourlyUnlocks) {
      final count = hourData['count'] as int;
      if (count > peakCount) {
        peakCount = count;
        peakHour = hourData['hour'] as int;
      }
    }
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'Phone Unlocks Today',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '$totalUnlocks',
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _getUnlockFeedback(totalUnlocks),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Text(
                'Hourly Breakdown',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Spacer(),
              Text(
                'Peak: ${_formatHour(peakHour)} ($peakCount unlocks)',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildHourlyChart(hourlyUnlocks),
          ),
        ),
      ],
    );
  }

  Widget _buildHourlyChart(List<dynamic> hourlyData) {
    // Find the maximum value for scaling
    int maxValue = 1;  // Default to 1 to avoid division by zero
    for (final hourData in hourlyData) {
      final count = hourData['count'] as int;
      if (count > maxValue) maxValue = count;
    }
    
    return ListView.builder(
      itemCount: 24,
      itemBuilder: (context, index) {
        // Find the data for this hour
        final hourData = hourlyData.firstWhere(
          (data) => data['hour'] as int == index,
          orElse: () => {'hour': index, 'count': 0},
        );
        
        final count = hourData['count'] as int;
        final percentage = count / maxValue;
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              SizedBox(
                width: 50,
                child: Text(_formatHour(index)),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: percentage,
                      child: Container(
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              SizedBox(
                width: 30,
                child: Text('$count', textAlign: TextAlign.right),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatHour(int hour) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour $period';
  }

  String _getUnlockFeedback(int unlockCount) {
    if (unlockCount > 100) {
      return 'You\'re checking your phone very frequently. Consider setting focus time.';
    } else if (unlockCount > 50) {
      return 'That\'s a lot of unlocks! Try to be more mindful of phone usage.';
    } else if (unlockCount > 25) {
      return 'Average unlock count. You\'re doing fine!';
    } else {
      return 'Great job! You\'re not checking your phone too often.';
    }
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${remainingMinutes}m';
    } else {
      return '${remainingMinutes}m';
    }
  }
}