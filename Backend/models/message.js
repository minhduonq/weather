const pool = require('../db');
const { v4: uuidv4 } = require('uuid');

class Message {
    static async create(conversationId, content, isFromUser, userId = null, referencedChunks = null) {
        try {
            const messageId = uuidv4();
            const [result] = await pool.execute(
                'INSERT INTO messages (message_id, conversation_id, user_id, content, is_from_user, referenced_chunks) VALUES (?, ?, ?, ?, ?, ?)',
                [messageId, conversationId, userId, content, isFromUser, referencedChunks ? JSON.stringify(referencedChunks) : null]
            );

            // Update conversation timestamp
            await pool.execute('UPDATE conversations SET updated_at = CURRENT_TIMESTAMP WHERE conversation_id = ?', [conversationId]);

            return messageId;
        } catch (error) {
            console.error('Error creating message:', error);
            throw error;
        }
    }

    static async getConversationMessages(conversationId) {
        try {
            const [rows] = await pool.execute(
                'SELECT * FROM messages WHERE conversation_id = ? ORDER BY timestamp',
                [conversationId]
            );
            return rows;
        } catch (error) {
            console.error('Error fetching conversation messages:', error);
            throw error;
        }
    }

    static async getById(messageId) {
        try {
            const [rows] = await pool.execute(
                'SELECT * FROM messages WHERE message_id = ?',
                [messageId]
            );
            return rows[0];
        } catch (error) {
            console.error('Error fetching message:', error);
            throw error;
        }
    }
}

module.exports = Message;