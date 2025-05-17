
const express = require('express');
const router = express.Router();
const WeatherData = require('../models/weather');
const ApiLog = require('../models/apiLog');
const authenticate = require('../middleware/authenticate');

// Get weather data by location
router.get('/:location', authenticate, async (req, res) => {
    const startTime = Date.now();
    try {
        const { location } = req.params;

        const weatherData = await WeatherData.getByLocation(location);

        // Log the API call
        await ApiLog.create(
            'get_weather',
            { location },
            weatherData,
            200,
            Date.now() - startTime,
            req.user.userId
        );

        res.json({ weatherData });
    } catch (error) {
        console.error('Error fetching weather data:', error);
        res.status(500).json({ error: 'Failed to fetch weather data' });
    }
});

// Get latest weather by location
router.get('/:location/latest', authenticate, async (req, res) => {
    try {
        const { location } = req.params;

        const weatherData = await WeatherData.getLatestByLocation(location);

        if (!weatherData) {
            return res.status(404).json({ error: 'Weather data not found for this location' });
        }

        res.json({ weatherData });
    } catch (error) {
        console.error('Error fetching latest weather:', error);
        res.status(500).json({ error: 'Failed to fetch latest weather' });
    }
});

// Get weather forecast for location
router.get('/:location/forecast', authenticate, async (req, res) => {
    try {
        const { location } = req.params;
        const { days = 5 } = req.query;

        const forecast = await WeatherData.getForecast(location, parseInt(days));

        res.json({ forecast });
    } catch (error) {
        console.error('Error fetching weather forecast:', error);
        res.status(500).json({ error: 'Failed to fetch weather forecast' });
    }
});

// Add weather data (admin only)
router.post('/', authenticate, async (req, res) => {
    try {
        const { location, temperature, humidity, windSpeed, windDirection, description, forecastDate } = req.body;

        const weatherId = await WeatherData.create(
            location,
            temperature,
            humidity,
            windSpeed,
            windDirection,
            description,
            forecastDate
        );

        res.status(201).json({
            message: 'Weather data added successfully',
            weatherId
        });
    } catch (error) {
        console.error('Error adding weather data:', error);
        res.status(500).json({ error: 'Failed to add weather data' });
    }
});

module.exports = router;