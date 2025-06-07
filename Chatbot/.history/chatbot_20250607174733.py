import asyncio
from dotenv import load_dotenv, find_dotenv
import os
from openai import AsyncAzureOpenAI
import mysql.connector
from mysql.connector import Error
from datetime import datetime

from pydantic_ai import Agent, RunContext
from pydantic_ai.common_tools.tavily import tavily_search_tool
from pydantic_ai.messages import ModelMessage
from pydantic_ai.models.gemini import GeminiModel
from pydantic_ai.providers.google_gla import GoogleGLAProvider
from pydantic import BaseModel

from dataclasses import asdict

from fastapi import FastAPI
from fastapi.responses import StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
load_dotenv(find_dotenv())

GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
model = GeminiModel(
    'gemini-2.0-flash', provider=GoogleGLAProvider(api_key=GEMINI_API_KEY)
)
agent = Agent(model)

def get_db_connection():
    """Create and return a database connection"""
    try:
        connection = mysql.connector.connect(
            host='localhost',
            user='root',
            password='',
            database='weather',
            port = 3307 ,
            charset='utf8mb4',  
            collation='utf8mb4_unicode_ci',
            use_unicode=True
        )
        return connection
    except Error as e:
        print(f"Error connecting to MySQL database: {e}")
        return None

@agent.tool
async def get_latitute_longtitue(ctx, location: str) -> tuple[float, float]:
    """Get latitude and longtitude from location"""
    print(f"Getting coordinates for location: {location}")
    connection = get_db_connection()
    if connection:
        try:
            cursor = connection.cursor()
            # First check if location exists in location table (case-insensitive)
            cursor.execute("SELECT latitude, longitude FROM location WHERE LOWER(name) = LOWER(%s)", (location,))
            result = cursor.fetchone()
            if result:
                return result
            
            # If not found in location table, check search_history (case-insensitive)
            cursor.execute("SELECT lat, lon FROM search_history WHERE LOWER(location) = LOWER(%s) ORDER BY searched_at DESC LIMIT 1", (location,))
            result = cursor.fetchone()
            if result:
                return result
            
            return None
        except Error as e:
            print(f"Error querying database: {e}")
            return None
        finally:
            cursor.close()
            connection.close()
    return None

@agent.tool
async def get_current_weather(ctx, latitude: float, longtitude: float):
    """Query weather databases to get current temperature for location defined by its latitude and longtitude"""
    print(f"Getting weather for coordinates: {latitude}, {longtitude}")
    connection = get_db_connection()
    if connection:
        try:
            cursor = connection.cursor(dictionary=True)
            # First find the location_id
            cursor.execute("SELECT id FROM location WHERE latitude = %s AND longitude = %s", (latitude, longtitude))
            location = cursor.fetchone()
            
            if location:
                # Get current weather data
                cursor.execute("""
                    SELECT temperature, feelsLike, humidity, windSpeed, description, main, icon, updatedAt
                    FROM weather_data
                    WHERE location_id = %s
                    ORDER BY updatedAt DESC
                    LIMIT 1
                """, (location['id'],))
                weather = cursor.fetchone()
                
                if weather:
                    return {
                        'temperature': weather['temperature'],
                        'feels_like': weather['feelsLike'],
                        'humidity': weather['humidity'],
                        'wind_speed': weather['windSpeed'],
                        'description': weather['description'],
                        'main': weather['main'],
                        'icon': weather['icon'],
                        'updated_at': weather['updatedAt']
                    }
            
            return None
        except Error as e:
            print(f"Error querying database: {e}")
            return None
        finally:
            cursor.close()
            connection.close()
    return None

@agent.tool
async def get_hourly_forecast(ctx, latitude: float, longtitude: float):
    """Get hourly weather forecast for the next 24 hours"""
    print(f"Getting hourly forecast for coordinates: {latitude}, {longtitude}")
    connection = get_db_connection()
    if connection:
        try:
            cursor = connection.cursor(dictionary=True)
            # Find the location_id
            cursor.execute("SELECT id FROM location WHERE latitude = %s AND longitude = %s", (latitude, longtitude))
            location = cursor.fetchone()
            
            if location:
                # Get hourly forecast data
                cursor.execute("""
                    SELECT time, temperatureMax, temperatureMin, humidity, icon
                    FROM hourly_data
                    WHERE location_id = %s
                    ORDER BY time ASC
                    LIMIT 24
                """, (location['id'],))
                forecast = cursor.fetchall()
                
                if forecast:
                    return [{
                        'time': datetime.fromtimestamp(item['time']).strftime('%H:%M:%S'),
                        'temperature_max': item['temperatureMax'],
                        'temperature_min': item['temperatureMin'],
                        'humidity': item['humidity'],
                        'icon': item['icon']
                    } for item in forecast]
            
            return None
        except Error as e:
            print(f"Error querying database: {e}")
            return None
        finally:
            cursor.close()
            connection.close()
    return None

@agent.tool
async def get_daily_forecast(ctx, latitude: float, longtitude: float):
    """Get daily weather forecast for the next 7 days"""
    print(f"Getting daily forecast for coordinates: {latitude}, {longtitude}")
    connection = get_db_connection()
    if connection:
        try:
            cursor = connection.cursor(dictionary=True)
            # Find the location_id
            cursor.execute("SELECT id FROM location WHERE latitude = %s AND longitude = %s", (latitude, longtitude))
            location = cursor.fetchone()
            
            if location:
                # Get daily forecast data
                cursor.execute("""
                    SELECT time, temperatureMax, temperatureMin, humidity, icon
                    FROM daily_data
                    WHERE location_id = %s
                    ORDER BY time ASC
                    LIMIT 7
                """, (location['id'],))
                forecast = cursor.fetchall()
                
                if forecast:
                    return [{
                        'time': datetime.fromtimestamp(item['time']).strftime('%d/%m/%Y'),
                        'temperature_max': item['temperatureMax'],
                        'temperature_min': item['temperatureMin'],
                        'humidity': item['humidity'],
                        'icon': item['icon']
                    } for item in forecast]
            
            return None
        except Error as e:
            print(f"Error querying database: {e}")
            return None
        finally:
            cursor.close()
            connection.close()
    return None

@agent.tool
async def recommend_outfit(ctx, latitude: float, longtitude: float):
    """Analyze weather data and recommend appropriate clothing and accessories"""
    print(f"Getting recommendations for coordinates: {latitude}, {longtitude}")
    
    # Get all weather data
    current_weather = await get_current_weather(ctx, latitude, longtitude)
    hourly_forecast = await get_hourly_forecast(ctx, latitude, longtitude)
    daily_forecast = await get_daily_forecast(ctx, latitude, longtitude)
    
    if not current_weather:
        return "Không thể lấy thông tin thời tiết hiện tại."
    
    recommendations = {
        "clothing": [],
        "accessories": [],
        "activities": [],
        "precautions": []
    }
    
    # Analyze current temperature
    temp = current_weather['temperature']
    if temp < 10:
        recommendations["clothing"].extend([
            "Áo khoác dày hoặc áo len",
            "Quần dài",
            "Giày kín",
            "Găng tay",
            "Khăn quàng cổ"
        ])
        recommendations["precautions"].append("Cần mặc ấm để tránh cảm lạnh")
    elif temp < 20:
        recommendations["clothing"].extend([
            "Áo khoác mỏng hoặc áo len nhẹ",
            "Quần dài",
            "Giày kín"
        ])
    elif temp < 25:
        recommendations["clothing"].extend([
            "Áo dài tay mỏng",
            "Quần dài",
            "Giày thể thao"
        ])
    else:
        recommendations["clothing"].extend([
            "Áo ngắn tay",
            "Quần ngắn",
            "Giày sandal hoặc dép"
        ])
    
    # Analyze weather conditions
    weather_main = current_weather['main'].lower()
    if 'rain' in weather_main:
        recommendations["accessories"].extend([
            "Áo mưa",
            "Ô",
            "Giày không thấm nước"
        ])
        recommendations["precautions"].append("Mang theo ô hoặc áo mưa")
    elif 'snow' in weather_main:
        recommendations["accessories"].extend([
            "Giày chống trơn",
            "Găng tay chống nước"
        ])
        recommendations["precautions"].append("Cẩn thận đường trơn")
    elif 'clear' in weather_main or 'sun' in weather_main:
        recommendations["accessories"].extend([
            "Kính râm",
            "Mũ",
            "Kem chống nắng"
        ])
        recommendations["precautions"].append("Bảo vệ da khỏi tia UV")
    
    # Analyze humidity
    humidity = current_weather['humidity']
    if humidity > 80:
        recommendations["precautions"].append("Độ ẩm cao, nên mặc quần áo thoáng mát")
    elif humidity < 30:
        recommendations["precautions"].append("Độ ẩm thấp, nên uống nhiều nước")
    
    # Analyze wind speed
    wind_speed = current_weather['wind_speed']
    if wind_speed > 20:
        recommendations["accessories"].append("Mũ chống gió")
        recommendations["precautions"].append("Gió mạnh, cẩn thận khi di chuyển")
    
    # Suggest activities based on weather
    if 'clear' in weather_main or 'sun' in weather_main:
        if 20 <= temp <= 28:
            recommendations["activities"].extend([
                "Dã ngoại",
                "Đi bộ",
                "Chơi thể thao ngoài trời"
            ])
    elif 'rain' in weather_main:
        recommendations["activities"].extend([
            "Hoạt động trong nhà",
            "Xem phim",
            "Đọc sách"
        ])
    
    # Format recommendations
    response = {
        "current_weather": {
            "temperature": temp,
            "description": current_weather['description'],
            "humidity": humidity,
            "wind_speed": wind_speed
        },
        "recommendations": recommendations
    }
    
    return response

conversations_history: dict[str, list[ModelMessage]] = {}

async def chat(conversation_id: str, message: str):
    conversations = conversations_history.get(conversation_id, [])
    async with agent.run_stream(message, message_history=conversations) as response:
        async for token in response.stream_text(delta=True):
            yield token
        conversations.extend(response.new_messages())
        conversations_history[conversation_id] = conversations

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class MessageRequest(BaseModel):
    uid: str
    message: str

@app.post("/chat")
async def chat_endpoint(message: MessageRequest):
    async def generate_response():
        async for token in chat(message.uid, message.message):
            yield token.encode('utf-8').decode('utf-8')
    
    return StreamingResponse(
        generate_response(),
        media_type="text/plain; charset=utf-8"  
    )