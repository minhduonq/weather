const pool = require('../db');
const { v4: uuidv4 } = require('uuid');

class Chunk {
    static async create(documentId, chunkText, chunkIndex, embedding = null) {
        try {
            const chunkId = uuidv4();
            const [result] = await pool.execute(
                'INSERT INTO chunks (chunk_id, document_id, chunk_text, chunk_index, embedding) VALUES (?, ?, ?, ?, ?)',
                [chunkId, documentId, chunkText, chunkIndex, embedding ? JSON.stringify(embedding) : null]
            );
            return chunkId;
        } catch (error) {
            console.error('Error creating chunk:', error);
            throw error;
        }
    }

    static async getByDocumentId(documentId) {
        try {
            const [rows] = await pool.execute(
                'SELECT * FROM chunks WHERE document_id = ? ORDER BY chunk_index',
                [documentId]
            );
            return rows;
        } catch (error) {
            console.error('Error fetching chunks:', error);
            throw error;
        }
    }

    static async getById(chunkId) {
        try {
            const [rows] = await pool.execute(
                'SELECT * FROM chunks WHERE chunk_id = ?',
                [chunkId]
            );
            return rows[0];
        } catch (error) {
            console.error('Error fetching chunk:', error);
            throw error;
        }
    }

    static async updateEmbedding(chunkId, embedding) {
        try {
            const [result] = await pool.execute(
                'UPDATE chunks SET embedding = ? WHERE chunk_id = ?',
                [JSON.stringify(embedding), chunkId]
            );
            return result.affectedRows > 0;
        } catch (error) {
            console.error('Error updating chunk embedding:', error);
            throw error;
        }
    }
}

module.exports = Chunk;