const pool = require('../db');
const { v4: uuidv4 } = require('uuid');

class WeatherData {
    static async create(location, temperature, humidity, windSpeed, windDirection, description, forecastDate) {
        try {
            const weatherId = uuidv4();
            const [result] = await pool.execute(
                'INSERT INTO weather_data (weather_id, location, temperature, humidity, wind_speed, wind_direction, description, forecast_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
                [weatherId, location, temperature, humidity, windSpeed, windDirection, description, forecastDate]
            );
            return weatherId;
        } catch (error) {
            console.error('Error creating weather data:', error);
            throw error;
        }
    }

    static async getByLocation(location) {
        try {
            const [rows] = await pool.execute(
                'SELECT * FROM weather_data WHERE location = ? ORDER BY forecast_date DESC',
                [location]
            );
            return rows;
        } catch (error) {
            console.error('Error fetching weather data:', error);
            throw error;
        }
    }

    static async getLatestByLocation(location) {
        try {
            const [rows] = await pool.execute(
                'SELECT * FROM weather_data WHERE location = ? ORDER BY forecast_date DESC LIMIT 1',
                [location]
            );
            return rows[0];
        } catch (error) {
            console.error('Error fetching latest weather data:', error);
            throw error;
        }
    }

    static async getForecast(location, days = 5) {
        try {
            const [rows] = await pool.execute(
                'SELECT * FROM weather_data WHERE location = ? AND forecast_date >= CURDATE() ORDER BY forecast_date LIMIT ?',
                [location, days]
            );
            return rows;
        } catch (error) {
            console.error('Error fetching weather forecast:', error);
            throw error;
        }
    }
}

module.exports = WeatherData;