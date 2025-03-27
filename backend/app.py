from flask import Flask, request, jsonify
from flask_cors import CORS
import os
from dotenv import load_dotenv
import logging
import datetime
import platform
import flask
import time
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig
import random

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Load environment variables
load_dotenv()
API_KEY = os.getenv("GOOGLE_AI_API_KEY")

# Path to custom trained model
MODEL_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "adapter_model.safetensors")
BASE_MODEL = "unsloth/llama-3-8b-bnb-4bit"

# Initialize custom model
custom_model = None
custom_tokenizer = None

try:
    logger.info(f"Loading custom model from {MODEL_PATH}")
    
    # Configure quantization
    bnb_config = BitsAndBytesConfig(
        load_in_4bit=True,
        bnb_4bit_use_double_quant=True,
        bnb_4bit_quant_type="nf4",
        bnb_4bit_compute_dtype=torch.bfloat16
    )
    
    # Load tokenizer
    custom_tokenizer = AutoTokenizer.from_pretrained(BASE_MODEL)
    
    # Load model with the adapter weights
    custom_model = AutoModelForCausalLM.from_pretrained(
        BASE_MODEL,
        device_map="auto",
        torch_dtype=torch.bfloat16,
        quantization_config=bnb_config
    )
    
    # Load adapter weights
    custom_model.load_adapter(MODEL_PATH)
    logger.info("Custom model loaded successfully")
except Exception as e:
    logger.error(f"Error loading custom model: {e}")
    custom_model = None
    custom_tokenizer = None

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

# Function to generate tips using the custom model
def generate_custom_tip(anxiety, stress, screen_time, unlock_count):
    if not custom_model or not custom_tokenizer:
        # Return a default tip if model isn't loaded
        default_tips = [
            "Take regular breaks from your screen every 30 minutes.",
            "Practice deep breathing exercises when feeling stressed.",
            "Set boundaries for your device usage, especially before bedtime.",
            "Consider a short meditation session to improve focus.",
            "Stay hydrated and maintain physical activity throughout the day."
        ]
        return random.choice(default_tips)
    
    try:
        # Format the input as shown in the examples
        instruction = f"The user has an anxiety level of {anxiety} and a stress level of {stress}."
        model_input = f"{anxiety} {stress} {screen_time} {unlock_count}"
        
        # Create the prompt
        prompt = f"""
        <|system|>
        You are a mental health assistant that provides brief, helpful tips.
        </|system|>
        
        <|user|>
        {instruction}
        {model_input}
        </|user|>
        
        <|assistant|>
        """
        
        # Generate the response
        inputs = custom_tokenizer(prompt, return_tensors="pt").to("cuda")
        outputs = custom_model.generate(
            **inputs,
            max_new_tokens=100,
            temperature=0.7,
            top_p=0.9,
            repetition_penalty=1.2,
            pad_token_id=custom_tokenizer.eos_token_id
        )
        
        response = custom_tokenizer.decode(outputs[0], skip_special_tokens=True)
        
        # Extract just the assistant's response
        if "<|assistant|>" in response:
            response = response.split("<|assistant|>")[1].strip()
        
        logger.info(f"Generated custom tip: {response}")
        return response
    except Exception as e:
        logger.error(f"Error generating custom tip: {e}")
        return "Take regular breaks and be mindful of your screen time."

# Add a new endpoint for getting personalized tips
@app.route('/get_custom_tip', methods=['POST'])
def get_custom_tip():
    try:
        data = request.json
        
        # Extract parameters for the model
        anxiety_level = int(data.get('anxiety_level', 5))
        stress_level = int(data.get('stress_level', 5))
        
        # Extract screen time (convert from "Xm" format to just the number)
        screen_time_str = data.get('screen_time', '240m')
        screen_time = int(screen_time_str.replace('m', '')) if 'm' in screen_time_str else int(screen_time_str)
        
        # Extract unlock count
        unlock_count = int(data.get('unlock_count', '50'))
        
        # Generate tip
        tip = generate_custom_tip(anxiety_level, stress_level, screen_time, unlock_count)
        
        return jsonify({
            "success": True,
            "tip": tip,
            "using_custom_model": custom_model is not None
        })
        
    except Exception as e:
        logger.error(f"Error generating custom tip: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

# Updated health check endpoint with more diagnostics
@app.route('/health', methods=['GET'])
def health_check():
    try:
        # Include more diagnostic info
        return jsonify({
            "status": "healthy",
            "ai_status": "active" if model else "disabled",
            "custom_model_status": "active" if custom_model else "disabled",
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
        insights = response.text
        logger.info(f"Generated insights successfully")
        
        # Log processing time
        processing_time = (datetime.datetime.now() - start_time).total_seconds()
        logger.info(f"Request processed in {processing_time:.2f} seconds")
        
        return jsonify({
            "success": True,
            "insights": insights,
            "mode": "ai",
            "processing_time_seconds": processing_time
        })
        
    except Exception as e:
        logger.error(f"Error generating mental health insights: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

if __name__ == '__main__':
    # Binding to 0.0.0.0 instead of localhost allows connections from other devices
    app.run(host='0.0.0.0', port=5000, debug=True)
