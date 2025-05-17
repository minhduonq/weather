const pool = require('../db');
const { v4: uuidv4 } = require('uuid');

class Document {
    static async create(title, content, sourceUrl = null, author = null, category = null) {
        try {
            const documentId = uuidv4();
            const [result] = await pool.execute(
                'INSERT INTO documents (document_id, title, content, source_url, author, category) VALUES (?, ?, ?, ?, ?, ?)',
                [documentId, title, content, sourceUrl, author, category]
            );
            return documentId;
        } catch (error) {
            console.error('Error creating document:', error);
            throw error;
        }
    }

    static async getById(documentId) {
        try {
            const [rows] = await pool.execute(
                'SELECT * FROM documents WHERE document_id = ?',
                [documentId]
            );
            return rows[0];
        } catch (error) {
            console.error('Error fetching document:', error);
            throw error;
        }
    }

    static async getAllDocuments(limit = 100, offset = 0) {
        try {
            const [rows] = await pool.execute(
                'SELECT * FROM documents WHERE is_active = TRUE ORDER BY created_at DESC LIMIT ? OFFSET ?',
                [limit, offset]
            );
            return rows;
        } catch (error) {
            console.error('Error fetching documents:', error);
            throw error;
        }
    }

    static async update(documentId, data) {
        try {
            const allowedFields = ['title', 'content', 'source_url', 'author', 'category', 'is_active'];
            const fields = Object.keys(data).filter(key => allowedFields.includes(key));

            if (fields.length === 0) {
                throw new Error('No valid fields to update');
            }

            const sql = `UPDATE documents SET ${fields.map(field => `${field} = ?`).join(', ')} WHERE document_id = ?`;
            const values = [...fields.map(field => data[field]), documentId];

            const [result] = await pool.execute(sql, values);
            return result.affectedRows > 0;
        } catch (error) {
            console.error('Error updating document:', error);
            throw error;
        }
    }

    static async delete(documentId) {
        try {
            const [result] = await pool.execute(
                'DELETE FROM documents WHERE document_id = ?',
                [documentId]
            );
            return result.affectedRows > 0;
        } catch (error) {
            console.error('Error deleting document:', error);
            throw error;
        }
    }
}

module.exports = Document;