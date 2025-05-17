const express = require('express');
const router = express.Router();
const Conversation = require('../models/conversation');
const Message = require('../models/message');
const Chunk = require('../models/chunk');
const ApiLog = require('../models/apiLog');
const { v4: uuidv4 } = require('uuid');

// Middleware for verifying JWT token (import from authMiddleware.js)
const authenticate = require('../middleware/authenticate');

// Generate chat completion with RAG
router.post('/', authenticate, async (req, res) => {
    const startTime = Date.now();
    const { conversationId, message } = req.body;
    const userId = req.user.userId;

    try {
        // Create new conversation if needed
        let currentConversationId = conversationId;
        if (!currentConversationId) {
            currentConversationId = await Conversation.create(userId);
        }

        // Log user message
        await Message.create(currentConversationId, message, true, userId);

        // Here you would typically:
        // 1. Generate embedding for the user query using an AI service
        // 2. Find similar chunks in your database
        // 3. Use these chunks + the query to generate a response from an LLM

        // Simulate finding relevant chunks (replace with actual implementation)
        // const relevantChunks = await findRelevantChunks(message);
        const relevantChunks = ["sample-chunk-id-1"];

        // Simulate AI response (replace with actual LLM call)
        const aiResponse = `This is a simulated response to your question: "${message}"`;

        // Save the AI response
        const messageId = await Message.create(
            currentConversationId,
            aiResponse,
            false,
            null,
            relevantChunks
        );

        // Log the API call
        await ApiLog.create(
            'chat_completion',
            { message, conversationId },
            { response: aiResponse, sources: relevantChunks },
            200,
            Date.now() - startTime,
            userId
        );

        res.json({
            conversationId: currentConversationId,
            messageId,
            response: aiResponse,
            sources: relevantChunks
        });
    } catch (error) {
        console.error('Error in chat endpoint:', error);
        res.status(500).json({ error: 'Failed to process chat message' });
    }
});

// Get conversation history
router.get('/conversations/:conversationId', authenticate, async (req, res) => {
    try {
        const { conversationId } = req.params;
        const conversation = await Conversation.getById(conversationId);

        if (!conversation) {
            return res.status(404).json({ error: 'Conversation not found' });
        }

        // Check if user owns this conversation
        if (conversation.user_id !== req.user.userId) {
            return res.status(403).json({ error: 'Access denied' });
        }

        const messages = await Message.getConversationMessages(conversationId);

        res.json({
            conversation,
            messages
        });
    } catch (error) {
        console.error('Error fetching conversation:', error);
        res.status(500).json({ error: 'Failed to fetch conversation' });
    }
});

// Get user conversations list
router.get('/conversations', authenticate, async (req, res) => {
    try {
        const userId = req.user.userId;
        const { limit = 20, offset = 0 } = req.query;

        const conversations = await Conversation.getUserConversations(
            userId,
            parseInt(limit),
            parseInt(offset)
        );

        res.json({ conversations });
    } catch (error) {
        console.error('Error fetching user conversations:', error);
        res.status(500).json({ error: 'Failed to fetch user conversations' });
    }
});

// Submit feedback for a chat response
router.post('/feedback', authenticate, async (req, res) => {
    try {
        const { messageId, rating, comment } = req.body;

        // Verify the message exists and user has access to it
        const message = await Message.getById(messageId);
        if (!message) {
            return res.status(404).json({ error: 'Message not found' });
        }

        const conversation = await Conversation.getById(message.conversation_id);
        if (conversation.user_id !== req.user.userId) {
            return res.status(403).json({ error: 'Access denied' });
        }

        const feedbackId = await Feedback.create(messageId, rating, comment);

        res.json({
            message: 'Feedback submitted successfully',
            feedbackId
        });
    } catch (error) {
        console.error('Error submitting feedback:', error);
        res.status(500).json({ error: 'Failed to submit feedback' });
    }
});

module.exports = router;