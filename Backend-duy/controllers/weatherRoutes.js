const express = require('express');
const axios = require('axios');
const router = express.Router();

require('dotenv').config();

// Lấy dữ liệu thời tiết hàng ngày
router.get('/daily', async (req, res) => {
    const lat = req.query.lat;
    const lon = req.query.lon;
    try {
        const API_KEY = process.env.API_KEY;
        console.log('API_KEY:', API_KEY);
        const url = `https://api.openweathermap.org/data/2.5/forecast/daily?lat=${lat}&lon=${lon}&cnt=7&appid=${API_KEY}`;
        const response = await axios.get(url);
        res.json(response.data);
    } catch (error) {
        console.error('Error fetching daily weather:', error);
        res.status(500).json({ error: 'Failed to fetch daily weather data' });
    }
});

// Lấy dữ liệu thời tiết hàng giờ
router.get('/hourly', async (req, res) => {
    const lat = req.query.lat;
    const lon = req.query.lon;
    try {
        const API_KEY = process.env.API_KEY;
        const url = `https://pro.openweathermap.org/data/2.5/forecast/hourly?lat=${lat}&lon=${lon}&appid=${API_KEY}`;
        const response = await axios.get(url);
        res.json(response.data);
    } catch (error) {
        console.error('Error fetching hourly weather:', error);
        res.status(500).json({ error: 'Failed to fetch hourly weather data' });
    }
});

// Lấy chi tiết thời tiết hiện tại
router.get('/detail', async (req, res) => {
    const lat = req.query.lat;
    const lon = req.query.lon;
    try {
        const API_KEY = process.env.API_KEY || '2b5630205440fa5d9747bc910681e783';
        const url = `https://api.openweathermap.org/data/2.5/weather?lat=${lat}&lon=${lon}&appid=${API_KEY}`;
        const response = await axios.get(url);
        res.json(response.data);
    } catch (error) {
        console.error('Error fetching weather details:', error);
        res.status(500).json({ error: 'Failed to fetch weather details' });
    }
});

router.get('/location', async (req, res) => {
    const name = req.query.name;
    try {
        const API_KEY = process.env.API_KEY;
        const url = `http://api.openweathermap.org/geo/1.0/direct?q=${name}&limit=3&appid=${API_KEY}`;
        const response = await axios.get(url);
        res.json(response.data);
    } catch (error) {
        console.error('Error fetching location:', error);
        res.status(500).json({ error: 'Failed to fetch location data' });
    }
})

router.get('/', (req, res) => {
    res.json({ message: 'Welcome to the weather API!' });
}
);

module.exports = router;