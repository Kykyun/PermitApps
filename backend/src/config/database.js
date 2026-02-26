const { Pool } = require('pg');

const pool = new Pool({
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT) || 5432,
    user: process.env.DB_USER || 'permitapp',
    password: process.env.DB_PASSWORD || 'permit2026secure',
    database: process.env.DB_NAME || 'workpermit',
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 5000,
});

pool.on('error', (err) => {
    console.error('Unexpected DB pool error:', err);
});

module.exports = { pool };
