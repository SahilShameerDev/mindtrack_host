import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Custom Colors - copied from original to maintain consistency
class AppColors {
  static const Color primary = Color(0xC4FF4000); // #FF4000 with 77% alpha
  static const Color secondary = Color(0xFFFFB357); // #FFB357
  static const Color background = Colors.white;
}

// Unlock Count Page
class UnlockCountPage extends StatefulWidget {
  final MethodChannel platform;
  
  const UnlockCountPage({super.key, required this.platform});

  @override
  _UnlockCountPageState createState() => _UnlockCountPageState();
}

class _UnlockCountPageState extends State<UnlockCountPage> with SingleTickerProviderStateMixin {
  Map<String, dynamic> _unlockData = {};
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
    _fetchPhoneUnlockCount();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchPhoneUnlockCount() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final result = await widget.platform.invokeMethod('getPhoneUnlockCount');
      
      setState(() {
        _unlockData = Map<String, dynamic>.from(result);
        _isLoading = false;
      });
      _animationController.forward();
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

  @override
  Widget build(BuildContext context) {
    // Get theme colors
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Unlock Count', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: primaryColor))
        : _errorMessage.isNotEmpty
          ? Center(child: Text(_errorMessage, style: TextStyle(color: Colors.red)))
          : _buildUnlockContent(primaryColor, secondaryColor, textColor),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchPhoneUnlockCount,
        backgroundColor: primaryColor,
        child: Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  Widget _buildUnlockContent(Color primaryColor, Color secondaryColor, Color? textColor) {
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
    
    // Find the maximum value for scaling
    int maxValue = 1;  // Default to 1 to avoid division by zero
    for (final hourData in hourlyUnlocks) {
      final count = hourData['count'] as int;
      if (count > maxValue) maxValue = count;
    }
    
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
                  'Phone Unlocks Today',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 12),
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: totalUnlocks),
                  duration: Duration(milliseconds: 1500),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Text(
                      '$value',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
                SizedBox(height: 8),
                Text(
                  _getUnlockFeedback(totalUnlocks),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Text(
                'Hourly Breakdown',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              Spacer(),
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: child,
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: secondaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Peak: ${_formatHour(peakHour)} ($peakCount)',
                    style: TextStyle(
                      fontSize: 14,
                      color: primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Expanded(
          child: AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: child,
              );
            },
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: 24,
              itemBuilder: (context, index) {
                // Find the data for this hour
                final hourData = hourlyUnlocks.firstWhere(
                  (data) => data['hour'] as int == index,
                  orElse: () => {'hour': index, 'count': 0},
                );
                
                final count = hourData['count'] as int;
                final percentage = count / maxValue;
                
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          child: Text(
                            _formatHour(index),
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: index == peakHour ? primaryColor : textColor,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: percentage),
                            duration: Duration(milliseconds: 800),
                            curve: Curves.easeOut,
                            builder: (context, value, _) {
                              return Stack(
                                children: [
                                  Container(
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: value,
                                    child: Container(
                                      height: 24,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: index == peakHour 
                                            ? [primaryColor, secondaryColor]
                                            : [primaryColor.withOpacity(0.6), secondaryColor.withOpacity(0.6)],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        SizedBox(width: 8),
                        SizedBox(
                          width: 30,
                          child: Text(
                            '$count',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontWeight: index == peakHour ? FontWeight.bold : FontWeight.normal,
                              color: index == peakHour ? primaryColor : textColor,
                            ),
                          ),
                        ),
                      ],
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
}