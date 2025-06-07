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
            port = 3307
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
            # First check if location exists in location table
            cursor.execute("SELECT latitude, longitude FROM location WHERE name = %s", (location,))
            result = cursor.fetchone()
            if result:
                return result
            
            # If not found in location table, check search_history
            cursor.execute("SELECT lat, lon FROM search_history WHERE location = %s ORDER BY searched_at DESC LIMIT 1", (location,))
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
                        'time': item['time'],
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
                        'time': item['time'],
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

conversations_history: dict[str, list[ModelMessage]] = {}

async def chat(conversation_id: str, message: str):
    conversations = conversations_history.get(conversation_id, [])
    async with agent.run_stream(message, message_history=conversations) as response:
        async for token in response.stream_text(delta=True):
            yield token
        conversations.extend(response.new_messages())
        conversations_history[conversation_id] = conversations

app = FastAPI()

class MessageRequest(BaseModel):
    uid: str
    message: str

@app.post("/chat")
async def chat_endpoint(message: MessageRequest):
    return StreamingResponse(chat(message.uid, message.message))