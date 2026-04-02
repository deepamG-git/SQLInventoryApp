# SQL Inventory Portal - README (Frontend + Backend + IIS)

Internal SQL Server Inventory portal for governed inventory entry, executive reporting, exportable server/database lists, database trend analysis and Monitor Server Health. Designed for intranet hosting behind IIS reverse proxy.

## What It Does
- Login (username/password)
- Executive Dashboard with KPIs and interactive metrics (counts only `IN USE` servers)
- Health Report (daily DBA view for PROD servers)
  - Export all sections to a single CSV
  - Send Email Report (Database Mail)
- Server List (exportable)
- Database List (exportable)
- Database Trend (last 6 months, exportable)
- Server Details page (search + deep view)
- Admin-only Inventory Form (create + edit/update) with change history logging

## High-Level Architecture
Browser (React SPA)
-> IIS (static hosting + reverse proxy for /api)
-> Node.js API (Express, JWT auth)
-> SQL Server (SQLInventory database, inventory schema)

## Roles
- `admin`
  - Dashboard + Health Report + Server List + Database List + Database Trend + Server Details + Inventory Form
  - Can insert/update inventory
- `readonly`
  - Dashboard + Health Report + Server List + Database List + Database Trend + Server Details
  - No access to Inventory Form

Role is enforced in both the API (middleware) and UI navigation.

## URLs (Frontend Routes)
- `/login` (and `/` redirects to dashboard after auth)
- `/dashboard` Executive dashboard
- `/health` Server health report view (admin + readonly)
- `/serverlist` Flattened list + export (admin + readonly)
- `/databaselist` Flattened list + export (admin + readonly)
- `/databasetrend` Database size trend report + export (admin + readonly)
- `/server/<ServerID>` Server details view (admin + readonly)
- `/inventory` Inventory form (admin only)


## UI Overview
### Inventory Form (Tabbed, Admin Only)
Tabs:
1. Server
2. Hardware
3. SQL (supports multiple instances)
4. Network
5. Contacts
6. Review

SQL Instances support multiple SQL instances per server. Each instance captures:
- InstanceName
- InstanceType (lookup)
- SQLInstallDate (per instance)
- Version: SQLVersion, SQLEdition, ProductBuild, ProductLevel, VersionEffectiveDate
- Config: Collation (lookup), Min/Max memory, MaxDOP, Cost Threshold, Adhoc/LockPages/IFI/DBMail/FileStream, ConfigEffectiveDate

### Executive Dashboard (Admin + Readonly)
- KPI strip includes total servers + BU cards (click BU card to filter the dashboard)
- Interactive metric blocks (click to filter the dashboard like BU cards):
  - Environment
  - Region
  - Platform
  - OS Category (Windows/Linux)
  - Server Type
  - SQL Version
  - SQL Edition
  - Instance Type
- KPI includes SQL Instance count (interactive)
- Tables:
  - Recently Added/Modified (last 1 month)
  - TO BE COMMISSIONED
  - DECOMMISSIONED in last 3 months

Important:
- KPIs/charts count only servers with `ServerStatus = 'IN USE'`.

### Server Search and Server Details (Admin + Readonly)
Dashboard search:
- If exactly one match: opens `/server/<id>`
- Otherwise: shows clickable results

Server Details page (`/server/<id>`) shows:
1. OS Details
2. Network Details
3. SQL Instance Details (repeats for multiple instances)
4. Storage Details
5. Support Contact
6. Other Details:
   - Server Effective From (ServerHardware.EffectiveDate)
   - OS Install Date (ServerHardware.OSInstallDate)
   - SQL Install Date (SQLInstance.SQLInstallDate)
   - Recent Patch Applied On (VersionEffectiveDate of primary/default instance if present, otherwise first instance)

### ServerList (Admin + Readonly)
- BU KPI cards (click to filter)
- Flattened table: one row per SQL instance (servers with multiple instances appear as multiple rows)
- `ServerName` is clickable (opens `/server/<ServerID>`)
- Filter box and CSV export (Excel compatible)

### Health Report (Admin + Readonly)
- Requires selecting Business Unit + PROD Server (PROD + IN USE)
- Shows:
  - Druva backup summary report from last 24 hours + per-database latest full/diff backup dates (with time)
  - Disk space details for SQL disks only (mdf/ldf)
  - Latest status of DBA maintenance jobs
- Actions:
  - Export All (CSV): exports all sections together into one CSV
  - Send Email Report: prompts for Recipients/CC and triggers Database Mail via stored procedure

### Database List (Admin + Readonly)
- Dropdown filters: Business Unit + Server (optional; default shows all)
- KPI: Total databases (for current selection)
- Export CSV

### Database Trend (Admin + Readonly)
- Select Business Unit + PROD Server (PROD + IN USE)
- Shows last 6 months monthly max DB size and `%Change(6M)` (red if >20% increase, green otherwise)
- Export CSV

## Backend (Node.js API)
Location:
- `..\backend\server.js`

Tech:
- Node.js 20
- Express
- `mssql` driver
- JWT auth

### Backend Environment Variables (`backend/.env`)
Typical:
- `DB_HOST=...`
- `DB_PORT=...`
- `DB_NAME=SQLInventory`
- `DB_USER=...`
- `DB_PASSWORD=...`
- `JWT_SECRET=...`
- `PORT=5000`

### API Endpoints
Auth:
- `POST /api/auth/login`
- `GET /api/auth/me`

Admin-only:
- `GET /api/lookups`
- `GET /api/servers`
- `POST /api/inventory`
- `GET /api/inventory/:serverId`
- `PUT /api/inventory/:serverId`

Read-only + Admin:
- `GET /api/dashboard/summary?bu=<BUID>`
- `GET /api/health/prod-servers?buId=<BUID>`
- `GET /api/health/report?serverId=<ServerID>`
- `POST /api/health/email-report`
- `GET /api/server-search?name=<term>`
- `GET /api/server-details/:serverId`
- `GET /api/server-list?bu=<BUID>&inUseOnly=1`
- `GET /api/database-list?buId=<BUID>&serverId=<ServerID>`
- `GET /api/db-trend?buId=<BUID>&serverId=<ServerID>&monthsBack=6`

### Change History
Updates are logged into:
- `inventory.ChangeHistory`

### SQLInstallDate
New column:
- `inventory.SQLInstance.SQLInstallDate date NULL`

Idempotent DDL script:
- `..\backend\sql\alter_20260312_add_sqlinstalldate.sql`

## SQL Objects (Collectors + Reporting Tables)
Key SQL scripts live under `..\backend\sql\` (recommended schedule: hourly for collectors, monthly for trend rollup):
- SQLDatabase inventory and trend:
  - `alter_20260318_create_sqldatabase.sql`
  - `alter_20260319_create_sqldatabase_daily_snapshot.sql`
  - `alter_20260319_create_sqldatabase_monthly_max.sql`
  - `sp_20260319_refresh_sqldatabase_from_linkedservers.sql`
  - `sp_20260319_calc_sqldatabase_monthly_max.sql`
- Backup reporting:
  - `alter_20260319_create_databasebackup.sql`
  - `sp_20260319_collect_databasebackup_last24h.sql`
  - `sp_20260320_collect_databasebackup_all_linkedservers.sql`
- Maintenance job reporting:
  - `alter_20260319_create_sqlmaintenancejobrun.sql`
  - `sp_20260319_collect_sqlmaintenancejobs.sql`
- Linked Server mapping helper:
  - `alter_20260319_create_linkedserver_map.sql`
- Health email (Database Mail):
  - `sp_20260324_email_health_report_dbmail.sql`

## IIS Intranet Hosting (Reverse Proxy)
IIS serves the React `build` folder and proxies `/api/*` to Node at `http://localhost:5000`.

### Requirements
- IIS URL Rewrite module
- ARR (Application Request Routing) with proxy enabled:
  - IIS Manager -> Server -> Application Request Routing Cache -> Server Proxy Settings -> Enable Proxy

### `web.config`
React build includes `web.config` (from `public/web.config`) to:
- Proxy `/api/*` -> `http://localhost:5000/api/*`
- SPA fallback routing to `index.html`

### Firewall Guidance (IIS Server)
- Allow inbound TCP 80 (intranet only)
- Block inbound TCP 5000 (Node API should not be exposed)
- Allow outbound to SQL Server TCP 1433 (to `VGLIND-TSDB-SRV`)

## Build and Deploy (Frontend)
```powershell
npm install
npm run build
```
Deploy:
- Copy `build\*` to IIS site physical path (ensure `index.html` and `web.config` are there)
- Restart IIS site (or `iisreset`)

## Local Development (Frontend)
```powershell
npm start
```
## Server Deployment(Frontend)
- Copy `build\*` to IIS site physical path (ensure `index.html` and `web.config` are there)
- Restart IIS site (or `iisreset`)

## Server Deployment(Backend)
- Copy the `backend\*` to physical path of your App
```powershell(admin)
net stop pm2
net start pm2
pm2 list (check if node app is running)
pm start E:\Apps\SQLInventory\backend\server.js --name sqlinventory-api (In case pm2 list gives no output)  
```

Notes:
- The correct command is `pm2 start ...` (not `pm start ...`).
- If your PM2 service runs as `Local System`, you may need to set `PM2_HOME` to:
  - `C:\Windows\System32\config\systemprofile\.pm2`
- For full deployment steps, see `INSTALLATION.md`.

## GitHub Safety Notes
Before uploading to GitHub (especially public GitHub):
- Do not commit `.env` files (DB passwords, JWT secrets, mail profile names).
- Commit only `.env.example` with placeholders.
- Do not commit exported inventory data (contacts/emails/phone).
- Scrub internal hostnames/IPs if the repository will be public.
