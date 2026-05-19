#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/userdata-frontend.log | logger -t userdata -s 2>/dev/console) 2>&1

echo "===== [nt-frontend] Initialization Start ====="

# ── System packages ───────────────────────────────────────────
apt-get update -y
apt-get install -y nginx curl

# ── Write the frontend HTML app ───────────────────────────────
mkdir -p /var/www/html/app

cat > /var/www/html/app/index.html << 'HTMLAPP'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>Team Directory</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: 'Segoe UI', system-ui, sans-serif; background: #0f172a; color: #e2e8f0; min-height: 100vh; padding: 2rem; }
    header { text-align: center; margin-bottom: 3rem; }
    header h1 { font-size: 2.5rem; font-weight: 700; background: linear-gradient(135deg, #38bdf8, #818cf8); -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text; }
    header p { color: #64748b; margin-top: 0.5rem; }
    #status { text-align: center; padding: 1rem; border-radius: 8px; margin-bottom: 1.5rem; font-size: 0.9rem; display: none; }
    #status.error   { background: #450a0a; color: #fca5a5; display: block; }
    #status.loading { background: #172554; color: #93c5fd; display: block; }
    #grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 1.25rem; max-width: 1100px; margin: 0 auto; }
    .card { background: #1e293b; border: 1px solid #334155; border-radius: 12px; padding: 1.5rem; transition: transform 0.2s, border-color 0.2s; }
    .card:hover { transform: translateY(-4px); border-color: #38bdf8; }
    .avatar { width: 52px; height: 52px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 1.4rem; font-weight: 700; margin-bottom: 1rem; background: linear-gradient(135deg, #0ea5e9, #6366f1); color: #fff; }
    .card h2 { font-size: 1.1rem; font-weight: 600; color: #f1f5f9; }
    .role { font-size: 0.82rem; color: #38bdf8; margin: 0.25rem 0 0.75rem; text-transform: uppercase; letter-spacing: 0.05em; }
    .dept { font-size: 0.85rem; color: #94a3b8; }
    .joined { font-size: 0.78rem; color: #475569; margin-top: 0.5rem; }
    .tag { display: inline-block; background: #0f172a; border: 1px solid #334155; color: #94a3b8; font-size: 0.75rem; padding: 0.2rem 0.6rem; border-radius: 999px; margin-top: 0.75rem; }
    #meta { text-align: center; color: #334155; font-size: 0.78rem; margin-top: 2.5rem; }
  </style>
</head>
<body>
<header>
  <h1>Team Directory</h1>
  <p>Live data pulled from RDS MySQL via Node.js API</p>
</header>
<div id="status" class="loading">Fetching data...</div>
<div id="grid"></div>
<div id="meta"></div>
<script>
  async function load() {
    const status = document.getElementById('status');
    const grid   = document.getElementById('grid');
    const meta   = document.getElementById('meta');
    status.className = 'loading'; status.textContent = 'Fetching team data from API...'; status.style.display = 'block';
    try {
      const res  = await fetch('/api/members');
      if (!res.ok) throw new Error('HTTP ' + res.status);
      const data = await res.json();
      status.style.display = 'none';
      data.members.forEach(m => {
        const initials = m.name.split(' ').map(w=>w[0]).join('').slice(0,2).toUpperCase();
        grid.innerHTML += '<div class="card"><div class="avatar">'+initials+'</div><h2>'+m.name+'</h2><div class="role">'+m.role+'</div><div class="dept">'+m.department+'</div><div class="joined">Joined '+new Date(m.joined_at).toLocaleDateString('en-US',{year:'numeric',month:'short'})+'</div><span class="tag">'+m.location+'</span></div>';
      });
      meta.textContent = data.members.length+' members loaded from '+data.source+' in '+data.query_ms+'ms';
    } catch(e) {
      status.className = 'error'; status.textContent = 'Error: '+e.message;
    }
  }
  load();
</script>
</body>
</html>
HTMLAPP

# ── Nginx config: serve app + proxy /api to backend ──────────
cat > /etc/nginx/sites-available/nt-app << NGINXCONF
server {
    listen 80;
    server_name _;

    root /var/www/html/app;
    index index.html;

    # Serve frontend SPA
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Proxy all /api/* calls to backend Node.js
    location /api/ {
        proxy_pass         http://${backend_private_ip}:8080;
        proxy_http_version 1.1;
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 30s;
        proxy_read_timeout    30s;
    }

    access_log /var/log/nginx/nt-app-access.log;
    error_log  /var/log/nginx/nt-app-error.log;
}
NGINXCONF

ln -sf /etc/nginx/sites-available/nt-app /etc/nginx/sites-enabled/nt-app
rm -f /etc/nginx/sites-enabled/default

nginx -t   # Validate config before restarting

systemctl enable nginx
systemctl restart nginx

hostnamectl set-hostname ${project_name}-frontend
echo "===== [nt-frontend] Init Complete ====="
echo "Backend proxied at: http://${backend_private_ip}:8080"
