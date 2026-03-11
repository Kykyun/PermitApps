const express = require('express');
const { pool } = require('../config/database');
const { authenticate, requireRole } = require('../middleware/auth');

const router = express.Router();

// GET /api/users
router.get('/', authenticate, requireRole('admin'), async (req, res) => {
    try {
        const { rows } = await pool.query('SELECT id, name, email, role, department, phone FROM users ORDER BY created_at DESC');
        res.json({ users: rows });
    } catch (err) {
        console.error('List users error:', err);
        res.status(500).json({ error: 'Server error' });
    }
});

// PUT /api/users/:id/role
router.put('/:id/role', authenticate, requireRole('admin'), async (req, res) => {
    try {
        const { role } = req.body;
        const validRoles = ['worker', 'supervisor', 'k3_officer', 'k3_umum', 'mill_assistant', 'mill_manager', 'admin'];
        
        if (!validRoles.includes(role)) {
            return res.status(400).json({ error: 'Invalid role' });
        }

        const { rows } = await pool.query(
            'UPDATE users SET role = $1, updated_at = NOW() WHERE id = $2 RETURNING id, name, email, role',
            [role, req.params.id]
        );

        if (rows.length === 0) return res.status(404).json({ error: 'User not found' });
        
        res.json({ user: rows[0], message: 'Role updated successfully' });
    } catch (err) {
        console.error('Update user role error:', err);
        res.status(500).json({ error: 'Server error' });
    }
});

module.exports = router;
