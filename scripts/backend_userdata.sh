#!/bin/bash

exec > >(tee /var/log/userdata-backend.log | logger -t userdata -s 2>/dev/console) 2>&1

echo "===== [nt-backend] Initialization Start ====="


echo "[Network] Waiting for connectivity to package repositories..."
for i in {1..40}; do
  if apt-get update -qq > /dev/null 2>&1; then
    echo "[Network] Connection established."
    break
  fi
  echo "[Network] Not ready yet... waiting 10s (Attempt $i/20)"
  sleep 10
done

# ── System packages ───────────────────────────────────────────
apt-get update -y
apt-get install -y git curl build-essential mysql-client

# ── Node.js 18 via NVM ────────────────────────────────────────
mkdir -p /root/.nvm
export NVM_DIR="/root/.nvm"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  echo "ERROR: NVM installation failed. Script exiting."
  exit 1
fi
echo "[Step 2/5] Loading NVM..."
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
# [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
# source ~/.bashrc

# ── CRITICAL FIX: Export PATH for PM2 and NPM ─────────────────

nvm install 18 && nvm use 18 && nvm alias default 18
export PATH=$NVM_DIR/versions/node/$(nvm current)/bin:$PATH

# ── PM2 process manager ───────────────────────────────────────
npm install -g pm2
npm install dotenv

# ── App directories ───────────────────────────────────────────
mkdir -p /var/app/backend
mkdir -p /var/log/app
chown -R root:root /var/app/backend /var/log/app

# ── Write package.json (Includes dotenv) ──────────────────────
cat > /var/app/backend/package.json << 'PKGJSON'
{
  "name": "nt-backend",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": { "start": "node server.js" },
  "dependencies": { 
    "mysql2": "^3.9.7",
    "dotenv": "^16.4.5" 
  }
}
PKGJSON

# ── Write .env ────────────────────────────────────────────────
cat > /var/app/backend/.env << ENVFILE
NODE_ENV=production
PORT=8080
DB_HOST=${db_endpoint}
DB_PORT=${db_port}
DB_NAME=${db_name}
DB_USER=${db_username}
DB_PASSWORD=${db_password}
ENVFILE
chmod 600 /var/app/backend/.env

# ── Write server.js (Includes dotenv config) ───────────────────
cat > /var/app/backend/server.js << 'SERVERJS'
require('dotenv').config();
'use strict';

const http  = require('http');
const mysql = require('mysql2/promise');

const PORT    = process.env.PORT     || 8080;
const DB_HOST = process.env.DB_HOST;
const DB_PORT = parseInt(process.env.DB_PORT || '3306', 10);
const DB_NAME = process.env.DB_NAME;
const DB_USER = process.env.DB_USER;
const DB_PASS = process.env.DB_PASSWORD;

let pool;

async function getPool() {
  if (!pool) {
    pool = mysql.createPool({
      host: DB_HOST, port: DB_PORT, database: DB_NAME,
      user: DB_USER, password: DB_PASS,
      waitForConnections: true, connectionLimit: 10,
    });
    await seedIfEmpty(pool);
  }
  return pool;
}

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
    ['Alice Nguyen',  'Lead Engineer',      'Engineering', 'Singapore',    '2021-03-15'],
    ['Bob Rahman',    'Product Manager',    'Product',     'Kuala Lumpur', '2020-07-01'],
    ['Clara Osei',    'UX Designer',        'Design',      'Accra',        '2022-01-10'],
    ['David Kim',     'Backend Developer',  'Engineering', 'Seoul',        '2021-11-22'],
    ['Eva Santos',    'Data Analyst',       'Analytics',   'Sao Paulo',    '2023-02-28'],
    ['Frank Muller',  'DevOps Engineer',    'Platform',    'Berlin',       '2020-09-05'],
    ['Grace Okonkwo', 'Frontend Developer', 'Engineering', 'Lagos',        '2022-06-17'],
    ['Hassan Ali',    'QA Engineer',        'Quality',     'Cairo',        '2021-08-30'],
  ];
  for (const [name, role, department, location, joined_at] of seed) {
    await pool.execute(
      'INSERT INTO members (name, role, department, location, joined_at) VALUES (?,?,?,?,?)',
      [name, role, department, location, joined_at]
    );
  }
  console.log('[seed] 8 members inserted');
}

const server = http.createServer(async (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Access-Control-Allow-Origin', '*');
  const url = req.url.split('?')[0];

  if (url === '/api/health') {
    res.writeHead(200);
    return res.end(JSON.stringify({ status: 'ok', ts: new Date().toISOString() }));
  }

  if (url === '/api/members') {
    try {
      const p = await getPool();
      const t0 = Date.now();
      const [rows] = await p.execute('SELECT * FROM members ORDER BY joined_at DESC');
      res.writeHead(200);
      return res.end(JSON.stringify({
        source: `mysql://$${DB_HOST}/$${DB_NAME}`,
        query_ms: Date.now() - t0,
        members: rows,
      }));
    } catch (e) {
      res.writeHead(500);
      return res.end(JSON.stringify({ error: e.message }));
    }
  }

  res.writeHead(404);
  res.end(JSON.stringify({ error: 'Not found' }));
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[server] :$${PORT} | db=$${DB_HOST}/$${DB_NAME}`);
  getPool().catch(e => console.error('[pool init]', e.message));
});

process.on('SIGTERM', () => server.close(() => process.exit(0)));
SERVERJS

# ── Install dependencies & start ─────────────────────────────
cd /var/app/backend
rm -rf node_modules package-lock.json
npm cache clean --force

echo "[Final] Installing NPM dependencies..."
npm install --legacy-peer-deps --no-audit --no-fund || true


pm2 start server.js --name nt-api
pm2 save

# ── PM2 auto-start on reboot ──────────────────────────────────
# env PATH=$PATH:/root/.nvm/versions/node/$(nvm current)/bin
pm2 startup systemd -u root --hp /root

hostnamectl set-hostname ${project_name}-backend
echo "===== [nt-backend] Init Complete ====="