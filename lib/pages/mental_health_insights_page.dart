import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:markdown_widget/markdown_widget.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'package:mindtrack/utils/debug_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Caching variables
  static const String _cacheKeyInsights = 'cached_mental_health_insights';
  static const String _cacheKeyTimestamp = 'cached_insights_timestamp';
  static const String _cacheKeyMode = 'cached_insights_mode';
  static const Duration _cacheExpiration = Duration(hours: 6);

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
      bool shouldFetchFromBackend = true;
      
      // Try to get cached insights with proper error handling
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedInsights = prefs.getString(_cacheKeyInsights);
        final cachedMode = prefs.getString(_cacheKeyMode);
        final cachedTimestampMillis = prefs.getInt(_cacheKeyTimestamp);
        
        // If we have cached insights, check if they're still valid
        if (cachedInsights != null && cachedTimestampMillis != null) {
          final cachedTime = DateTime.fromMillisecondsSinceEpoch(cachedTimestampMillis);
          final now = DateTime.now();
          final difference = now.difference(cachedTime);
          
          // If cache is still valid (less than 6 hours old), use it
          if (difference < _cacheExpiration) {
            DebugHelper.log("Using cached insights from ${difference.inMinutes} minutes ago");
            setState(() {
              _insights = cachedInsights;
              _mode = cachedMode ?? 'unknown';
              _isLoading = false;
              _isRetrying = false;
              _retryAttempts = 0;
              _progressTimer?.cancel();
            });
            return; // Exit early since we're using cached data
          } else {
            DebugHelper.log("Cached insights expired (${difference.inHours} hours old), fetching new data");
            shouldFetchFromBackend = true;
          }
        } else {
          DebugHelper.log("No cached insights found, fetching from backend");
          shouldFetchFromBackend = true;
        }
      } catch (e) {
        DebugHelper.error("Error reading cache", e);
        // Continue with backend fetch if cache read fails
        shouldFetchFromBackend = true;
      }

      if (shouldFetchFromBackend) {
        DebugHelper.log("Fetching mental health insights from backend");
        DebugHelper.log("Attempt ${_retryAttempts + 1} of ${_maxRetryAttempts + 1}");

        // Use hosted URL as primary, then fall back to local URLs if needed
        final urls = [
          'https://mindtrack-backend.onrender.com/get_mental_health_insights',  // Hosted URL
          'http://192.168.1.41:5000/get_mental_health_insights',  // PC's actual IP (fallback)
          'http://10.0.2.2:5000/get_mental_health_insights'       // Emulator (fallback)
        ];
        
        final url = urls[_retryAttempts % urls.length]; // Cycle through URLs on retry
        
        DebugHelper.log("Connecting to: $url");
        
        // Use a longer timeout for the hosted service
        final timeout = const Duration(seconds: 30);

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
          
          // Process the response using our helper method
          final data = await _processServerResponse(response);
          
          // Cache the new insights
          final insights = data['insights'];
          final mode = data['mode'] ?? 'unknown';
          final now = DateTime.now().millisecondsSinceEpoch;
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_cacheKeyInsights, insights);
          await prefs.setString(_cacheKeyMode, mode);
          await prefs.setInt(_cacheKeyTimestamp, now);
          DebugHelper.log("Cached new insights with timestamp: $now");
          
          setState(() {
            _insights = insights;
            _mode = mode;
            _isLoading = false;
            _isRetrying = false;
            _retryAttempts = 0;
            _progressTimer?.cancel();
          });
        } finally {
          client.close();
        }
      }
    } catch (e) {
      DebugHelper.error("Error fetching insights", e);
      
      // Try to load cached insights as a fallback, even if they're expired
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedInsights = prefs.getString(_cacheKeyInsights);
        final cachedMode = prefs.getString(_cacheKeyMode);
        
        if (cachedInsights != null) {
          DebugHelper.log("Using expired cached insights as fallback after fetch error");
          setState(() {
            _insights = cachedInsights;
            _mode = cachedMode ?? 'offline';
            _isLoading = false;
            _progressTimer?.cancel();
            _isRetrying = false;
            _retryAttempts = 0;
          });
          return;
        }
      } catch (cacheError) {
        DebugHelper.error("Failed to read cache as fallback", cacheError);
      }
      
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

  // This method deserializes and validates the response from the server
  Future<Map<String, dynamic>> _processServerResponse(http.Response response) async {
    try {
      // First validate the response status code
      if (response.statusCode != 200) {
        throw Exception('Server returned status code ${response.statusCode}');
      }
      
      // Parse the response body
      final data = jsonDecode(response.body);
      
      // Log the received data structure for debugging
      DebugHelper.log("Received response data: ${data.toString().substring(0, min(100, data.toString().length))}...");
      
      // Validate response structure
      if (!data.containsKey('success')) {
        throw Exception('Invalid response format: missing success field');
      }
      
      // Check if the request was successful according to the response
      final success = data['success'];
      if (success != true) {
        final errorMsg = data['error'] ?? 'Unknown error occurred';
        throw Exception('Request failed: $errorMsg');
      }
      
      // Validate required fields
      if (!data.containsKey('insights')) {
        throw Exception('Invalid response format: missing insights field');
      }
      
      return data;
    } catch (e) {
      DebugHelper.error("Error processing server response", e);
      rethrow; // Re-throw the exception to be handled by the caller
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('Mental Health Insights'),
        backgroundColor: primaryColor,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: SafeArea(
        child: _buildBody(primaryColor, textColor),
      ),
    );
  }

  Widget _buildBody(Color primaryColor, Color? textColor) {
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
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                borderRadius: BorderRadius.circular(4),
              ),
              SizedBox(height: 10),
              Text(
                _isRetrying ? "Retrying... (Attempt ${_retryAttempts})" : _statusMessage,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textColor?.withOpacity(0.7),
                ),
              ),
              SizedBox(height: 32),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
              SizedBox(height: 24),
              Text(
                'Analyzing your data and generating personalized insights...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textColor,
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
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'We had trouble connecting to our recommendation service. This might be due to network issues.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor?.withOpacity(0.8),
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
                          backgroundColor: primaryColor,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: Text('Try Again' , style: TextStyle(fontSize: 16, color: Colors.white)),
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
                  color: primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, 
                      color: primaryColor,
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
                              color: textColor,
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
              _buildMarkdownContent(_insights, textColor),
              
              SizedBox(height: 40),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: Text('Back to Home', style: TextStyle(fontSize: 16, color: Colors.white)),
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
  Widget _buildMarkdownContent(String markdown, Color? textColor) {
    try {
      // Simple markdown parsing for robust rendering
      final lines = markdown.split('\n');
      List<Widget> content = [];
      final primaryColor = Theme.of(context).colorScheme.primary;
      bool inList = false;
      List<Widget> listItems = [];
      
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        
        // Handle headings (H1)
        if (line.startsWith('# ')) {
          // If we were in a list, add the accumulated list items first
          if (inList) {
            content.add(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: listItems,
            ));
            listItems = [];
            inList = false;
          }
          
          content.add(
            Padding(
              padding: const EdgeInsets.only(top: 24.0, bottom: 16.0),
              child: Text(
                line.substring(2),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: primaryColor.withOpacity(0.9),
                ),
              ),
            )
          );
        } 
        // Handle subheadings (H2)
        else if (line.startsWith('## ')) {
          // If we were in a list, add the accumulated list items first
          if (inList) {
            content.add(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: listItems,
            ));
            listItems = [];
            inList = false;
          }
          
          content.add(
            Padding(
              padding: const EdgeInsets.only(top: 20.0, bottom: 12.0),
              child: Text(
                line.substring(3),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            )
          );
        }
        // Handle H3
        else if (line.startsWith('### ')) {
          // If we were in a list, add the accumulated list items first
          if (inList) {
            content.add(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: listItems,
            ));
            listItems = [];
            inList = false;
          }
          
          content.add(
            Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
              child: Text(
                line.substring(4),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: primaryColor.withOpacity(0.8),
                ),
              ),
            )
          );
        }
        // Handle bullet points
        else if (line.startsWith('- ') || line.startsWith('* ')) {
          inList = true;
          
          // Get the bullet text content
          final bulletText = line.substring(2);
          
          listItems.add(
            Padding(
              padding: const EdgeInsets.only(top: 4.0, bottom: 4.0, left: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, right: 8.0),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      bulletText,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: textColor?.withOpacity(0.9),
                      ),
                    ),
                  ),
                ],
              ),
            )
          );
        }
        // Handle numbered lists
        else if (RegExp(r'^\d+\.\s').hasMatch(line)) {
          inList = true;
          
          // Extract the number and text
          final match = RegExp(r'^(\d+)\.\s(.+)$').firstMatch(line);
          if (match != null) {
            final number = match.group(1);
            final text = match.group(2);
            
            listItems.add(
              Padding(
                padding: const EdgeInsets.only(top: 4.0, bottom: 4.0, left: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      margin: EdgeInsets.only(right: 8.0, top: 4.0),
                      child: Text(
                        '$number.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        text!,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: textColor?.withOpacity(0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            );
          }
        }
        // Handle bold text (**text**)
        else if (line.contains('**')) {
          // If we were in a list, add the accumulated list items first
          if (inList) {
            content.add(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: listItems,
            ));
            listItems = [];
            inList = false;
          }
          
          // Process bold text
          final parts = _processBoldText(line, textColor);
          content.add(
            Padding(
              padding: const EdgeInsets.only(top: 6.0, bottom: 6.0),
              child: RichText(
                text: TextSpan(
                  children: parts,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: textColor?.withOpacity(0.9),
                  ),
                ),
              ),
            )
          );
        }
        // Handle paragraphs (any non-empty line that isn't a heading or list)
        else if (line.isNotEmpty) {
          // If we were in a list, add the accumulated list items first
          if (inList) {
            content.add(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: listItems,
            ));
            listItems = [];
            inList = false;
          }
          
          content.add(
            Padding(
              padding: const EdgeInsets.only(top: 6.0, bottom: 6.0),
              child: Text(
                line,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: textColor?.withOpacity(0.9),
                ),
              ),
            )
          );
        }
        // Handle horizontal rule
        else if (line.startsWith('---') || line.startsWith('***')) {
          // If we were in a list, add the accumulated list items first
          if (inList) {
            content.add(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: listItems,
            ));
            listItems = [];
            inList = false;
          }
          
          content.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Container(
                height: 1,
                color: Colors.grey.withOpacity(0.5),
              ),
            )
          );
        }
        // Add empty line for spacing between paragraphs
        else if (line.isEmpty) {
          // For empty lines, add spacing but don't end lists
          if (!inList) {
            content.add(SizedBox(height: 8));
          }
        }
      }
      
      // Add any remaining list items
      if (inList && listItems.isNotEmpty) {
        content.add(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: listItems,
        ));
      }
      
      // Fallback if no content was parsed
      if (content.isEmpty) {
        content.add(
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              markdown,
              style: TextStyle(fontSize: 16, height: 1.5, color: textColor),
            ),
          )
        );
      }
      
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: content,
        ),
      );
    } catch (e) {
      // If any error occurs during markdown parsing, show raw text
      DebugHelper.error("Error parsing markdown", e);
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          _insights,
          style: TextStyle(fontSize: 16, height: 1.5, color: textColor),
        ),
      );
    }
  }
  
  // Helper method to process bold text in markdown
  List<TextSpan> _processBoldText(String text, Color? textColor) {
    List<TextSpan> spans = [];
    final boldPattern = RegExp(r'\*\*(.*?)\*\*');
    
    int lastMatchEnd = 0;
    
    // Find all bold text patterns
    for (final match in boldPattern.allMatches(text)) {
      // Add normal text before the match
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
        ));
      }
      
      // Add the bold text
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(fontWeight: FontWeight.bold)
      ));
      
      lastMatchEnd = match.end;
    }
    
    // Add any remaining text after the last match
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
      ));
    }
    
    return spans;
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
