const { pool } = require('./src/config/database');
const { initDatabase } = require('./src/config/init-db');

const reset = async () => {
    try {
        console.log('Dropping tables...');
        await pool.query(`
            DROP TABLE IF EXISTS notifications CASCADE;
            DROP TABLE IF EXISTS approval_history CASCADE;
            DROP TABLE IF EXISTS permit_documents CASCADE;
            DROP TABLE IF EXISTS permits CASCADE;
            DROP TABLE IF EXISTS users CASCADE;
        `);
        console.log('Tables dropped.');
        await initDatabase();
        process.exit(0);
    } catch (err) {
        console.error('Error resetting DB:', err);
        process.exit(1);
    }
};

reset();
