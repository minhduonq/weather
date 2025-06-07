import os
import requests
from datetime import datetime
import mysql.connector
from mysql.connector import Error
from dotenv import load_dotenv
import time

def get_db_connection():
    """Create and return a database connection"""
    try:
        connection = mysql.connector.connect(
            host='localhost',
            user='root',
            password='',
            database='weather'
            
        )
        return connection
    except Error as e:
        print(f"Error connecting to MySQL database: {e}")
        return None

def get_api_key():
    """Get OpenWeather API key from .env file"""
    load_dotenv()
    api_key = os.getenv('OPENWEATHER_API_KEY')
    if not api_key:
        print("Error: OPENWEATHER_API_KEY not found in .env file")
        return None
    print(f"Using API key: {api_key}")
    return api_key

def get_locations():
    """Get all locations from database"""
    connection = get_db_connection()
    if connection:
        try:
            cursor = connection.cursor(dictionary=True)
            cursor.execute("SELECT id, name, latitude, longitude FROM location")
            return cursor.fetchall()
        except Error as e:
            print(f"Error getting locations: {e}")
            return []
        finally:
            cursor.close()
            connection.close()
    return []

def update_location_coordinates(location_id: int, latitude: float, longitude: float):
    """Update location coordinates in database"""
    connection = get_db_connection()
    if connection:
        try:
            cursor = connection.cursor()
            cursor.execute('''
                UPDATE location 
                SET latitude = %s, longitude = %s
                WHERE id = %s
            ''', (latitude, longitude, location_id))
            connection.commit()
            print(f"Updated coordinates for location ID {location_id}")
        except Error as e:
            print(f"Error updating coordinates: {e}")
        finally:
            cursor.close()
            connection.close()

def save_weather_data(location_id: int, weather_data: dict):
    """Save current weather data to database"""
    connection = get_db_connection()
    if connection:
        try:
            cursor = connection.cursor()
            cursor.execute('''
                INSERT INTO weather_data 
                (id, location_id, temperature, feelsLike, maxTemp, minTemp, pressure, humidity,
                windSpeed, windDeg, windGust, icon, timeZone, cloud, visibility,
                sunrise, sunset, description, main, updatedAt)
                VALUES (NULL, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ''', (
                location_id,
                weather_data['main']['temp'],
                weather_data['main']['feels_like'],
                weather_data['main']['temp_max'],
                weather_data['main']['temp_min'],
                weather_data['main']['pressure'],
                weather_data['main']['humidity'],
                weather_data['wind']['speed'],
                weather_data['wind']['deg'],
                weather_data['wind'].get('gust', 0),
                weather_data['weather'][0]['icon'],
                weather_data['timezone'],
                weather_data['clouds']['all'],
                weather_data['visibility'],
                weather_data['sys']['sunrise'],
                weather_data['sys']['sunset'],
                weather_data['weather'][0]['description'],
                weather_data['weather'][0]['main'],
                datetime.now().isoformat()
            ))
            connection.commit()
            return cursor.lastrowid
        except Error as e:
            print(f"Error saving weather data: {e}")
            return None
        finally:
            cursor.close()
            connection.close()
    return None

def save_hourly_forecast(location_id: int, forecast_data: list):
    """Save hourly forecast data to database"""
    connection = get_db_connection()
    if connection:
        try:
            cursor = connection.cursor()
            # Clear existing hourly data for this location
            cursor.execute("DELETE FROM hourly_data WHERE location_id = %s", (location_id,))
            
            # Insert new hourly data
            for item in forecast_data[:24]:  # Only save next 24 hours
                cursor.execute('''
                    INSERT INTO hourly_data 
                    (id, location_id, time, temperatureMax, temperatureMin, humidity, icon)
                    VALUES (NULL, %s, %s, %s, %s, %s, %s)
                ''', (
                    location_id,
                    item['dt'],
                    item['main']['temp_max'],
                    item['main']['temp_min'],
                    item['main']['humidity'],
                    item['weather'][0]['icon']
                ))
            connection.commit()
        except Error as e:
            print(f"Error saving hourly forecast: {e}")
        finally:
            cursor.close()
            connection.close()

def save_daily_forecast(location_id: int, forecast_data: list):
    """Save daily forecast data to database"""
    connection = get_db_connection()
    if connection:
        try:
            cursor = connection.cursor()
            # Clear existing daily data for this location
            cursor.execute("DELETE FROM daily_data WHERE location_id = %s", (location_id,))
            
            # Group forecast data by day
            daily_forecasts = {}
            for item in forecast_data:
                # Convert timestamp to date
                date = datetime.fromtimestamp(item['dt']).date()
                if date not in daily_forecasts:
                    daily_forecasts[date] = {
                        'temp_max': item['main']['temp_max'],
                        'temp_min': item['main']['temp_min'],
                        'humidity': item['main']['humidity'],
                        'icon': item['weather'][0]['icon'],
                        'dt': item['dt']
                    }
                else:
                    # Update max/min temperatures
                    daily_forecasts[date]['temp_max'] = max(daily_forecasts[date]['temp_max'], item['main']['temp_max'])
                    daily_forecasts[date]['temp_min'] = min(daily_forecasts[date]['temp_min'], item['main']['temp_min'])
            
            # Insert daily data
            for date, forecast in daily_forecasts.items():
                cursor.execute('''
                    INSERT INTO daily_data 
                    (id, location_id, time, temperatureMax, temperatureMin, humidity, icon)
                    VALUES (NULL, %s, %s, %s, %s, %s, %s)
                ''', (
                    location_id,
                    forecast['dt'],
                    forecast['temp_max'],
                    forecast['temp_min'],
                    forecast['humidity'],
                    forecast['icon']
                ))
            connection.commit()
        except Error as e:
            print(f"Error saving daily forecast: {e}")
        finally:
            cursor.close()
            connection.close()

def test_api_key(api_key: str) -> bool:
    """Test if the API key is valid by making a simple request"""
    test_url = f"https://api.openweathermap.org/data/2.5/weather?q=London&appid={api_key}"
    try:
        response = requests.get(test_url)
        if response.status_code == 200:
            print("API key is valid!")
            return True
        else:
            print(f"API key test failed with status code: {response.status_code}")
            print(f"Response: {response.text}")
            return False
    except Exception as e:
        print(f"Error testing API key: {e}")
        return False

def fetch_weather_data():
    """Fetch weather data for all locations and save to database"""
    api_key = get_api_key()
    if not api_key:
        print("Error: OpenWeather API key not found")
        return

    locations = get_locations()
    if not locations:
        print("No locations found in database")
        return

    for location in locations:
        print(f"Fetching weather data for {location['name']}...")
        
        # If location doesn't have coordinates, fetch them first
        if location['latitude'] is None or location['longitude'] is None:
            try:
                # Use OpenWeather Geocoding API to get coordinates
                geocode_url = f"https://api.openweathermap.org/geo/1.0/direct?q={location['name']}&limit=1&appid={api_key}"
                response = requests.get(geocode_url)
                response.raise_for_status()
                geocode_data = response.json()
                
                if geocode_data:
                    lat = geocode_data[0]['lat']
                    lon = geocode_data[0]['lon']
                    update_location_coordinates(location['id'], lat, lon)
                    location['latitude'] = lat
                    location['longitude'] = lon
                    print(f"Updated coordinates for {location['name']}: {lat}, {lon}")
                else:
                    print(f"Could not find coordinates for {location['name']}")
                    continue
            except Exception as e:
                print(f"Error fetching coordinates for {location['name']}: {e}")
                continue
        
        # Fetch current weather
        current_url = f"https://api.openweathermap.org/data/2.5/weather?lat={location['latitude']}&lon={location['longitude']}&appid={api_key}&units=metric"
        try:
            response = requests.get(current_url)
            response.raise_for_status()
            weather_data = response.json()
            weather_data_id = save_weather_data(location['id'], weather_data)
            print(f"Current weather data saved for {location['name']}")
        except Exception as e:
            print(f"Error fetching current weather for {location['name']}: {e}")
            if hasattr(e, 'response'):
                print(f"Response status: {e.response.status_code}")
                print(f"Response text: {e.response.text}")
            continue

        # Fetch 5-day forecast
        forecast_url = f"https://api.openweathermap.org/data/2.5/forecast?lat={location['latitude']}&lon={location['longitude']}&appid={api_key}&units=metric"
        try:
            response = requests.get(forecast_url)
            response.raise_for_status()
            forecast_data = response.json()
            
            # Save hourly forecast
            save_hourly_forecast(location['id'], forecast_data['list'])
            print(f"Hourly forecast saved for {location['name']}")
            
            # Save daily forecast (using the same data)
            save_daily_forecast(location['id'], forecast_data['list'])
            print(f"Daily forecast saved for {location['name']}")
        except Exception as e:
            print(f"Error fetching forecast for {location['name']}: {e}")
            if hasattr(e, 'response'):
                print(f"Response status: {e.response.status_code}")
                print(f"Response text: {e.response.text}")

        # Add delay to avoid hitting API rate limits
        time.sleep(1)

if __name__ == "__main__":
    fetch_weather_data() 