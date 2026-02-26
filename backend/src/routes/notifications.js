const express = require('express');
const { pool } = require('../config/database');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

// GET /api/notifications — user's notifications
router.get('/', authenticate, async (req, res) => {
    try {
        const { rows } = await pool.query(
            `SELECT n.*, p.permit_number FROM notifications n
       LEFT JOIN permits p ON n.permit_id = p.id
       WHERE n.user_id = $1 ORDER BY n.created_at DESC LIMIT 50`,
            [req.user.id]
        );

        const { rows: countRows } = await pool.query(
            'SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND is_read = false',
            [req.user.id]
        );

        res.json({
            notifications: rows,
            unread_count: parseInt(countRows[0].count),
        });
    } catch (err) {
        console.error('Get notifications error:', err);
        res.status(500).json({ error: 'Server error' });
    }
});

// PUT /api/notifications/:id/read — mark single as read
router.put('/:id/read', authenticate, async (req, res) => {
    try {
        await pool.query(
            'UPDATE notifications SET is_read = true WHERE id = $1 AND user_id = $2',
            [req.params.id, req.user.id]
        );
        res.json({ message: 'Marked as read' });
    } catch (err) {
        res.status(500).json({ error: 'Server error' });
    }
});

// PUT /api/notifications/read-all — mark all as read
router.put('/read-all', authenticate, async (req, res) => {
    try {
        await pool.query(
            'UPDATE notifications SET is_read = true WHERE user_id = $1 AND is_read = false',
            [req.user.id]
        );
        res.json({ message: 'All marked as read' });
    } catch (err) {
        res.status(500).json({ error: 'Server error' });
    }
});

module.exports = router;
