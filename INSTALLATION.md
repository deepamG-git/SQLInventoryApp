# SQL Inventory Portal - Installation & Deployment Guide

This guide covers:
- Developer workstation setup (frontend + backend)
- SQL Server prerequisites
- Windows Server (IIS) intranet deployment with reverse proxy
- Windows Server backend hosting with PM2 as a Windows Service (Local System)

Repo layout (typical):
- `frontend/` React (Create React App)
- `backend/` Node.js/Express API
- SQL Server database: `SQLInventory`, schema: `inventory`

---

## 1) Prerequisites (Developer Workstation)

### Required software
- Node.js 20 LTS (includes `npm`)
- Git (optional, if pulling from repo)
- VS Code (recommended editor)
- SQL Server access + SSMS (recommended) for DB scripts and validation

### Optional (but helpful)
- Postman / Thunder Client (for API testing)

---

## 2) SQL Server Prerequisites

### Database
- SQL Server instance reachable from backend host
- Database: `SQLInventory`
- Schema: `inventory`
- Tables created (inventory model)

### Required DB change scripts
If you use the `SQLInstallDate` feature, run this on `SQLInventory`:
- `backend/sql/alter_20260312_add_sqlinstalldate.sql`

Example (SSMS):
1. Connect to SQL Server
2. Open the script and execute

---

## 3) Backend (Node API) - Local Development

### Install dependencies
From `backend/`:
```powershell
cd <path>\InventoryApp\backend
npm install
```

### Configure environment variables
Create `backend/.env`:
```text
DB_HOST=...
DB_PORT=...
DB_NAME=SQLInventory
DB_USER=...
DB_PASSWORD=...

JWT_SECRET=<set a long random string>
JWT_EXPIRY=8h

PORT=5000
```

### Run backend
```powershell
node server.js
```

Quick test:
```powershell
curl http://localhost:5000/api/auth/me
```
Expected: `401 Unauthorized` (this proves the API is reachable).

---

## 4) Frontend (React) - Local Development

### Install dependencies
From `frontend/`:
```powershell
cd <path>\InventoryApp\frontend
npm install
```

### Configure API base (optional)
By default:
- Local dev uses `http://localhost:5000`
- IIS / intranet uses same-origin `/api` (reverse proxy)

If you want to override locally, create `frontend/.env`:
```text
REACT_APP_API_BASE_URL=http://localhost:5000
```

### Run frontend
```powershell
npm start
```
Open:
- `http://localhost:3000`

---

## 5) Production/Intranet Deployment (Windows Server 2022 + IIS + Reverse Proxy)

### Summary architecture
- IIS hosts the React static build (port 80)
- IIS reverse proxies `/api/*` to the Node API at `http://localhost:5000`
- Node API listens on port 5000 (NOT exposed to intranet)

### 5.1 Deploy the backend files
Copy backend code to server, example:
- `E:\Apps\SQLInventory\backend\`

Ensure:
- `E:\Apps\SQLInventory\backend\.env` exists
- Node 20 is installed

### 5.2 Install PM2 and PM2 Windows Service tools
Run PowerShell as Administrator:
```powershell
npm install -g pm2
npm install -g pm2-windows-service
pm2-service-install
```

If PM2 service runs as **Local System** (common choice), you must manage PM2 using:
```text
PM2_HOME = C:\Windows\System32\config\systemprofile\.pm2
```

### 5.3 Start and persist the backend under Local System PM2_HOME (ONE-TIME)
Run PowerShell as Administrator:
```powershell
$env:PM2_HOME="C:\Windows\System32\config\systemprofile\.pm2"

pm2 start E:\Apps\SQLInventory\backend\server.js --name sqlinventory-api
pm2 save

net stop PM2
net start PM2
```

Verify:
```powershell
$env:PM2_HOME="C:\Windows\System32\config\systemprofile\.pm2"
pm2 list
curl http://localhost:5000/api/auth/me
```

Important:
- Local System must have read access to `E:\Apps\SQLInventory\backend\server.js` and `E:\Apps\SQLInventory\backend\.env`.

### 5.4 Build and deploy the frontend
On a build machine (or the server):
```powershell
cd <path>\InventoryApp\frontend
npm install
npm run build
```

Copy the contents of `frontend/build/` to IIS site folder, example:
- `E:\Apps\SQLInventory\frontend\`

Your IIS physical path must contain:
- `index.html`
- `web.config` (required for SPA routing + API reverse proxy)

### 5.5 IIS requirements (modules)
Install on the IIS server:
- IIS URL Rewrite
- ARR (Application Request Routing)

Enable proxy:
- IIS Manager -> Server -> Application Request Routing Cache -> Server Proxy Settings -> Enable Proxy

### 5.6 IIS site configuration
Create a website or use Default Web Site (recommended: dedicated site):
- Port: 80
- Hostname: optional (if you have DNS); otherwise use server IP
- Physical Path: `E:\Apps\SQLInventory\frontend` (folder containing `index.html`)

### 5.7 Firewall guidance (IIS server)
Recommended inbound rules:
- Allow TCP 80 (intranet only)
- Block TCP 5000 (do not expose Node)

Example:
```powershell
New-NetFirewallRule -DisplayName "SQLInventory - Block API 5000 Inbound" -Direction Inbound -Action Block -Protocol TCP -LocalPort 5000
New-NetFirewallRule -DisplayName "SQLInventory - Allow HTTP 80 Inbound" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 80
```

### 5.8 Smoke tests (from client machine)
Open:
- `http://<iis-server-ip>/`

Verify API reverse proxy:
- `http://<iis-server-ip>/api/auth/me`
Expected: `401 Unauthorized`

---

## 6) Common Operational Tasks

### Restart backend after deploying new backend code
If PM2 service runs as Local System:
```powershell
$env:PM2_HOME="C:\Windows\System32\config\systemprofile\.pm2"
pm2 restart sqlinventory-api
pm2 save
```

If PM2 CLI cannot connect, restart service:
```powershell
net stop PM2
net start PM2
```

### Deploying a new frontend build
1. Copy new `frontend/build/*` to the IIS physical path
2. Restart IIS site (or `iisreset`)
3. Client hard refresh: `Ctrl+F5`

---

## 7) Notes (Important)

### Frontend/Backend version coupling
If frontend expects new API fields (example: `totalSqlInstances` in dashboard summary),
you must deploy the updated backend at the same time. Otherwise UI may show `0` or fallback values.

### Reverse proxy behavior
In IIS deployments, the frontend calls `/api/...` (same origin). Do not configure frontend to call `http://localhost:5000` in production.

