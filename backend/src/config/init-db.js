const { pool } = require('./database');
const bcrypt = require('bcryptjs');

const createTables = async () => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        // Users table
        await client.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(150) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        role VARCHAR(20) NOT NULL DEFAULT 'worker'
          CHECK (role IN ('worker', 'supervisor', 'k3_officer', 'k3_umum', 'mill_assistant', 'mill_manager', 'admin')),
        department VARCHAR(100),
        phone VARCHAR(20),
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      );
    `);

        // Permits table
        await client.query(`
      CREATE TABLE IF NOT EXISTS permits (
        id SERIAL PRIMARY KEY,
        permit_number VARCHAR(20) UNIQUE NOT NULL,
        applicant_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        permit_type VARCHAR(30) NOT NULL
          CHECK (permit_type IN ('confined_space', 'working_at_height', 'excavation', 'electrical', 'hot_work')),
        status VARCHAR(30) NOT NULL DEFAULT 'draft'
          CHECK (status IN ('draft', 'submitted', 'k3_filled', 'k3_umum_approved', 'mill_assistant_approved', 'approved', 'rejected', 'active', 'expired', 'closed')),
        work_description TEXT NOT NULL,
        work_location VARCHAR(255) NOT NULL,
        start_date TIMESTAMP NOT NULL,
        end_date TIMESTAMP NOT NULL,
        hazard_identification TEXT,
        control_measures TEXT,
        ppe_required TEXT,
        rejection_reason TEXT,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      );
    `);

        // Permit documents table
        await client.query(`
      CREATE TABLE IF NOT EXISTS permit_documents (
        id SERIAL PRIMARY KEY,
        permit_id INTEGER REFERENCES permits(id) ON DELETE CASCADE,
        document_name VARCHAR(255) NOT NULL,
        file_path VARCHAR(500) NOT NULL,
        file_type VARCHAR(50),
        file_size INTEGER,
        uploaded_at TIMESTAMP DEFAULT NOW()
      );
    `);

        // Approval history table
        await client.query(`
      CREATE TABLE IF NOT EXISTS approval_history (
        id SERIAL PRIMARY KEY,
        permit_id INTEGER REFERENCES permits(id) ON DELETE CASCADE,
        reviewer_id INTEGER REFERENCES users(id),
        action VARCHAR(20) NOT NULL
          CHECK (action IN ('submitted', 'approved', 'rejected', 'commented')),
        comments TEXT,
        reviewer_role VARCHAR(20),
        action_date TIMESTAMP DEFAULT NOW()
      );
    `);

        // Notifications table
        await client.query(`
      CREATE TABLE IF NOT EXISTS notifications (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        permit_id INTEGER REFERENCES permits(id) ON DELETE CASCADE,
        title VARCHAR(255) NOT NULL,
        message TEXT NOT NULL,
        is_read BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT NOW()
      );
    `);

        await client.query('COMMIT');
        console.log('✅ Database tables created successfully');
    } catch (err) {
        await client.query('ROLLBACK');
        throw err;
    } finally {
        client.release();
    }
};

const seedDemoUsers = async () => {
    const client = await pool.connect();
    try {
        const { rows } = await client.query('SELECT COUNT(*) FROM users');
        if (parseInt(rows[0].count) > 0) {
            console.log('ℹ️  Users already exist, skipping seed');
            return;
        }

        const salt = await bcrypt.genSalt(10);
        const users = [
            { name: 'Admin User', email: 'admin@demo.com', password: 'admin123', role: 'admin', department: 'Management', phone: '0121234567' },
            { name: 'Ahmad Pekerja', email: 'worker@demo.com', password: 'worker123', role: 'worker', department: 'Operations', phone: '0131234567' },
            { name: 'Siti Supervisor', email: 'supervisor@demo.com', password: 'supervisor123', role: 'supervisor', department: 'Operations', phone: '0141234567' },
            { name: 'Dr. Ali K3', email: 'k3@demo.com', password: 'k3123', role: 'k3_officer', department: 'Safety', phone: '0151234567' },
            { name: 'Budi K3 Umum', email: 'k3umum@demo.com', password: 'k3umum123', role: 'k3_umum', department: 'Safety', phone: '0161234567' },
            { name: 'Amin Assistant', email: 'mill_assistant@demo.com', password: 'assistant123', role: 'mill_assistant', department: 'Management', phone: '0171234567' },
            { name: 'John Manager', email: 'mill_manager@demo.com', password: 'manager123', role: 'mill_manager', department: 'Management', phone: '0181234567' },
        ];

        for (const u of users) {
            const hash = await bcrypt.hash(u.password, salt);
            await client.query(
                'INSERT INTO users (name, email, password_hash, role, department, phone) VALUES ($1, $2, $3, $4, $5, $6)',
                [u.name, u.email, hash, u.role, u.department, u.phone]
            );
        }

        console.log('✅ Demo users seeded successfully');
    } finally {
        client.release();
    }
};

const initDatabase = async () => {
    console.log('🔧 Initializing database...');
    await createTables();
    await seedDemoUsers();
    console.log('🚀 Database ready!');
};

module.exports = { initDatabase };
