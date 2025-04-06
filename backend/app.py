from flask import Flask, request, jsonify
from flask_cors import CORS
import os
from dotenv import load_dotenv
import logging
import datetime
import platform
import flask
import time

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Load environment variables
load_dotenv()
API_KEY = os.getenv("GOOGLE_AI_API_KEY")

# Add a new endpoint for getting Gemini-generated tips
@app.route('/get_gemini_tips', methods=['POST'])
def get_gemini_tips():
    try:
        data = request.json
        
        # Extract parameters
        anxiety_level = data.get('anxiety_level', 5)
        stress_level = data.get('stress_level', 5)
        screen_time = data.get('screen_time', '240m')
        unlock_count = data.get('unlock_count', 50)
        mood_description = data.get('mood_description', '')
        weekly_moods = data.get('weekly_moods', {})
        most_used_app = data.get('most_used_app', 'Unknown')
        
        # Check if Gemini is available
        if not model:
            logger.warning("Using fallback tips since Gemini model is not available")
            tips = [
                "Take regular breaks from your screen every 30 minutes.",
                "Practice deep breathing exercises when feeling stressed.",
                "Set boundaries for your device usage, especially before bedtime."
            ]
            return jsonify({
                "success": True,
                "tips": tips,
                "mode": "fallback"
            })
        
        # Prepare prompt for Gemini
        prompt = f"""
        As a mental health advisor, analyze this user data and provide exactly 3 short, specific mental health tips:
        
        User Data:
        - Anxiety level: {anxiety_level}
        - Stress level: {stress_level}
        - Daily screen time: {screen_time}
        - Daily phone unlocks: {unlock_count}
        - Most used app: {most_used_app}
        - Mood description: "{mood_description}"
        - Weekly mood data: {weekly_moods}
        
        Return exactly 3 tips that are concise (under 100 characters each) and directly actionable.
        Each tip should target a different aspect of mental wellbeing based on the data.
        Format the response as a list of 3 tips only, with no additional text, numbering, or explanations.
        """
        
        # Generate response from Google Gemini
        response = model.generate_content(prompt)
        
        # Process response to extract the 3 tips
        tips_text = response.text.strip()
        
        # Split by newlines or bullet points to get individual tips
        if '\n' in tips_text:
            raw_tips = tips_text.split('\n')
        else:
            raw_tips = [tips_text]
            
        # Clean up tips (remove bullet points, numbering, etc.)
        cleaned_tips = []
        for tip in raw_tips:
            # Remove common bullet point formats and leading/trailing whitespace
            cleaned_tip = tip.replace('•', '').replace('-', '').replace('*', '')
            cleaned_tip = cleaned_tip.strip()
            
            # Remove numbering like "1." or "1)"
            if cleaned_tip and cleaned_tip[0].isdigit() and len(cleaned_tip) > 2:
                if cleaned_tip[1] in ['.', ')', ':']:
                    cleaned_tip = cleaned_tip[2:].trip()
            
            if cleaned_tip:  # Only add non-empty tips
                cleaned_tips.append(cleaned_tip)
        
        # Ensure we have exactly 3 tips
        if len(cleaned_tips) < 3:
            # Add fallback tips if needed
            fallback_tips = [
                "Take regular breaks from your screen every 30 minutes.",
                "Practice deep breathing exercises when feeling stressed.",
                "Set boundaries for your device usage, especially before bedtime."
            ]
            while len(cleaned_tips) < 3:
                cleaned_tips.append(fallback_tips[len(cleaned_tips) % 3])
        elif len(cleaned_tips) > 3:
            # Trim to just 3 tips
            cleaned_tips = cleaned_tips[:3]
            
        logger.info(f"Generated {len(cleaned_tips)} Gemini tips successfully")
        
        return jsonify({
            "success": True,
            "tips": cleaned_tips,
            "mode": "gemini"
        })
        
    except Exception as e:
        logger.error(f"Error generating Gemini tips: {e}")
        # Return fallback tips if an error occurs
        fallback_tips = [
            "Take regular breaks from your screen every 30 minutes.",
            "Practice deep breathing exercises when feeling stressed.",
            "Set boundaries for your device usage, especially before bedtime."
        ]
        return jsonify({
            "success": False,
            "tips": fallback_tips,
            "error": str(e),
            "mode": "fallback"
        })

# Initialize Google Gemini AI client only if we have an API key
genai = None
model = None

if API_KEY:
    try:
        import google.generativeai as genai
        
        # Updated API initialization - new method instead of configure()
        genai.configure(api_key=API_KEY)
        
        # Create the model with the correct API
        model = genai.GenerativeModel('gemini-1.5-flash')
        
        logger.info("Google Gemini AI client initialized successfully")
    except Exception as e:
        logger.error(f"Error initializing Google Gemini AI client: {e}")
        genai = None
        model = None

# Updated health check endpoint with more diagnostics
@app.route('/health', methods=['GET'])
def health_check():
    try:
        # Include more diagnostic info
        return jsonify({
            "status": "healthy",
            "ai_status": "active" if model else "disabled",
            "api_key_configured": bool(API_KEY),
            "timestamp": datetime.datetime.now().isoformat(),
            "server_info": {
                "platform": platform.system(),
                "python_version": platform.python_version(),
                "flask_version": flask.__version__
            }
        }), 200
    except Exception as e:
        logger.error(f"Error in health check: {e}")
        return jsonify({
            "status": "error",
            "error": str(e)
        }), 500

# Add timeout handling for the insights endpoint
@app.route('/get_mental_health_insights', methods=['POST'])
def get_mental_health_insights():
    try:
        # Get data from the request
        start_time = datetime.datetime.now()
        data = request.json
        logger.info(f"Received data: {data}")
        
        # Extract user data
        weekly_moods = data.get('weekly_moods', {})
        screen_time = data.get('screen_time', 'Unknown')
        unlock_count = data.get('unlock_count', 'Unknown')
        most_used_app = data.get('most_used_app', 'Unknown')
        mood_description = data.get('mood_description', 'Unknown')
        profession = data.get('profession', 'Unknown')
        gender = data.get('gender', 'Unknown')
        age = data.get('age', 'Unknown')
        
        # If model is not available, return demo response
        if not model:
            logger.warning("Using demo response since AI model is not available")
            insights = """
# Mental Health Insights

Based on your data, here are some personalized insights:

## Recognize Screen Time Patterns

Your daily screen time of {screen_time} suggests potential digital overload. 
Consider setting app time limits and taking regular breaks from your devices.

## Practice Mindfulness Techniques

Your mood patterns and unlock frequency indicate stress. Try deep breathing exercises 
or meditation for 5 minutes when you feel overwhelmed.

## Establish Healthy Phone Boundaries

With {unlock_count} phone unlocks daily, you might benefit from designating phone-free zones 
or times, particularly during meals and before bedtime.

## Seek Balance in Digital Life

Your most used app is {most_used_app}. Consider if this aligns with your priorities 
and values. Try diversifying your activities and interests.
""".format(screen_time=screen_time, unlock_count=unlock_count, most_used_app=most_used_app)
            
            # Shorter delay for demo mode
            time.sleep(1)
            
            processing_time = (datetime.datetime.now() - start_time).total_seconds()
            logger.info(f"Generated demo insights, returning to client")
            
            return jsonify({
                "success": True,
                "insights": insights,
                "mode": "demo",
                "processing_time_seconds": processing_time
            })
        
        # If we have a model, use Gemini AI
        # Prepare prompt for Gemini AI
        prompt = f"""
        As a mental health advisor, analyze the following data and provide 4-5 personalized mental health suggestions, explaining the rationale behind each suggestion:
        
        User Profile:
        - Age: {age}
        - Gender: {gender}
        - Profession: {profession}
        
        Weekly Mood Data: {weekly_moods}
        
        Digital Well-being Metrics:
        - Daily Screen Time: {screen_time}
        - Daily Phone Unlock Count: {unlock_count}
        - Most Used App: {most_used_app}
        
        User's Description of Their Mood: "{mood_description}"
        
        Based on this data, please provide:
        1. A brief analysis of potential mental health impacts
        2. 4-5 specific, actionable suggestions to improve mental wellbeing
        3. For each suggestion, explain why it might help this particular user
        
        Format each suggestion with a clear title and detailed explanation.
        """
        
        # Generate response from Google Gemini AI with updated API
        response = model.generate_content(prompt)
        
        # Check if response is valid
        if not hasattr(response, 'text') or not response.text:
            logger.error("Empty or invalid response from Gemini API")
            raise Exception("Invalid response received from AI service")
            
        insights = response.text
        
        # Print the insights to terminal for debugging
        print("\n----- GENERATED INSIGHTS -----")
        print(insights)
        print("----- END OF INSIGHTS -----\n")
        
        logger.info(f"Generated insights successfully, length: {len(insights)} characters")
        
        # Log processing time
        processing_time = (datetime.datetime.now() - start_time).total_seconds()
        logger.info(f"Request processed in {processing_time:.2f} seconds")
        
        # Make sure the content is properly encoded and has CORS headers
        response = jsonify({
            "success": True,
            "insights": insights,
            "mode": "ai",
            "processing_time_seconds": processing_time
        })
        
        # Add explicit CORS headers
        response.headers.add('Access-Control-Allow-Origin', '*')
        response.headers.add('Access-Control-Allow-Headers', 'Content-Type')
        return response
        
    except Exception as e:
        logger.error(f"Error generating mental health insights: {e}")
        # Return a properly formatted error response with fallback content
        fallback_insights = """
# Mental Health Insights

It seems we encountered an issue connecting to our AI service. Here are some general tips:

## Take Regular Breaks

Consider stepping away from screens every 30-45 minutes to reduce eye strain and mental fatigue.

## Practice Mindfulness

Set aside 5-10 minutes daily for deep breathing or meditation to reduce stress.

## Establish Digital Boundaries

Consider designating tech-free times or zones in your daily routine.

## Prioritize Sleep

Try to maintain a consistent sleep schedule and avoid screens before bedtime.
"""
        
        error_response = jsonify({
            "success": False,
            "insights": fallback_insights,
            "mode": "fallback",
            "error": str(e)
        })
        
        # Add explicit CORS headers
        error_response.headers.add('Access-Control-Allow-Origin', '*')
        error_response.headers.add('Access-Control-Allow-Headers', 'Content-Type')
        return error_response

if __name__ == '__main__':
    # Binding to 0.0.0.0 instead of localhost allows connections from other devices
    app.run(host='0.0.0.0', port=5000, debug=True)
