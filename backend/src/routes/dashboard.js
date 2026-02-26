const express = require('express');
const { pool } = require('../config/database');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

// GET /api/dashboard/stats
router.get('/stats', authenticate, async (req, res) => {
    try {
        let whereClause = '';
        const params = [];

        if (req.user.role === 'worker') {
            whereClause = 'WHERE applicant_id = $1';
            params.push(req.user.id);
        }

        const { rows } = await pool.query(`
      SELECT
        COUNT(*) FILTER (WHERE status IN ('approved', 'active')) as active,
        COUNT(*) FILTER (WHERE status IN ('submitted', 'supervisor_review', 'supervisor_approved', 'k3_review')) as pending,
        COUNT(*) FILTER (WHERE status = 'rejected') as rejected,
        COUNT(*) FILTER (WHERE status = 'draft') as draft,
        COUNT(*) FILTER (WHERE status = 'closed') as closed,
        COUNT(*) FILTER (WHERE status = 'expired') as expired,
        COUNT(*) as total
      FROM permits ${whereClause}
    `, params);

        res.json({ stats: rows[0] });
    } catch (err) {
        console.error('Dashboard stats error:', err);
        res.status(500).json({ error: 'Server error' });
    }
});

// GET /api/dashboard/trend — monthly permit trend
router.get('/trend', authenticate, async (req, res) => {
    try {
        let whereClause = '';
        const params = [];

        if (req.user.role === 'worker') {
            whereClause = 'AND applicant_id = $1';
            params.push(req.user.id);
        }

        const { rows } = await pool.query(`
      SELECT
        TO_CHAR(created_at, 'YYYY-MM') as month,
        COUNT(*) as count
      FROM permits
      WHERE created_at >= NOW() - INTERVAL '12 months' ${whereClause}
      GROUP BY TO_CHAR(created_at, 'YYYY-MM')
      ORDER BY month ASC
    `, params);

        res.json({ trend: rows });
    } catch (err) {
        console.error('Dashboard trend error:', err);
        res.status(500).json({ error: 'Server error' });
    }
});

// GET /api/dashboard/recent — recent permits
router.get('/recent', authenticate, async (req, res) => {
    try {
        let whereClause = '';
        const params = [];

        if (req.user.role === 'worker') {
            whereClause = 'WHERE p.applicant_id = $1';
            params.push(req.user.id);
        }

        const { rows } = await pool.query(`
      SELECT p.*, u.name as applicant_name
      FROM permits p JOIN users u ON p.applicant_id = u.id
      ${whereClause}
      ORDER BY p.created_at DESC LIMIT 10
    `, params);

        res.json({ permits: rows });
    } catch (err) {
        console.error('Dashboard recent error:', err);
        res.status(500).json({ error: 'Server error' });
    }
});

module.exports = router;
