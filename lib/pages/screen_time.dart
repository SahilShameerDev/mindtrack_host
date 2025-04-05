import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Screen Time Page
class ScreenTimePage extends StatefulWidget {
  final MethodChannel platform;
  
  const ScreenTimePage({super.key, required this.platform});

  @override
  _ScreenTimePageState createState() => _ScreenTimePageState();
}

class _ScreenTimePageState extends State<ScreenTimePage> with SingleTickerProviderStateMixin {
  Map<String, dynamic> _screenTimeData = {};
  bool _isLoading = true;
  String _errorMessage = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _fetchScreenTimeData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchScreenTimeData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final result = await widget.platform.invokeMethod('getScreenTimeData');
      
      final Map<String, dynamic> screenTimeData = {};
      
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
      _animationController.forward();
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

  @override
  Widget build(BuildContext context) {
    // Get theme colors
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Screen Time', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: primaryColor))
        : _errorMessage.isNotEmpty
          ? Center(child: Text(_errorMessage, style: TextStyle(color: Colors.red)))
          : _buildScreenTimeContent(primaryColor, secondaryColor, textColor),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchScreenTimeData,
        backgroundColor: primaryColor,
        child: Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  Widget _buildScreenTimeContent(Color primaryColor, Color secondaryColor, Color? textColor) {
    if (_screenTimeData.isEmpty) {
      return Center(child: Text('No screen time data available'));
    }

    final totalUsageTime = _screenTimeData['totalUsageTime'] ?? 0;
    final appUsageList = _screenTimeData['appUsage'] as List<dynamic>? ?? [];
    
    return Column(
      children: [
        AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - _fadeAnimation.value)),
                child: child,
              ),
            );
          },
          child: Container(
            width: double.infinity,
            margin: EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Text(
                  'Total Screen Time Today',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 12),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: Duration(milliseconds: 1000),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: child,
                    );
                  },
                  child: Text(
                    _formatDuration(totalUsageTime),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: child,
              );
            },
            child: appUsageList.isEmpty
              ? Center(
                  child: Text('No app usage data available. Please try refreshing.'),
                )
              : ListView.builder(
                  itemCount: appUsageList.length,
                  itemBuilder: (context, index) {
                    final app = appUsageList[index];
                    final usageTime = app['usageTime'] as int;
                    final totalTime = totalUsageTime > 0 ? totalUsageTime : 1;
                    final percentage = usageTime / totalTime;
                                      
                    return TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(50 * (1 - value), 0),
                            child: child,
                          ),
                        );
                      },
                      child: Card(  
                        elevation: 2,
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: secondaryColor,
                                    child: Text(
                                      app['appName'].toString()[0],
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          app['appName'].toString(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold, 
                                            fontSize: 16,
                                            color: textColor,
                                          ),
                                        ),
                                        Text(
                                          app['packageName'].toString(),
                                          style: TextStyle(
                                            fontSize: 12, 
                                            color: Colors.grey
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(usageTime),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0, end: percentage),
                                duration: Duration(milliseconds: 800),
                                curve: Curves.easeOut,
                                builder: (context, value, _) {
                                  return Stack(
                                    children: [
                                      Container(
                                        height: 8,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      FractionallySizedBox(
                                        widthFactor: value,
                                        child: Container(
                                          height: 8,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [primaryColor, secondaryColor],
                                            ),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '${(percentage * 100).toStringAsFixed(1)}%',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
          ),
        ),
      ],
    );
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