require('dotenv').config();
'use strict';

const http     = require('http');
const mysql    = require('mysql2/promise');

// ── Config from environment (injected by userdata) ────────────
const PORT    = process.env.PORT     || 8080;
const DB_HOST = process.env.DB_HOST;
const DB_PORT = parseInt(process.env.DB_PORT || '3306', 10);
const DB_NAME = process.env.DB_NAME;
const DB_USER = process.env.DB_USER;
const DB_PASS = process.env.DB_PASSWORD;

// ── MySQL connection pool ─────────────────────────────────────
let pool;

async function getPool() {
  if (!pool) {
    pool = mysql.createPool({
      host            : DB_HOST,
      port            : DB_PORT,
      database        : DB_NAME,
      user            : DB_USER,
      password        : DB_PASS,
      waitForConnections: true,
      connectionLimit : 10,
      queueLimit      : 0,
      connectTimeout  : 10000,
    });
    // Seed on first connection if table is empty
    await seedIfEmpty(pool);
  }
  return pool;
}

// ── Seed initial data ─────────────────────────────────────────
async function seedIfEmpty(pool) {
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS members (
      id         INT AUTO_INCREMENT PRIMARY KEY,
      name       VARCHAR(100) NOT NULL,
      role       VARCHAR(100) NOT NULL,
      department VARCHAR(100) NOT NULL,
      location   VARCHAR(100) NOT NULL,
      joined_at  DATE NOT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  `);

  const [rows] = await pool.execute('SELECT COUNT(*) AS cnt FROM members');
  if (rows[0].cnt > 0) return;

  const seed = [
    ['Alice Nguyen',   'Lead Engineer',      'Engineering', 'Singapore',   '2021-03-15'],
    ['Bob Rahman',     'Product Manager',    'Product',     'Kuala Lumpur','2020-07-01'],
    ['Clara Osei',     'UX Designer',        'Design',      'Accra',       '2022-01-10'],
    ['David Kim',      'Backend Developer',  'Engineering', 'Seoul',       '2021-11-22'],
    ['Eva Santos',     'Data Analyst',       'Analytics',   'Sao Paulo',   '2023-02-28'],
    ['Frank Müller',   'DevOps Engineer',    'Platform',    'Berlin',      '2020-09-05'],
    ['Grace Okonkwo',  'Frontend Developer', 'Engineering', 'Lagos',       '2022-06-17'],
    ['Hassan Ali',     'QA Engineer',        'Quality',     'Cairo',       '2021-08-30'],
  ];

  for (const [name, role, department, location, joined_at] of seed) {
    await pool.execute(
      'INSERT INTO members (name, role, department, location, joined_at) VALUES (?, ?, ?, ?, ?)',
      [name, role, department, location, joined_at]
    );
  }
  console.log('[seed] Inserted 8 seed members');
}

// ── NEW: Helper to parse POST body from stream ───────────────
async function getBody(req) {
  return new Promise((resolve, reject) => {
    try {
      let body = '';
      req.on('data', chunk => { body += chunk.toString(); });
      req.on('end', () => { resolve(JSON.parse(body)); });
    } catch (err) { reject(err); }
  });
}

// ── Request router ────────────────────────────────────────────
async function handler(req, res) {
  // CORS headers (allowing POST and OPTIONS)
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Content-Type', 'application/json');

  const url = req.url.split('?')[0];

  // Handle Preflight (OPTIONS)
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    return res.end();
  }

  // ── GET /api/health ──────────────────────────────────────
  if (url === '/api/health' && req.method === 'GET') {
    res.writeHead(200);
    return res.end(JSON.stringify({ status: 'ok', timestamp: new Date().toISOString() }));
  }

  // ── GET /api/members ─────────────────────────────────────
  if (url === '/api/members' && req.method === 'GET') {
    try {
      const p     = await getPool();
      const t0    = Date.now();
      const [rows] = await p.execute('SELECT * FROM members ORDER BY joined_at DESC');
      const ms    = Date.now() - t0;

      res.writeHead(200);
      return res.end(JSON.stringify({
        source   : `mysql://${DB_HOST}/${DB_NAME}`,
        query_ms : ms,
        members  : rows,
      }));
    } catch (err) {
      console.error('[/api/members] DB error:', err.message);
      res.writeHead(500);
      return res.end(JSON.stringify({ error: 'Database error', detail: err.message }));
    }
  }

  // ── NEW: POST /api/members (Add Member) ───────────────────
  if (url === '/api/members' && req.method === 'POST') {
    try {
      const body = await getBody(req);

      // Basic validation
      if (!body.name || !body.role || !body.department || !body.location || !body.joined_at) {
        res.writeHead(400);
        return res.end(JSON.stringify({ error: 'Missing required fields' }));
      }

      const p = await getPool();
      await p.execute(
        'INSERT INTO members (name, role, department, location, joined_at) VALUES (?, ?, ?, ?, ?)',
        [body.name, body.role, body.department, body.location, body.joined_at]
      );

      res.writeHead(201); // 201 Created
      return res.end(JSON.stringify({ message: 'Member added successfully', member: body }));

    } catch (err) {
      console.error('[POST /api/members] Error:', err.message);
      res.writeHead(500);
      return res.end(JSON.stringify({ error: 'Server error', detail: err.message }));
    }
  }

  // ── 404 ──────────────────────────────────────────────────
  res.writeHead(404);
  res.end(JSON.stringify({ error: 'Not found' }));
}

// ── Start server ──────────────────────────────────────────────
const server = http.createServer(handler);

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[server] Listening on port ${PORT}`);
  console.log(`[server] DB => ${DB_HOST}:${DB_PORT}/${DB_NAME}`);
  // Eagerly connect and seed
  getPool().catch(err => console.error('[server] Pool init error:', err.message));
});

// Graceful shutdown
process.on('SIGTERM', () => {
  server.close(() => process.exit(0));
});