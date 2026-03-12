const express = require('express');
const { pool } = require('../config/database');
const { authenticate, requireRole } = require('../middleware/auth');
const { upload } = require('../middleware/upload');

const router = express.Router();

// Helper: generate permit number
const generatePermitNumber = async () => {
    const year = new Date().getFullYear();
    const { rows } = await pool.query(
        "SELECT COUNT(*) FROM permits WHERE permit_number LIKE $1",
        [`WP-${year}-%`]
    );
    const num = parseInt(rows[0].count) + 1;
    return `WP-${year}-${String(num).padStart(4, '0')}`;
};

// Helper: create notification
const createNotification = async (userId, permitId, title, message) => {
    await pool.query(
        'INSERT INTO notifications (user_id, permit_id, title, message) VALUES ($1, $2, $3, $4)',
        [userId, permitId, title, message]
    );
};

// Helper: notify users by role
const notifyByRole = async (role, permitId, title, message) => {
    const { rows } = await pool.query('SELECT id FROM users WHERE role = $1', [role]);
    for (const user of rows) {
        await createNotification(user.id, permitId, title, message);
    }
};

// GET /api/permits — list permits (role-filtered)
router.get('/', authenticate, async (req, res) => {
    try {
        const { status, type, search, page = 1, limit = 20 } = req.query;
        const offset = (page - 1) * limit;
        let query = `
      SELECT p.*, u.name as applicant_name, u.department as applicant_department
      FROM permits p
      JOIN users u ON p.applicant_id = u.id
      WHERE 1=1
    `;
        const params = [];
        let paramIdx = 1;

        // Role-based filtering
        if (req.user.role === 'supervisor') {
            query += ` AND p.applicant_id = $${paramIdx++}`;
            params.push(req.user.id);
        }

        if (status) {
            query += ` AND p.status = $${paramIdx++}`;
            params.push(status);
        }
        if (type) {
            query += ` AND p.permit_type = $${paramIdx++}`;
            params.push(type);
        }
        if (search) {
            query += ` AND (p.permit_number ILIKE $${paramIdx} OR p.work_description ILIKE $${paramIdx} OR p.work_location ILIKE $${paramIdx})`;
            params.push(`%${search}%`);
            paramIdx++;
        }

        // Count query
        const countQuery = query.replace(/SELECT .* FROM/, 'SELECT COUNT(*) FROM');
        const { rows: countRows } = await pool.query(countQuery, params);
        const total = parseInt(countRows[0].count);

        query += ` ORDER BY p.created_at DESC LIMIT $${paramIdx++} OFFSET $${paramIdx++}`;
        params.push(parseInt(limit), parseInt(offset));

        const { rows } = await pool.query(query, params);

        res.json({
            permits: rows,
            pagination: {
                total,
                page: parseInt(page),
                limit: parseInt(limit),
                pages: Math.ceil(total / limit),
            },
        });
    } catch (err) {
        console.error('List permits error:', err);
        res.status(500).json({ error: 'Server error' });
    }
});

// GET /api/permits/:id — get permit detail
router.get('/:id', authenticate, async (req, res) => {
    try {
        const { rows: permits } = await pool.query(
            `SELECT p.*, u.name as applicant_name, u.email as applicant_email, u.department as applicant_department, u.phone as applicant_phone
       FROM permits p JOIN users u ON p.applicant_id = u.id WHERE p.id = $1`,
            [req.params.id]
        );

        if (permits.length === 0) {
            return res.status(404).json({ error: 'Permit not found' });
        }

        const permit = permits[0];

        // Get documents
        const { rows: documents } = await pool.query(
            'SELECT * FROM permit_documents WHERE permit_id = $1 ORDER BY uploaded_at DESC',
            [permit.id]
        );

        // Get approval history
        const { rows: history } = await pool.query(
            `SELECT ah.*, u.name as reviewer_name FROM approval_history ah
       LEFT JOIN users u ON ah.reviewer_id = u.id
       WHERE ah.permit_id = $1 ORDER BY ah.action_date ASC`,
            [permit.id]
        );

        res.json({ permit, documents, history });
    } catch (err) {
        console.error('Get permit error:', err);
        res.status(500).json({ error: 'Server error' });
    }
});

// POST /api/permits — create new permit
router.post('/', authenticate, async (req, res) => {
    try {
        if (req.user.role !== 'supervisor' && req.user.role !== 'admin') {
            return res.status(403).json({ error: 'Only supervisor can create permits' });
        }
        const { permit_type, work_description, work_location, start_date, end_date, hazard_identification, control_measures, ppe_required } = req.body;

        if (!permit_type || !work_description || !work_location || !start_date || !end_date) {
            return res.status(400).json({ error: 'Missing required fields' });
        }

        const permit_number = await generatePermitNumber();

        const { rows } = await pool.query(
            `INSERT INTO permits (permit_number, applicant_id, permit_type, status, work_description, work_location, start_date, end_date, hazard_identification, control_measures, ppe_required)
       VALUES ($1, $2, $3, 'draft', $4, $5, $6, $7, $8, $9, $10)
       RETURNING *`,
            [permit_number, req.user.id, permit_type, work_description, work_location, start_date, end_date, hazard_identification || null, control_measures || null, ppe_required || null]
        );

        res.status(201).json({ permit: rows[0] });
    } catch (err) {
        console.error('Create permit error:', err);
        res.status(500).json({ error: 'Server error' });
    }
});

// PUT /api/permits/:id — update draft permit
router.put('/:id', authenticate, async (req, res) => {
    try {
        const { rows: existing } = await pool.query('SELECT * FROM permits WHERE id = $1', [req.params.id]);
        if (existing.length === 0) return res.status(404).json({ error: 'Not found' });
        if (existing[0].applicant_id !== req.user.id) return res.status(403).json({ error: 'Not your permit' });
        if (existing[0].status !== 'draft' && existing[0].status !== 'rejected') {
            return res.status(400).json({ error: 'Can only edit draft or rejected permits' });
        }

        const { permit_type, work_description, work_location, start_date, end_date, hazard_identification, control_measures, ppe_required } = req.body;

        const { rows } = await pool.query(
            `UPDATE permits SET permit_type = COALESCE($1, permit_type), work_description = COALESCE($2, work_description),
       work_location = COALESCE($3, work_location), start_date = COALESCE($4, start_date), end_date = COALESCE($5, end_date),
       hazard_identification = COALESCE($6, hazard_identification), control_measures = COALESCE($7, control_measures),
       ppe_required = COALESCE($8, ppe_required), updated_at = NOW() WHERE id = $9 RETURNING *`,
            [permit_type, work_description, work_location, start_date, end_date, hazard_identification, control_measures, ppe_required, req.params.id]
        );

        res.json({ permit: rows[0] });
    } catch (err) {
        console.error('Update permit error:', err);
        res.status(500).json({ error: 'Server error' });
    }
});

// POST /api/permits/:id/submit — submit for review
router.post('/:id/submit', authenticate, async (req, res) => {
    try {
        if (req.user.role !== 'supervisor' && req.user.role !== 'admin') {
            return res.status(403).json({ error: 'Only supervisor can submit permits' });
        }

        const { rows: existing } = await pool.query('SELECT * FROM permits WHERE id = $1', [req.params.id]);
        if (existing.length === 0) return res.status(404).json({ error: 'Not found' });
        if (existing[0].applicant_id !== req.user.id && req.user.role !== 'admin') return res.status(403).json({ error: 'Not your permit' });
        if (existing[0].status !== 'draft' && existing[0].status !== 'rejected') {
            return res.status(400).json({ error: 'Can only submit draft or rejected permits' });
        }

        const { rows } = await pool.query(
            "UPDATE permits SET status = 'submitted', updated_at = NOW() WHERE id = $1 RETURNING *",
            [req.params.id]
        );

        // Record history
        await pool.query(
            "INSERT INTO approval_history (permit_id, reviewer_id, action, comments, reviewer_role) VALUES ($1, $2, 'submitted', 'Permit submitted for review', $3)",
            [req.params.id, req.user.id, req.user.role]
        );

        // Notify K3 officers
        await notifyByRole('k3_officer', req.params.id, 'New Permit Submission',
            `Supervisor ${req.user.name} submitted permit ${existing[0].permit_number} for review`);

        res.json({ permit: rows[0] });
    } catch (err) {
        console.error('Submit permit error:', err);
        res.status(500).json({ error: 'Server error' });
    }
});

// POST /api/permits/:id/approve — approve permit
router.post('/:id/approve', authenticate, requireRole('k3_officer', 'k3_umum', 'mill_assistant', 'mill_manager', 'admin'), async (req, res) => {
    try {
        const { comments } = req.body;
        const { rows: existing } = await pool.query('SELECT * FROM permits WHERE id = $1', [req.params.id]);
        if (existing.length === 0) return res.status(404).json({ error: 'Not found' });

        const permit = existing[0];
        let newStatus;

        if (req.user.role === 'k3_officer' && permit.status === 'submitted') {
            newStatus = 'k3_filled';
            // Ahli K3 has filled the form, notify Ahli K3 Umum
            await notifyByRole('k3_umum', permit.id, 'Permit Needs Review',
                `Ahli K3 completed form for permit ${permit.permit_number}. Needs your review.`);
        } else if (req.user.role === 'k3_umum' && permit.status === 'k3_filled') {
            newStatus = 'k3_umum_approved';
            // Notify Mill Assistant
            await notifyByRole('mill_assistant', permit.id, 'Permit Needs Review',
                `Ahli K3 Umum approved permit ${permit.permit_number}. Needs your review.`);
        } else if (req.user.role === 'mill_assistant' && permit.status === 'k3_umum_approved') {
            newStatus = 'mill_assistant_approved';
            // Notify Mill Manager
            await notifyByRole('mill_manager', permit.id, 'Permit Needs Final Approval',
                `Mill Assistant approved permit ${permit.permit_number}. Ready for final approval.`);
        } else if (req.user.role === 'mill_manager' && permit.status === 'mill_assistant_approved') {
            newStatus = 'approved';
            // Notify Applicant
            await createNotification(permit.applicant_id, permit.id, 'Permit Fully Approved ✅',
                `Your permit ${permit.permit_number} has been entirely approved!`);
        } else if (req.user.role === 'admin') {
            // Admin can advance any status directly to next step or straight to approved. Let's just say admin approves it linearly or fully.
            // For simplicity, admin force-approves
            newStatus = 'approved';
            await createNotification(permit.applicant_id, permit.id, 'Permit Force Approved ✅',
                `Your permit ${permit.permit_number} has been forcefully approved by admin!`);
        } else {
            return res.status(400).json({ error: 'Cannot approve permit in current status with your role' });
        }

        const { rows } = await pool.query(
            'UPDATE permits SET status = $1, updated_at = NOW() WHERE id = $2 RETURNING *',
            [newStatus, req.params.id]
        );

        await pool.query(
            "INSERT INTO approval_history (permit_id, reviewer_id, action, comments, reviewer_role) VALUES ($1, $2, 'approved', $3, $4)",
            [req.params.id, req.user.id, comments || 'Approved', req.user.role]
        );

        res.json({ permit: rows[0] });
    } catch (err) {
        console.error('Approve permit error:', err);
        res.status(500).json({ error: 'Server error' });
    }
});

// POST /api/permits/:id/reject — reject permit
router.post('/:id/reject', authenticate, requireRole('k3_officer', 'k3_umum', 'mill_assistant', 'mill_manager', 'admin'), async (req, res) => {
    try {
        const { comments } = req.body;
        if (!comments) return res.status(400).json({ error: 'Rejection reason is required' });

        const { rows: existing } = await pool.query('SELECT * FROM permits WHERE id = $1', [req.params.id]);
        if (existing.length === 0) return res.status(404).json({ error: 'Not found' });

        const { rows } = await pool.query(
            "UPDATE permits SET status = 'rejected', rejection_reason = $1, updated_at = NOW() WHERE id = $2 RETURNING *",
            [comments, req.params.id]
        );

        await pool.query(
            "INSERT INTO approval_history (permit_id, reviewer_id, action, comments, reviewer_role) VALUES ($1, $2, 'rejected', $3, $4)",
            [req.params.id, req.user.id, comments, req.user.role]
        );

        // Notify applicant
        await createNotification(existing[0].applicant_id, req.params.id, 'Permit Rejected ❌',
            `Your permit ${existing[0].permit_number} was rejected: ${comments}`);

        res.json({ permit: rows[0] });
    } catch (err) {
        console.error('Reject permit error:', err);
        res.status(500).json({ error: 'Server error' });
    }
});

// POST /api/permits/:id/documents — upload documents
router.post('/:id/documents', authenticate, upload.array('documents', 5), async (req, res) => {
    try {
        const { rows: existing } = await pool.query('SELECT * FROM permits WHERE id = $1', [req.params.id]);
        if (existing.length === 0) return res.status(404).json({ error: 'Not found' });

        const docs = [];
        for (const file of req.files) {
            const { rows } = await pool.query(
                'INSERT INTO permit_documents (permit_id, document_name, file_path, file_type, file_size) VALUES ($1, $2, $3, $4, $5) RETURNING *',
                [req.params.id, file.originalname, `/uploads/${file.filename}`, file.mimetype, file.size]
            );
            docs.push(rows[0]);
        }

        res.status(201).json({ documents: docs });
    } catch (err) {
        console.error('Upload documents error:', err);
        res.status(500).json({ error: 'Server error' });
    }
});

module.exports = router;
