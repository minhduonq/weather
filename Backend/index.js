const express = require('express');
const cors = require('cors');
const db = require('./db');
const userRoutes = require('./controllers/userRoutes');
const weatherRoutes = require('./controllers/weatherRoutes'); // Import weather routes

require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json());
app.use(cors());

// Kiểm tra kết nối MySQL
db.execute('SELECT 1')
    .then(() => console.log('Kết nối MySQL thành công!'))
    .catch(err => console.error('Kết nối MySQL thất bại:', err));

// Sử dụng routes
app.use('/api/users', userRoutes); // Route cho người dùng
app.use('/weather', weatherRoutes); // Route cho thời tiết

// Khởi động server
app.listen(PORT, () => {
    console.log(`Server chạy tại http://localhost:${PORT}`);
});