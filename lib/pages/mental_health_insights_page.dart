import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:markdown_widget/markdown_widget.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'package:mindtrack/utils/debug_helper.dart';

class MentalHealthInsightsPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const MentalHealthInsightsPage({
    Key? key,
    required this.userData,
  }) : super(key: key);

  @override
  _MentalHealthInsightsPageState createState() => _MentalHealthInsightsPageState();
}

class _MentalHealthInsightsPageState extends State<MentalHealthInsightsPage> {
  bool _isLoading = true;
  String _insights = '';
  String _errorMessage = '';
  bool _hasError = false;
  String _mode = '';
  bool _isRetrying = false;
  int _retryAttempts = 0;
  final int _maxRetryAttempts = 2;

  // Connection status indicators
  double _progressValue = 0.0;
  String _statusMessage = 'Connecting to server...';
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    DebugHelper.log("Mental Health Insights Page initialized");
    _startProgressAnimation();
    _fetchInsights();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  // Start progress animation to provide visual feedback during loading
  void _startProgressAnimation() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        setState(() {
          // Slowly increment progress up to 90% (reserve the last 10% for actual response)
          if (_progressValue < 0.9) {
            _progressValue += 0.01;
            
            // Update status message based on progress
            if (_progressValue > 0.3 && _progressValue < 0.5) {
              _statusMessage = 'Analyzing your data...';
            } else if (_progressValue >= 0.5 && _progressValue < 0.8) {
              _statusMessage = 'Generating insights...';
            } else if (_progressValue >= 0.8) {
              _statusMessage = 'Almost there...';
            }
          }
        });
      }
    });
  }

  Future<void> _fetchInsights() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
      if (!_isRetrying) {
        _progressValue = 0.0;
      }
    });

    try {
      DebugHelper.log("Fetching mental health insights from backend");
      DebugHelper.log("Attempt ${_retryAttempts + 1} of ${_maxRetryAttempts + 1}");

      // Try first your PC's actual IP address for physical device, then emulator/localhost addresses
      final urls = [
        'http://192.168.1.41:5000/get_mental_health_insights',  // PC's actual IP
        'http://10.0.2.2:5000/get_mental_health_insights',      // Emulator
        'http://127.0.0.1:5000/get_mental_health_insights'      // Localhost
      ];
      
      final url = urls[_retryAttempts % urls.length]; // Cycle through URLs on retry
      
      DebugHelper.log("Connecting to: $url");
      
      // Use a shorter timeout for first attempt, longer for retries
      final timeout = _retryAttempts == 0 
          ? const Duration(seconds: 10) 
          : const Duration(seconds: 20);

      // Create a client with timeout
      final client = http.Client();
      try {
        final response = await client.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(widget.userData),
        ).timeout(timeout);
        
        // Complete the progress animation
        setState(() {
          _progressValue = 1.0;
          _statusMessage = 'Insights received!';
        });

        DebugHelper.log("Got response with status code: ${response.statusCode}");
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success']) {
            DebugHelper.log("Successfully received insights, mode: ${data['mode']}");
            setState(() {
              _insights = data['insights'];
              _mode = data['mode'] ?? 'unknown';
              _isLoading = false;
              _isRetrying = false;
              _retryAttempts = 0;
            });
          } else {
            throw Exception(data['error'] ?? 'Unknown error occurred');
          }
        } else {
          throw Exception('Failed to load insights: ${response.statusCode}');
        }
      } finally {
        client.close();
      }
    } catch (e) {
      DebugHelper.error("Error fetching insights", e);
      
      // Retry logic
      if (_retryAttempts < _maxRetryAttempts) {
        setState(() {
          _retryAttempts++;
          _isRetrying = true;
        });
        
        DebugHelper.log("Retrying in 2 seconds...");
        await Future.delayed(const Duration(seconds: 2));
        return _fetchInsights();
      }
      
      // If there's an error connecting to the backend, generate a simple local response
      setState(() {
        _isLoading = false;
        _progressTimer?.cancel();
        
        // Check for specific error types and provide helpful messages
        if (e.toString().contains('timeout') || 
            e.toString().contains('SocketException')) {
          
          // Use offline content when backend is unreachable
          _useOfflineMode();
        } else {
          // For other errors, show the error message
          _hasError = true;
          _errorMessage = e.toString();
        }
      });
    }
  }
  
  // Extract offline mode to a separate method to avoid code duplication
  void _useOfflineMode() {
    setState(() {
      _hasError = false;
      _insights = """
# Mental Health Insights

It looks like we're having trouble connecting to our recommendation service. Here are some general suggestions based on common patterns:

## Take Regular Breaks

Consider taking short breaks from your screen every 30 minutes.

## Practice Mindfulness

Set aside 5-10 minutes each day for meditation or deep breathing exercises.

## Limit App Usage

Try setting time limits on social media and other frequently used apps.

## Establish Tech-Free Time

Create phone-free zones or times in your daily routine to disconnect.
""";
      _mode = 'offline';
      DebugHelper.log("Using offline mode for insights");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Mental Health Insights'),
        backgroundColor: Color.fromARGB(192, 255, 64, 0),
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min, // Add this to prevent layout overflow
            children: [
              // Show progress indicator with text below
              LinearProgressIndicator(
                value: _progressValue,
                minHeight: 8,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(Color.fromARGB(192, 255, 64, 0)),
                borderRadius: BorderRadius.circular(4),
              ),
              SizedBox(height: 10),
              Text(
                _isRetrying ? "Retrying... (Attempt ${_retryAttempts})" : _statusMessage,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 32),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color.fromARGB(192, 255, 64, 0)),
              ),
              SizedBox(height: 24),
              Text(
                'Analyzing your data and generating personalized insights...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              if (_isRetrying) ...[
                SizedBox(height: 16),
                Text(
                  'Connection is slow, please wait...',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.orange[800],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (_hasError) {
      return SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min, // Add this to prevent layout overflow
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 60,
                    color: Colors.red,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Unable to connect to server',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'We had trouble connecting to our recommendation service. This might be due to network issues.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Flexible(
                    child: Container(
                      constraints: BoxConstraints(maxHeight: 80),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            _errorMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _retryAttempts = 0;
                            _isRetrying = false;
                          });
                          _startProgressAnimation();
                          _fetchInsights();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromARGB(168, 254, 140, 0),
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: Text('Try Again'),
                      ),
                      SizedBox(width: 16),
                      TextButton(
                        onPressed: _useOfflineMode,
                        child: Text(
                          'Use Offline Mode',
                          style: TextStyle(
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Success state - show insights with fixed layout
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16.0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Header container
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color.fromARGB(168, 254, 140, 0).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, 
                      color: Color.fromARGB(255, 255, 100, 0),
                      size: 30,
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your personalized mental health insights',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_mode == 'offline')
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                '(Offline mode - Connect to the internet for AI-powered insights)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          if (_mode == 'demo')
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                '(Demo mode - API key not configured)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              
              // FIX: Use direct rendering for markdown content instead of the MarkdownWidget
              // This helps avoid layout issues
              _buildMarkdownContent(_insights),
              
              SizedBox(height: 40),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(168, 254, 140, 0),
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: Text('Back to Home', style: TextStyle(fontSize: 16)),
                ),
              ),
              SizedBox(height: 24),
            ]),
          ),
        ),
      ],
    );
  }
  
  // Custom markdown rendering to avoid layout issues
  Widget _buildMarkdownContent(String markdown) {
    try {
      // Simple markdown parsing for robust rendering
      final lines = markdown.split('\n');
      List<Widget> content = [];
      
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        
        // Handle headings
        if (line.startsWith('# ')) {
          content.add(
            Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
              child: Text(
                line.substring(2),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            )
          );
        } 
        // Handle subheadings
        else if (line.startsWith('## ')) {
          content.add(
            Padding(
              padding: const EdgeInsets.only(top: 14.0, bottom: 6.0),
              child: Text(
                line.substring(3),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 255, 100, 0),
                ),
              ),
            )
          );
        }
        // Handle paragraphs (any non-empty line that isn't a heading)
        else if (line.isNotEmpty) {
          content.add(
            Padding(
              padding: const EdgeInsets.only(top: 6.0, bottom: 6.0),
              child: Text(
                line,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
            )
          );
        }
      }
      
      // Fallback if no content was parsed
      if (content.isEmpty) {
        content.add(
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              markdown,
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
          )
        );
      }
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: content,
      );
    } catch (e) {
      // If any error occurs during markdown parsing, show raw text
      DebugHelper.error("Error parsing markdown", e);
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          _insights,
          style: TextStyle(fontSize: 16, height: 1.5),
        ),
      );
    }
  }
  
  // Backup method for when MarkdownWidget works
  Widget _buildMarkdownWidgetContent() {
    try {
      return Container(
        constraints: BoxConstraints(
          minHeight: 200,
        ),
        child: MarkdownWidget(
          data: _insights,
          config: MarkdownConfig(
            configs: [
              H1Config(
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              H2Config(
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 255, 100, 0),
                ),
              ),
              PConfig(
                textStyle: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      DebugHelper.error("Error rendering markdown widget", e);
      return Text(_insights);
    }
  }
}
