const pool = require('../db');
const { v4: uuidv4 } = require('uuid');
const bcrypt = require('bcrypt');

class User {
    static async create(username, email, password) {
        try {
            const userId = uuidv4();
            const passwordHash = await bcrypt.hash(password, 10);

            const [result] = await pool.execute(
                'INSERT INTO users (user_id, username, email, password_hash) VALUES (?, ?, ?, ?)',
                [userId, username, email, passwordHash]
            );

            return userId;
        } catch (error) {
            console.error('Error creating user:', error);
            throw error;
        }
    }

    static async getById(userId) {
        try {
            const [rows] = await pool.execute(
                'SELECT user_id, username, email, created_at, last_login, is_active FROM users WHERE user_id = ?',
                [userId]
            );
            return rows[0];
        } catch (error) {
            console.error('Error fetching user:', error);
            throw error;
        }
    }

    static async getByUsername(username) {
        try {
            const [rows] = await pool.execute(
                'SELECT * FROM users WHERE username = ?',
                [username]
            );
            return rows[0];
        } catch (error) {
            console.error('Error fetching user by username:', error);
            throw error;
        }
    }

    static async login(username, password) {
        try {
            const user = await this.getByUsername(username);

            if (!user) {
                return null;
            }

            const passwordMatch = await bcrypt.compare(password, user.password_hash);

            if (passwordMatch) {
                await pool.execute(
                    'UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE user_id = ?',
                    [user.user_id]
                );

                return {
                    user_id: user.user_id,
                    username: user.username,
                    email: user.email
                };
            }

            return null;
        } catch (error) {
            console.error('Error during login:', error);
            throw error;
        }
    }
}

module.exports = User;