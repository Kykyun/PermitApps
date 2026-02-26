const jwt = require('jsonwebtoken');
const { pool } = require('../config/database');

const JWT_SECRET = process.env.JWT_SECRET || 'wp-secret-key-2026';

const authenticate = async (req, res, next) => {
    try {
        const token = req.cookies?.token || req.headers.authorization?.replace('Bearer ', '');
        if (!token) {
            return res.status(401).json({ error: 'Authentication required' });
        }

        const decoded = jwt.verify(token, JWT_SECRET);
        const { rows } = await pool.query('SELECT id, name, email, role, department, phone FROM users WHERE id = $1', [decoded.userId]);

        if (rows.length === 0) {
            return res.status(401).json({ error: 'User not found' });
        }

        req.user = rows[0];
        next();
    } catch (err) {
        return res.status(401).json({ error: 'Invalid token' });
    }
};

const requireRole = (...roles) => {
    return (req, res, next) => {
        if (!req.user) {
            return res.status(401).json({ error: 'Authentication required' });
        }
        if (!roles.includes(req.user.role)) {
            return res.status(403).json({ error: 'Insufficient permissions' });
        }
        next();
    };
};

module.exports = { authenticate, requireRole, JWT_SECRET };
