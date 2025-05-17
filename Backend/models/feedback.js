const pool = require('../db');
const { v4: uuidv4 } = require('uuid');

class Feedback {
    static async create(messageId, rating, comment = null) {
        try {
            const feedbackId = uuidv4();
            const [result] = await pool.execute(
                'INSERT INTO feedback (feedback_id, message_id, rating, comment) VALUES (?, ?, ?, ?)',
                [feedbackId, messageId, rating, comment]
            );
            return feedbackId;
        } catch (error) {
            console.error('Error creating feedback:', error);
            throw error;
        }
    }

    static async getByMessageId(messageId) {
        try {
            const [rows] = await pool.execute(
                'SELECT * FROM feedback WHERE message_id = ?',
                [messageId]
            );
            return rows;
        } catch (error) {
            console.error('Error fetching feedback:', error);
            throw error;
        }
    }
}

module.exports = Feedback;