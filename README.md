# MindTrack

MindTrack is a Flutter-based mobile application designed to help users monitor their mental health and daily habits. It provides features such as mood tracking, screen time monitoring, phone unlock count analysis, and personalized mental health tips powered by Google's Generative AI.

---

## Project Summary

MindTrack aims to promote mindfulness and mental well-being by enabling users to:
- Track their daily mood and emotions.
- Monitor their screen time and app usage.
- Analyze phone unlock patterns.
- Receive personalized AI-powered mental health insights based on their usage patterns and mood data.

---

## Implementation Details

### Software Requirements
- **Flutter SDK**: Version 3.0 or higher
- **Dart**: Version 2.17 or higher
- **Hive**: For local data storage
- **Flask**: For backend API services (Python 3.8+)
- **Google Generative AI**: For AI-powered insights
- **Android Studio**: For Android development and testing
- **Xcode**: For iOS development and testing (optional)

### Hardware Requirements
- **Device**: Android device with API level 21 (Lollipop) or higher
- **Memory**: Minimum 2GB RAM
- **Storage**: Minimum 50MB free space

### Algorithms and Technologies Used
1. **Mood Analysis**: Maps user-selected mood indices to visual charts for weekly trends.
2. **Screen Time Calculation**: Aggregates app usage data using Android's `UsageStatsManager`.
3. **Unlock Count Analysis**: Tracks phone unlock events and calculates hourly patterns.
4. **AI-based Mental Health Insights**: Uses Google's Generative AI to analyze user data and provide personalized mental health recommendations.
5. **Flask Backend**: Provides API endpoints to connect the Flutter app with the Google Gemini AI service.

---

## Results and Testing

### Code Snippets

#### Example: Saving Mood Data
```dart
Future<void> _saveMood(int moodIndex) async {
  final today = _getCurrentDayName();
  setState(() {
    _selectedMoodIndex = moodIndex;
    weeklyMoods[today] = moodIndex;
  });
  await moodBox.put('weekly_moods', weeklyMoods);
}
```

#### Example: Fetching AI-Powered Mental Health Insights
```dart
Future<void> _fetchInsights() async {
  try {
    final urls = [
      'http://192.168.1.41:5000/get_mental_health_insights',  // PC's actual IP
      'http://10.0.2.2:5000/get_mental_health_insights',      // Emulator
      'http://127.0.0.1:5000/get_mental_health_insights'      // Localhost
    ];
    
    final url = urls[_retryAttempts % urls.length]; // Cycle through URLs on retry
    
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(userData),
    ).timeout(timeout);
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success']) {
        _insights = data['insights'];
        _mode = data['mode'] ?? 'unknown';
      }
    }
  } catch (e) {
    // Error handling...
  }
}
```

#### Example: Backend Integration with Google Gemini AI
```python
@app.route('/get_mental_health_insights', methods=['POST'])
def get_mental_health_insights():
    try:
        data = request.json
        
        # Extract user data
        weekly_moods = data.get('weekly_moods', {})
        screen_time = data.get('screen_time', 'Unknown')
        unlock_count = data.get('unlock_count', 'Unknown')
        most_used_app = data.get('most_used_app', 'Unknown')
        
        # Generate prompt for Gemini AI
        prompt = f"""
        As a mental health advisor, analyze the following data and provide 
        4-5 personalized mental health suggestions:
        
        Weekly Mood Data: {weekly_moods}
        Daily Screen Time: {screen_time}
        Daily Phone Unlock Count: {unlock_count}
        Most Used App: {most_used_app}
        """
        
        # Generate response from Google Gemini AI
        response = model.generate_content(prompt)
        insights = response.text
        
        return jsonify({
            "success": True,
            "insights": insights,
            "mode": "ai"
        })
        
    except Exception as e:
        return jsonify({
            "success": False, 
            "error": str(e)
        }), 500
```

---

### Test Cases

| Test Case ID | Test Scenario                  | Test Steps                                                                 | Expected Result                                                                 | Actual Result                                                                   | Status  |
|--------------|--------------------------------|---------------------------------------------------------------------------|--------------------------------------------------------------------------------|--------------------------------------------------------------------------------|---------|
| TC001        | Mood Selection Functionality   | 1. Open the app. <br> 2. Select a mood emoji. <br> 3. Save the mood.      | Mood is saved and displayed in the weekly mood chart.                          | Mood is saved and displayed correctly.                                          | Passed  |
| TC002        | Screen Time Data Fetch         | 1. Open the app. <br> 2. Navigate to the "Screen Time" page.              | Total screen time and app usage data are displayed.                            | Screen time and app usage data are displayed correctly.                         | Passed  |
| TC003        | Unlock Count Analysis          | 1. Open the app. <br> 2. Navigate to the "Unlock Count" page.             | Total unlock count and hourly breakdown are displayed.                         | Unlock count and hourly breakdown are displayed correctly.                      | Passed  |
| TC004        | Profile Update Functionality   | 1. Open the app. <br> 2. Navigate to the "Profile" page. <br> 3. Update profile details. | Profile details are updated and saved successfully.                            | Profile details are updated and saved correctly.                                | Passed  |
| TC005        | Error Handling for Permissions | 1. Deny usage stats permission. <br> 2. Try fetching screen time data.    | An error message is displayed, prompting the user to enable permissions.       | Error message is displayed, and user is prompted to enable permissions.         | Passed  |
| TC006        | AI Mental Health Insights      | 1. Open the app. <br> 2. Click on "Mental Health Suggestions and Tips".   | App connects to backend and displays personalized AI-generated insights.       | AI-generated insights are displayed correctly with proper formatting.          | Passed  |
| TC007        | Offline Mode for Insights      | 1. Enable airplane mode. <br> 2. Click on "Mental Health Suggestions".    | App falls back to offline mode and provides generic mental health tips.         | Generic tips shown with offline mode indicator.                                 | Passed  |
| TC008        | Insights Interface Rendering   | 1. View AI-generated insights. <br> 2. Scroll through the content.        | Content is properly rendered with markdown formatting and smooth scrolling.     | Markdown content displays with proper headings and paragraphs.                  | Passed  |
| TC009        | Flask Backend Integration      | 1. Start Flask server. <br> 2. Request insights from app.                 | Backend successfully processes request and returns AI-generated content.        | Connection established and insights generated within acceptable time.           | Passed  |

---

## Conclusion

MindTrack has been thoroughly tested and performs as expected. It provides an intuitive interface for users to track their mental health and habits. Future enhancements may include:

- Advanced analytics and insights based on user data.
- Enhanced AI capabilities for more personalized mental health recommendations.
