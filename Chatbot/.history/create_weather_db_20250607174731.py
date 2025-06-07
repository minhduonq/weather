import mysql.connector
from mysql.connector import Error

def create_weather_database():
    try:
        # Connect to MySQL server using settings from db.js
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
        
        if connection.is_connected():
            cursor = connection.cursor()
            
            # Create database if not exists
            cursor.execute("DROP DATABASE IF EXISTS weather")
            cursor.execute("CREATE DATABASE weather")
            cursor.execute("USE weather")
            
            # Create location table
            cursor.execute('''
            CREATE TABLE IF NOT EXISTS location(
                id INT AUTO_INCREMENT PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                latitude DOUBLE,
                longitude DOUBLE
            );
            ''')
            
            # Create weather_data table
            cursor.execute('''
            CREATE TABLE IF NOT EXISTS weather_data(
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
            
            # Create hourly_data table
            cursor.execute('''
            CREATE TABLE IF NOT EXISTS hourly_data(
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
            
            # Create daily_data table
            cursor.execute('''
            CREATE TABLE IF NOT EXISTS daily_data(
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
            
            # Create setting table
            cursor.execute('''
            CREATE TABLE IF NOT EXISTS setting(
                unit VARCHAR(50) NOT NULL,
                theme VARCHAR(50) NOT NULL,
                language VARCHAR(50) NOT NULL,
                notification_enabled TINYINT NOT NULL
            );
            ''')
            
            # Create search_history table
            cursor.execute('''
            CREATE TABLE IF NOT EXISTS search_history(
                location VARCHAR(255) NOT NULL,
                searched_at VARCHAR(255) NOT NULL,
                lat DOUBLE NOT NULL,
                lon DOUBLE NOT NULL
            );
            ''')
            
            # Insert default settings
            cursor.execute('''
            INSERT INTO setting (unit, theme, language, notification_enabled)
            VALUES ('metric', 'light', 'en', 1);
            ''')
            
            # Insert sample location
            cursor.execute('''
                INSERT INTO location (name)
                VALUES 
                    ('Ho Chi Minh City'),
                    ('Ha Noi'),
                    ('Da Nang'),
                    ('New York'),
                    ('London'),
                    ('Paris'),
                    ('Tokyo'),
                    ('Sydney'),
                    ('Moscow'),
                    ('Berlin')
            ''')

            
            # Commit changes
            connection.commit()
            print("Database 'weather' created successfully with all tables!")
            
    except Error as e:
        print(f"Error: {e}")
        
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()
            print("MySQL connection is closed")

if __name__ == "__main__":
    create_weather_database() 