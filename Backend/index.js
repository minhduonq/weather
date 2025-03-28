const express = require('express');
const axios = require('axios');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());

// Route để lấy dữ liệu thời tiết
app.get('/weather', async (req, res) => {
    let lat, lon;
    try {
        const API_KEY = '2b5630205440fa5d9747bc910681e783';
        lat = 21.036861253195692;
        lon = 105.78316890563965;
        const url = `https://api.openweathermap.org/data/2.5/forecast/daily?lat=${lat}&lon=${lon}&cnt=7&appid=${API_KEY}&units=metric`;
        console.log(API_KEY)
        const response = await axios.get(url);
        res.json(response.data);
    } catch (error) {
        res.status(500).json({ error: 'Failed to fetch weather data' });
    }
});

app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});
