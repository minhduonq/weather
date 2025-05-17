const express = require('express');
const router = express.Router();
const Document = require('../models/document');
const Chunk = require('../models/chunk');
const authenticate = require('../middleware/authenticate');

// Admin middleware - example implementation
const isAdmin = (req, res, next) => {
    if (req.user.role === 'admin') {
        next();
    } else {
        res.status(403).json({ error: 'Admin access required' });
    }
};

// Add a new document to the knowledge base
router.post('/', authenticate, isAdmin, async (req, res) => {
    try {
        const { title, content, sourceUrl, author, category } = req.body;

        const documentId = await Document.create(title, content, sourceUrl, author, category);

        // In a real implementation, you would:
        // 1. Split the document into chunks
        // 2. Generate embeddings for each chunk
        // 3. Store chunks with their embeddings

        // Example simple chunking (very naive approach)
        const chunks = content.split('\n\n');
        let chunkIndex = 0;

        for (const chunk of chunks) {
            if (chunk.trim().length > 0) {
                await Chunk.create(documentId, chunk.trim(), chunkIndex);
                chunkIndex++;
            }
        }

        res.status(201).json({
            message: 'Document added successfully',
            documentId,
            chunkCount: chunkIndex
        });
    } catch (error) {
        console.error('Error adding document:', error);
        res.status(500).json({ error: 'Failed to add document' });
    }
});

// Get document by ID
router.get('/:documentId', authenticate, async (req, res) => {
    try {
        const { documentId } = req.params;
        const document = await Document.getById(documentId);

        if (!document) {
            return res.status(404).json({ error: 'Document not found' });
        }

        res.json({ document });
    } catch (error) {
        console.error('Error fetching document:', error);
        res.status(500).json({ error: 'Failed to fetch document' });
    }
});

// List all documents
router.get('/', authenticate, async (req, res) => {
    try {
        const { limit = 100, offset = 0 } = req.query;

        const documents = await Document.getAllDocuments(
            parseInt(limit),
            parseInt(offset)
        );

        res.json({ documents });
    } catch (error) {
        console.error('Error fetching documents:', error);
        res.status(500).json({ error: 'Failed to fetch documents' });
    }
});

// Update document
router.put('/:documentId', authenticate, isAdmin, async (req, res) => {
    try {
        const { documentId } = req.params;
        const { title, content, sourceUrl, author, category, isActive } = req.body;

        const success = await Document.update(documentId, {
            title,
            content,
            source_url: sourceUrl,
            author,
            category,
            is_active: isActive
        });

        if (!success) {
            return res.status(404).json({ error: 'Document not found or not updated' });
        }

        res.json({ message: 'Document updated successfully' });
    } catch (error) {
        console.error('Error updating document:', error);
        res.status(500).json({ error: 'Failed to update document' });
    }
});

// Delete document
router.delete('/:documentId', authenticate, isAdmin, async (req, res) => {
    try {
        const { documentId } = req.params;

        const success = await Document.delete(documentId);

        if (!success) {
            return res.status(404).json({ error: 'Document not found or not deleted' });
        }

        res.json({ message: 'Document deleted successfully' });
    } catch (error) {
        console.error('Error deleting document:', error);
        res.status(500).json({ error: 'Failed to delete document' });
    }
});

module.exports = router;