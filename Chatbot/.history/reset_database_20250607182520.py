import mysql.connector
from mysql.connector import Error
import os
from dotenv import load_dotenv

def reset_database():
    try:
        # Load environment variables from .env file
        load_dotenv()
        
        # Get API key from environment variable
        api_key = os.getenv('OPENWEATHER_API_KEY')
        if not api_key:
            print("Warning: OPENWEATHER_API_KEY not found in environment variables")
        
        # Connect to MySQL server
        connection = mysql.connector.connect(
            host='localhost',
            user='root',
            password='',
            database='weather',
            port = 3307 ,
        )
        
        if connection.is_connected():
            cursor = connection.cursor()
            
            # Drop database if exists
            cursor.execute("DROP DATABASE IF EXISTS weather")
            print("Dropped existing weather database")
            
            # Create database
            cursor.execute("CREATE DATABASE weather")
            cursor.execute("USE weather")
            print("Created new weather database")
            
            # Create location table
            cursor.execute('''
            CREATE TABLE location(
                id INT PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                latitude DOUBLE NOT NULL,
                longitude DOUBLE NOT NULL
            );
            ''')
            print("Created location table")
            
            # Create weather_data table
            cursor.execute('''
            CREATE TABLE weather_data(
                id INT AUTO_INCREMENT PRIMARY KEY,
                location_id INT NOT NULL,
                temperature DOUBLE,
                feelsLike DOUBLE,
                maxTemp DOUBLE,
                minTemp DOUBLE,
                pressure INT,
                humidity INT,
                windSpeed DOUBLE,
                windDeg DOUBLE,
                windGust DOUBLE,
                icon VARCHAR(255),
                timeZone INT,
                cloud INT,
                visibility INT,
                sunrise INT,
                sunset INT,
                description TEXT,
                main VARCHAR(255),
                updatedAt VARCHAR(255),
                FOREIGN KEY (location_id) REFERENCES location(id) ON DELETE CASCADE
            );
            ''')
            print("Created weather_data table")
            
            # Create hourly_data table
            cursor.execute('''
            CREATE TABLE hourly_data(
                id INT AUTO_INCREMENT PRIMARY KEY,
                location_id INT NOT NULL,
                time INT,
                temperatureMax DOUBLE,
                temperatureMin DOUBLE,
                humidity INT,
                icon VARCHAR(255),
                FOREIGN KEY (location_id) REFERENCES location(id) ON DELETE CASCADE
            );
            ''')
            print("Created hourly_data table")
            
            # Create daily_data table
            cursor.execute('''
            CREATE TABLE daily_data(
                id INT AUTO_INCREMENT PRIMARY KEY,
                location_id INT NOT NULL,
                time INT,
                temperatureMax DOUBLE,
                temperatureMin DOUBLE,
                humidity INT,
                icon VARCHAR(255),
                FOREIGN KEY (location_id) REFERENCES location(id) ON DELETE CASCADE
            );
            ''')
            print("Created daily_data table")
            
            # Create setting table
            cursor.execute('''
            CREATE TABLE setting(
                unit VARCHAR(50) NOT NULL,
                theme VARCHAR(50) NOT NULL,
                language VARCHAR(50) NOT NULL,
                notification_enabled TINYINT NOT NULL
            );
            ''')
            print("Created setting table")
            
            # Create search_history table
            cursor.execute('''
            CREATE TABLE search_history(
                location VARCHAR(255) NOT NULL,
                searched_at VARCHAR(255) NOT NULL,
                lat DOUBLE NOT NULL,
                lon DOUBLE NOT NULL
            );
            ''')
            print("Created search_history table")
            
            # Create api_keys table
            cursor.execute('''
            CREATE TABLE api_keys(
                id INT AUTO_INCREMENT PRIMARY KEY,
                service_name VARCHAR(50) NOT NULL,
                api_key VARCHAR(255) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            );
            ''')
            print("Created api_keys table")
            
            # Create chat_history table
            cursor.execute('''
            CREATE TABLE chat_history(
                id INT AUTO_INCREMENT PRIMARY KEY,
                conversation_id VARCHAR(255) NOT NULL,
                message TEXT NOT NULL,
                response TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                location_id INT,
                weather_data_id INT,
                FOREIGN KEY (location_id) REFERENCES location(id) ON DELETE SET NULL,
                FOREIGN KEY (weather_data_id) REFERENCES weather_data(id) ON DELETE SET NULL
            );
            ''')
            print("Created chat_history table")
            
            # Insert default settings
            cursor.execute('''
            INSERT INTO setting (unit, theme, language, notification_enabled)
            VALUES ('metric', 'light', 'en', 1);
            ''')
            print("Inserted default settings")
            
            # Insert sample location
            cursor.execute('''
            INSERT INTO location (id, name, latitude, longitude)
            VALUES (1, 'Ho Chi Minh City', 10.7756587, 106.7004238);
            ''')
            print("Inserted sample location")
            
            # Insert OpenWeather API key if available
            if api_key:
                cursor.execute('''
                INSERT INTO api_keys (service_name, api_key)
                VALUES ('openweather', %s)
                ON DUPLICATE KEY UPDATE api_key = VALUES(api_key);
                ''', (api_key,))
                print("OpenWeather API key has been stored in the database")
            
            # Commit changes
            connection.commit()
            print("Database reset completed successfully!")
            
    except Error as e:
        print(f"Error: {e}")
        
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()
            print("MySQL connection is closed")

if __name__ == "__main__":
    reset_database() 