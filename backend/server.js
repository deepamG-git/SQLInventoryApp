const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const rateLimit = require("express-rate-limit");
const sql = require("mssql");
const crypto = require("crypto");
const jwt = require("jsonwebtoken");
require("dotenv").config();

const app = express();
const PORT = Number(process.env.PORT || 5000);

// JWT settings
// Security notes:
// - Do not ship with a default secret; require it via env
// - Lock verification to an explicit algorithm to avoid "alg" header confusion
// - Optionally set issuer/audience to bind tokens to your app
const JWT_SECRET = process.env.JWT_SECRET;
const JWT_EXPIRY = process.env.JWT_EXPIRY || "15m";
const JWT_ALGORITHM = (process.env.JWT_ALGORITHM || "HS256").toUpperCase();
const JWT_ISSUER = process.env.JWT_ISSUER;
const JWT_AUDIENCE = process.env.JWT_AUDIENCE;

// Stored procedures (override if your DB uses different names)
const SP_EMAIL_DB_TREND = process.env.SP_EMAIL_DB_TREND || "inventory.usp_Email_DBTrend_Server";

// IIS / reverse-proxy settings.
// Keep defaults non-breaking; enable explicitly in IIS via env variables.
const TRUST_PROXY = String(process.env.TRUST_PROXY || "").trim() === "1";
const FORCE_HTTPS = String(process.env.FORCE_HTTPS || "").trim() === "1";

// CORS: to avoid breaking existing intranet setups, default is permissive.
// To lock it down, set CORS_ORIGINS to a comma-separated list (e.g. "https://intranet-app.company.local").
const CORS_ORIGINS_RAW = String(process.env.CORS_ORIGINS || "").trim();
const CORS_ORIGINS = CORS_ORIGINS_RAW
  ? CORS_ORIGINS_RAW.split(",").map((s) => s.trim()).filter(Boolean)
  : null;

function requireJwtSecret() {
  if (!JWT_SECRET) {
    throw new Error("Missing JWT_SECRET. Set a long random value in your environment (.env) before starting the server.");
  }

  // For HS* algorithms, treat JWT_SECRET as the HMAC key material.
  // Enforce a minimum length to prevent trivially guessable secrets.
  if (JWT_SECRET.length < 32) {
    throw new Error("JWT_SECRET is too short. Use at least 32 characters (recommended: 64+).");
  }

  const allowed = new Set(["HS256", "HS384", "HS512"]);
  if (!allowed.has(JWT_ALGORITHM)) {
    throw new Error(`Unsupported JWT_ALGORITHM '${JWT_ALGORITHM}'. Supported values: HS256, HS384, HS512.`);
  }

  return JWT_SECRET;
}

const JWT_KEY = requireJwtSecret();

const dbConfig = {
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  server: process.env.DB_HOST,
  port: Number(process.env.DB_PORT || 1433),
  database: process.env.DB_NAME,
  options: {
    encrypt: false,
    trustServerCertificate: true,
  },
  pool: {
    max: 10,
    min: 0,
    idleTimeoutMillis: 30000,
  },
};

let pool;
async function getPool() {
  if (pool) return pool;
  pool = await sql.connect(dbConfig);
  return pool;
}

if (TRUST_PROXY) {
  // Required behind IIS/ARR so req.ip and x-forwarded-* are respected (rate-limits, HTTPS detection, logs).
  app.set("trust proxy", 1);
}

app.disable("x-powered-by");
app.use(
  helmet({
    // API-only server; no need for Helmet's CSP by default (keeps behavior predictable if you later serve HTML).
    contentSecurityPolicy: false,
  })
);

if (FORCE_HTTPS) {
  app.use((req, res, next) => {
    // Works when IIS forwards the original scheme via X-Forwarded-Proto and trust proxy is enabled.
    if (req.secure) return next();
    return res.status(400).json({ message: "HTTPS is required" });
  });
}

app.use(
  cors(
    CORS_ORIGINS
      ? {
          origin: (origin, cb) => {
            // Allow non-browser clients (no Origin header), and allowlisted browser origins.
            if (!origin) return cb(null, true);
            if (CORS_ORIGINS.includes(origin)) return cb(null, true);
            return cb(null, false);
          },
          methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
          allowedHeaders: ["Content-Type", "Authorization"],
          optionsSuccessStatus: 204,
        }
      : undefined
  )
);
app.use(express.json());

// Optional: rate limit login attempts (off by default to avoid breaking NAT'd intranet users).
const ENABLE_LOGIN_RATE_LIMIT = String(process.env.ENABLE_LOGIN_RATE_LIMIT || "").trim() === "1";
const LOGIN_RATE_WINDOW_MS = Number(process.env.LOGIN_RATE_WINDOW_MS || 15 * 60 * 1000);
const LOGIN_RATE_MAX = Number(process.env.LOGIN_RATE_MAX || 30);
const loginLimiter = rateLimit({
  windowMs: LOGIN_RATE_WINDOW_MS,
  max: LOGIN_RATE_MAX,
  standardHeaders: "draft-7",
  legacyHeaders: false,
  message: { message: "Too many login attempts. Try again later." },
});

const lookupQueries = {
  environments: "SELECT EnvID AS id, EnvName AS name FROM inventory.Environment ORDER BY EnvName",
  regions: "SELECT RegionID AS id, RegionName AS name FROM inventory.Region ORDER BY RegionName",
  businessUnits: "SELECT BUID AS id, BusinessUnitName AS name FROM inventory.BusinessUnit ORDER BY BusinessUnitName",
  categories: "SELECT CategoryID AS id, CategoryName AS name FROM inventory.ServerCategory ORDER BY CategoryName",
  statuses: "SELECT StatusID AS id, StatusName AS name FROM inventory.ServerStatus ORDER BY StatusName",
  osTypes: "SELECT OSID AS id, OperatingSystem AS name, OSCategory FROM inventory.OSType ORDER BY OperatingSystem",
  osCategories: "SELECT DISTINCT OSCategory AS id, OSCategory AS name FROM inventory.OSType WHERE OSCategory IS NOT NULL ORDER BY OSCategory",
  serverTypes: "SELECT ServerTypeID AS id, ServerType AS name FROM inventory.ServerType ORDER BY ServerType",
  platforms: "SELECT PlatformID AS id, PlatformName AS name FROM inventory.Platform ORDER BY PlatformName",
  ipAddressTypes: "SELECT IPAddressTypeID AS id, TypeName AS name FROM inventory.IPAddressType ORDER BY TypeName",
  sqlVersions: "SELECT SQLVersionID AS id, SQLVersionName AS name FROM inventory.SQLVersion ORDER BY SQLVersionName",
  sqlEditions: "SELECT SQLEditionID AS id, SQLEditionName AS name FROM inventory.SQLEdition ORDER BY SQLEditionName",
  contactCategories: "SELECT ContactCategoryID AS id, ContactCategoryName AS name FROM inventory.ContactCategory ORDER BY ContactCategoryName",
  domains: "SELECT DomainID AS id, DomainName AS name FROM inventory.Domain ORDER BY DomainName",
  timezones: "SELECT TimezoneID AS id, Timezone AS name FROM inventory.Timezone ORDER BY Timezone",
  sqlInstanceTypes: "SELECT InstanceTypeID AS id, InstanceTypeName AS name FROM inventory.SQLInstanceType ORDER BY InstanceTypeName",
  sqlInstanceCollations: "SELECT InstanceCollationID AS id, InstanceCollationName AS name FROM inventory.SQLInstanceCollation ORDER BY InstanceCollationName",
};

function required(value) {
  return !(value === undefined || value === null || value === "");
}

function hashPassword(password, salt) {
  return crypto.createHash("sha256").update(`${password}${salt}`, "utf8").digest("hex");
}

function authenticate(req, res, next) {
  const authHeader = req.headers.authorization || "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;

  if (!token) return res.status(401).json({ message: "Unauthorized" });

  try {
    const verifyOptions = { algorithms: [JWT_ALGORITHM] };
    if (JWT_ISSUER) verifyOptions.issuer = JWT_ISSUER;
    if (JWT_AUDIENCE) verifyOptions.audience = JWT_AUDIENCE;

    const decoded = jwt.verify(token, JWT_KEY, verifyOptions);
    req.user = { userId: decoded.userId, username: decoded.username, role: decoded.role || "readonly" };
    return next();
  } catch {
    return res.status(401).json({ message: "Invalid or expired token" });
  }
}

function requireAdmin(req, res, next) {
  if ((req.user?.role || "").toLowerCase() !== "admin") {
    return res.status(403).json({ message: "Forbidden: admin access required" });
  }
  return next();
}

function validatePayload(payload) {
  const errors = [];
  const server = payload.server || {};
  const hardware = payload.serverHardware || {};
  const sqlInstances = payload.sqlInstances || [];
  const contactMode = String(payload.contactMode || "bu").toLowerCase();

  if (!required(server.serverName)) errors.push("server.serverName is required");
  ["envId", "buId", "categoryId", "regionId", "statusId"].forEach((k) => {
    if (!required(server[k])) errors.push(`server.${k} is required`);
  });

  ["domainId", "operatingSystemId", "memoryGB", "cpuCores", "serverTypeId", "platformId", "timezoneId"].forEach((k) => {
    if (!required(hardware[k])) errors.push(`serverHardware.${k} is required`);
  });

  if (!Array.isArray(sqlInstances) || sqlInstances.length === 0) {
    errors.push("At least one SQL instance is required");
  } else {
    sqlInstances.forEach((inst, i) => {
      if (!required(inst.instanceName)) errors.push(`sqlInstances[${i}].instanceName is required`);
      if (!required(inst.instanceTypeId)) errors.push(`sqlInstances[${i}].instanceTypeId is required`);
      ["sqlVersionId", "sqlEditionId", "productBuild", "productLevel"].forEach((k) => {
        if (!required(inst[k])) errors.push(`sqlInstances[${i}].${k} is required`);
      });
      if (!required(inst.instanceCollationId)) errors.push(`sqlInstances[${i}].instanceCollationId is required`);

      if (inst.databases !== undefined) {
        if (!Array.isArray(inst.databases)) {
          errors.push(`sqlInstances[${i}].databases must be an array`);
        } else {
          inst.databases.forEach((db, di) => {
            const hasAny =
              required(db?.databaseName) ||
              required(db?.owner) ||
              required(db?.sizeGB) ||
              required(db?.createdOn) ||
              required(db?.recoveryModel) ||
              required(db?.databaseCollation) ||
              Boolean(db?.cdc) ||
              required(db?.compatibilityLevel) ||
              Boolean(db?.encryption) ||
              Boolean(db?.queryStore) ||
              Boolean(db?.autoUpdateStats);
            if (!hasAny) return;
            if (!required(db?.databaseName)) errors.push(`sqlInstances[${i}].databases[${di}].databaseName is required`);
          });
        }
      }
    });
  }
  if (!Array.isArray(payload.serverIPs) || payload.serverIPs.length === 0) errors.push("At least one server IP is required");
  if (!Array.isArray(payload.serverStorages) || payload.serverStorages.length === 0) errors.push("At least one server storage row is required");
  if (payload.contacts && !Array.isArray(payload.contacts)) errors.push("contacts must be an array");
  if (!["bu", "custom"].includes(contactMode)) errors.push("contactMode must be either 'bu' or 'custom'");

  return errors;
}

async function logChange(tx, entityName, recordId, fieldName, oldValue, newValue, changedBy) {
  if (String(oldValue ?? "") === String(newValue ?? "")) return;
  await new sql.Request(tx)
    .input("EntityName", sql.VarChar(100), entityName)
    .input("RecordID", sql.Int, recordId)
    .input("FieldName", sql.VarChar(100), fieldName)
    .input("OldValue", sql.VarChar(sql.MAX), oldValue === null || oldValue === undefined ? null : String(oldValue))
    .input("NewValue", sql.VarChar(sql.MAX), newValue === null || newValue === undefined ? null : String(newValue))
    .input("ChangedBy", sql.VarChar(100), changedBy)
    .query(`
      INSERT INTO inventory.ChangeHistory (EntityName, RecordID, FieldName, OldValue, NewValue, ChangedBy)
      VALUES (@EntityName, @RecordID, @FieldName, @OldValue, @NewValue, @ChangedBy);
    `);
}

async function getServerForEdit(serverId) {
  const conn = await getPool();

  const server = await conn.request().input("ServerID", sql.Int, serverId).query(`
    SELECT ServerID, ServerName, Description, EnvID, BUID, CategoryID, RegionID, StatusID, CreatedBy
    FROM inventory.Server
    WHERE ServerID = @ServerID;
  `);

  if (!server.recordset.length) return null;

  const hardware = await conn.request().input("ServerID", sql.Int, serverId).query(`
    SELECT TOP 1 DomainID, OperatingSystemID, MemoryGB, CPUCores, ProcessorModel, ServerTypeID, PlatformID, TimezoneID, OSInstallDate, IsCurrent, EffectiveDate
    FROM inventory.ServerHardware
    WHERE ServerID = @ServerID AND IsCurrent = 1
    ORDER BY ServerHardwareID DESC;
  `);

  const sqlInstances = await conn.request().input("ServerID", sql.Int, serverId).query(`
    SELECT
      si.SQLInstanceID,
      si.InstanceName,
      si.InstanceTypeID,
      si.SQLInstallDate,
      iv.SQLVersionID,
      iv.SQLEditionID,
      iv.ProductBuild,
      iv.ProductLevel,
      iv.EffectiveDate AS VersionEffectiveDate,
      ic.InstanceCollationID,
      ic.MinMemoryMB,
      ic.MaxMemoryMB,
      ic.MaxDOP,
      ic.CostThresholdParallelism,
      ic.AdhocWorkload,
      ic.LockPageInMemory,
      ic.IFI,
      ic.DatabaseMail,
      ic.FileStream,
      ic.EffectiveDate AS ConfigEffectiveDate
    FROM inventory.SQLInstance si
    OUTER APPLY (
      SELECT TOP 1 SQLVersionID, SQLEditionID, ProductBuild, ProductLevel, EffectiveDate
      FROM inventory.SQLInstanceVersion
      WHERE SQLInstanceID = si.SQLInstanceID AND IsCurrent = 1
      ORDER BY SQLInstanceVersionID DESC
    ) iv
    OUTER APPLY (
      SELECT TOP 1 InstanceCollationID, MinMemoryMB, MaxMemoryMB, MaxDOP, CostThresholdParallelism, AdhocWorkload, LockPageInMemory, IFI, DatabaseMail, FileStream, EffectiveDate
      FROM inventory.SQLInstanceConfig
      WHERE SQLInstanceID = si.SQLInstanceID AND IsCurrent = 1
      ORDER BY SQLInstanceConfigID DESC
    ) ic
    WHERE si.ServerID = @ServerID AND ISNULL(si.IsActive, 1) = 1
    ORDER BY si.InstanceName;
  `);

  // Databases (per instance)
  const instanceIds = (sqlInstances.recordset || []).map((r) => r.SQLInstanceID).filter(Boolean);
  let dbRows = [];
  if (instanceIds.length) {
    const rs = await conn.request().query(`
      SELECT
        SQLDatabaseID,
        SQLInstanceID,
        DatabaseName,
        Owner,
        SizeGB,
        CreatedOn,
        RecoveryModel,
        DatabaseCollation,
        CDC,
        CompatibilityLevel,
        Encryption,
        QueryStore,
        AutoUpdateStats,
        IsActive
      FROM inventory.SQLDatabase
      WHERE IsActive = 1 AND SQLInstanceID IN (${instanceIds.join(",")})
      ORDER BY SQLInstanceID, DatabaseName;
    `);
    dbRows = rs.recordset || [];
  }
  const dbMap = new Map();
  for (const r of dbRows) {
    const k = r.SQLInstanceID;
    if (!dbMap.has(k)) dbMap.set(k, []);
    dbMap.get(k).push(r);
  }

  const ips = await conn.request().input("ServerID", sql.Int, serverId).query(`
    SELECT IPID, IPAddress, IPAddressTypeID, IsActive
    FROM inventory.ServerIP
    WHERE ServerID = @ServerID AND IsActive = 1
    ORDER BY IPID;
  `);

  const storage = await conn.request().input("ServerID", sql.Int, serverId).query(`
    SELECT StorageID, DriveLetter, VolumeLabel, TotalSizeGB, FreeSpaceGB, IsActive
    FROM inventory.ServerStorage
    WHERE ServerID = @ServerID AND IsActive = 1
    ORDER BY StorageID;
  `);

  const contacts = await conn.request().input("BUID", sql.Int, server.recordset[0].BUID).query(`
    SELECT c.ContactID, c.ContactName, c.Email, c.Phone, buc.ContactCategoryID
    FROM inventory.BusinessUnitContact buc
    INNER JOIN inventory.Contact c ON c.ContactID = buc.ContactID
    WHERE buc.BUID = @BUID
    ORDER BY c.ContactName;
  `);

  const serverContacts = await conn.request().input("ServerID", sql.Int, serverId).query(`
    SELECT c.ContactID, c.ContactName, c.Email, c.Phone, sc.ContactCategoryID
    FROM inventory.ServerContact sc
    INNER JOIN inventory.Contact c ON c.ContactID = sc.ContactID
    WHERE sc.ServerID = @ServerID
    ORDER BY c.ContactName;
  `);

  const hasCustomContacts = (serverContacts.recordset || []).length > 0;

  return {
    server: server.recordset[0],
    serverHardware: hardware.recordset[0] || {},
    sqlInstances: (sqlInstances.recordset || []).map((i) => ({ ...i, Databases: dbMap.get(i.SQLInstanceID) || [] })),
    serverIPs: ips.recordset,
    serverStorages: storage.recordset,
    contactMode: hasCustomContacts ? "custom" : "bu",
    contacts: hasCustomContacts ? (serverContacts.recordset || []) : [],
    buDefaultContacts: contacts.recordset || [],
  };
}

app.get("/", (_req, res) => res.send("Inventory API Running"));

app.post("/api/auth/login", ...(ENABLE_LOGIN_RATE_LIMIT ? [loginLimiter] : []), async (req, res) => {
  try {
    const { username, password } = req.body || {};
    if (!required(username) || !required(password)) {
      return res.status(400).json({ message: "Username and password are required" });
    }

    const conn = await getPool();
    const rs = await conn
      .request()
      .input("Username", sql.VarChar(100), String(username).trim())
      .query(`
        SELECT UserID, Username, PasswordHash, PasswordSalt, IsActive, ISNULL(UserRole, 'readonly') AS UserRole
        FROM inventory.AppUser
        WHERE Username = @Username;
      `);

    if (!rs.recordset.length) return res.status(401).json({ message: "Invalid credentials" });

    const user = rs.recordset[0];
    if (!user.IsActive) return res.status(403).json({ message: "User is inactive" });

    const incomingHash = hashPassword(String(password), String(user.PasswordSalt));
    if (incomingHash.toLowerCase() !== String(user.PasswordHash).toLowerCase()) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    const role = String(user.UserRole || "readonly").toLowerCase();
    const signOptions = { expiresIn: JWT_EXPIRY, algorithm: JWT_ALGORITHM };
    if (JWT_ISSUER) signOptions.issuer = JWT_ISSUER;
    if (JWT_AUDIENCE) signOptions.audience = JWT_AUDIENCE;

    const token = jwt.sign({ userId: user.UserID, username: user.Username, role }, JWT_KEY, signOptions);
    return res.json({ token, user: { userId: user.UserID, username: user.Username, role } });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ message: "Login failed" });
  }
});

app.get("/api/auth/me", authenticate, (req, res) => {
  res.json({ user: req.user });
});

app.get("/api/lookups", authenticate, requireAdmin, async (_req, res) => {
  try {
    const conn = await getPool();
    const data = {};
    for (const [k, q] of Object.entries(lookupQueries)) {
      const rs = await conn.request().query(q);
      data[k] = rs.recordset;
    }
    res.json(data);
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Failed to load lookups" });
  }
});

// Read-only friendly lookup endpoints for list pages.
app.get("/api/business-units", authenticate, async (_req, res) => {
  try {
    const conn = await getPool();
    const rs = await conn.request().query("SELECT BUID AS id, BusinessUnitName AS name FROM inventory.BusinessUnit ORDER BY BusinessUnitName;");
    return res.json(rs.recordset || []);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ message: "Failed to load business units" });
  }
});

app.get("/api/servers-by-bu", authenticate, async (req, res) => {
  try {
    const buId = String(req.query.buId || "").trim();
    const conn = await getPool();
    const q = buId
      ? "SELECT ServerID AS id, ServerName AS name FROM inventory.Server WHERE BUID = @BUID ORDER BY ServerName;"
      : "SELECT ServerID AS id, ServerName AS name FROM inventory.Server ORDER BY ServerName;";
    const r = buId ? await conn.request().input("BUID", sql.Int, Number(buId)).query(q) : await conn.request().query(q);
    return res.json(r.recordset || []);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ message: "Failed to load servers" });
  }
});

app.get("/api/servers", authenticate, requireAdmin, async (_req, res) => {
  try {
    const conn = await getPool();
    const rs = await conn.request().query("SELECT ServerID AS id, ServerName AS name FROM inventory.Server ORDER BY ServerName;");
    res.json(rs.recordset);
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Failed to load servers" });
  }
});

app.get("/api/bu-default-contacts/:buId", authenticate, requireAdmin, async (req, res) => {
  try {
    const buId = Number(req.params.buId);
    if (!buId) return res.status(400).json({ message: "Invalid buId" });

    const conn = await getPool();
    const rs = await conn
      .request()
      .input("BUID", sql.Int, buId)
      .query(`
        SELECT c.ContactName, c.Email, c.Phone, buc.ContactCategoryID
        FROM inventory.BusinessUnitContact buc
        INNER JOIN inventory.Contact c ON c.ContactID = buc.ContactID
        WHERE buc.BUID = @BUID
        ORDER BY buc.ContactCategoryID, c.ContactName;
      `);
    return res.json(rs.recordset);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ message: "Failed to load BU default contacts" });
  }
});

// Flattened server list (one row per SQL instance; read-only users allowed).
// Default: only servers with status 'IN USE' to match executive reporting.
app.get("/api/server-list", authenticate, async (req, res) => {
  try {
    const conn = await getPool();
    const buParam = String(req.query.bu || "").trim();
    const inUseOnlyParam = String(req.query.inUseOnly || "1").trim();

    let selectedBUID = null;
    if (buParam) {
      if (/^\d+$/.test(buParam)) {
        selectedBUID = Number(buParam);
      } else {
        const buLookup = await conn.request().input("BusinessUnitName", sql.VarChar(100), buParam).query(`
          SELECT TOP 1 BUID FROM inventory.BusinessUnit WHERE BusinessUnitName = @BusinessUnitName;
        `);
        if (buLookup.recordset.length) selectedBUID = buLookup.recordset[0].BUID;
      }
    }

    const inUseOnly = !(inUseOnlyParam === "0" || inUseOnlyParam.toLowerCase() === "false");

    const rs = await conn
      .request()
      .input("BUID", sql.Int, selectedBUID)
      .input("InUseOnly", sql.Bit, inUseOnly ? 1 : 0)
      .query(`
        WITH ipAgg AS (
          -- STRING_AGG is not available on older SQL Server versions (e.g. 2016). Use FOR XML PATH instead.
          SELECT
            ip.ServerID,
            STUFF((
              SELECT ', ' + ip2.IPAddress
              FROM inventory.ServerIP ip2
              WHERE ip2.ServerID = ip.ServerID AND ip2.IsActive = 1
              ORDER BY ip2.IPAddress
              FOR XML PATH(''), TYPE
            ).value('.', 'nvarchar(max)'), 1, 2, '') AS IPAddress
          FROM inventory.ServerIP ip
          WHERE ip.IsActive = 1
          GROUP BY ip.ServerID
        )
        SELECT
          bu.BusinessUnitName AS BUName,
          s.ServerID AS ServerID,
          s.ServerName AS ServerName,
          env.EnvName AS Environment,
          s.Description AS ServerDescription,
          r.RegionName AS Region,
          p.PlatformName AS Platform,
          st.ServerType AS ServerType,
          d.DomainName AS Domain,
          ISNULL(ip.IPAddress, '') AS IPAddress,
          sh.CPUCores AS Cores,
          sh.MemoryGB AS RAM,
          os.OperatingSystem AS OperatingSystem,
          i.InstanceName AS SQLInstanceName,
          it.InstanceTypeName AS SQLInstanceType,
          sv.SQLVersionName AS SQLVersion,
          se.SQLEditionName AS SQLEdition,
          iv.ProductBuild AS ProductBuild,
          iv.ProductLevel AS ProductLevel
        FROM inventory.Server s
        INNER JOIN inventory.ServerStatus ss ON ss.StatusID = s.StatusID
        INNER JOIN inventory.BusinessUnit bu ON bu.BUID = s.BUID
        INNER JOIN inventory.Environment env ON env.EnvID = s.EnvID
        INNER JOIN inventory.Region r ON r.RegionID = s.RegionID
        INNER JOIN inventory.ServerHardware sh ON sh.ServerID = s.ServerID AND sh.IsCurrent = 1
        INNER JOIN inventory.Platform p ON p.PlatformID = sh.PlatformID
        INNER JOIN inventory.ServerType st ON st.ServerTypeID = sh.ServerTypeID
        INNER JOIN inventory.OSType os ON os.OSID = sh.OperatingSystemID
        LEFT JOIN inventory.Domain d ON d.DomainID = sh.DomainID
        LEFT JOIN ipAgg ip ON ip.ServerID = s.ServerID
        LEFT JOIN inventory.SQLInstance i ON i.ServerID = s.ServerID AND i.IsActive = 1
        LEFT JOIN inventory.SQLInstanceType it ON it.InstanceTypeID = i.InstanceTypeID
        LEFT JOIN inventory.SQLInstanceVersion iv ON iv.SQLInstanceID = i.SQLInstanceID AND iv.IsCurrent = 1
        LEFT JOIN inventory.SQLVersion sv ON sv.SQLVersionID = iv.SQLVersionID
        LEFT JOIN inventory.SQLEdition se ON se.SQLEditionID = iv.SQLEditionID
        WHERE (@InUseOnly = 0 OR ss.StatusName = 'IN USE')
          AND (@BUID IS NULL OR s.BUID = @BUID)
        ORDER BY bu.BusinessUnitName, s.ServerName, i.InstanceName;
      `);

    res.json(rs.recordset);
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Failed to load server list", error: e.originalError?.info?.message || e.message });
  }
});

// Flattened database list (one row per database; read-only users allowed).
// Default: returns all active database rows; optional filtering by BU and Server.
app.get("/api/database-list", authenticate, async (req, res) => {
  try {
    const conn = await getPool();
    const buId = String(req.query.buId || "").trim();
    const serverId = String(req.query.serverId || "").trim();

    const parsedBu = buId && /^\d+$/.test(buId) ? Number(buId) : null;
    const parsedServer = serverId && /^\d+$/.test(serverId) ? Number(serverId) : null;

    const rs = await conn
      .request()
      .input("BUID", sql.Int, parsedBu)
      .input("ServerID", sql.Int, parsedServer)
      .query(`
        SELECT
          db.SQLDatabaseID,
          bu.BusinessUnitName AS BUName,
          s.ServerName AS ServerName,
          env.EnvName AS Environment,
          si.InstanceName AS SQLInstanceName,
          db.DatabaseName AS DatabaseName,
          db.Owner AS Owner,
          db.SizeGB AS SizeGB,
          db.CreatedOn AS CreatedOn,
          db.RecoveryModel AS RecoveryModel,
          db.DatabaseCollation AS DatabaseCollation,
          db.CDC AS CDC,
          db.CompatibilityLevel AS CompatibilityLevel,
          db.Encryption AS Encryption,
          db.QueryStore AS QueryStore,
          db.AutoUpdateStats AS AutoUpdateStats
        FROM inventory.SQLDatabase db
        INNER JOIN inventory.SQLInstance si ON si.SQLInstanceID = db.SQLInstanceID
        INNER JOIN inventory.Server s ON s.ServerID = si.ServerID
        INNER JOIN inventory.BusinessUnit bu ON bu.BUID = s.BUID
        INNER JOIN inventory.Environment env ON env.EnvID = s.EnvID
        WHERE db.IsActive = 1
          AND ISNULL(si.IsActive, 1) = 1
          AND (@BUID IS NULL OR s.BUID = @BUID)
          AND (@ServerID IS NULL OR s.ServerID = @ServerID)
        ORDER BY bu.BusinessUnitName, s.ServerName, si.InstanceName, db.DatabaseName;
      `);

    return res.json(rs.recordset || []);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ message: "Failed to load database list" });
  }
});

// Database size trend (last N months, default 6) based on inventory.SQLDatabaseMonthlyMax.
app.get("/api/db-trend", authenticate, async (req, res) => {
  try {
    const conn = await getPool();
    const buId = String(req.query.buId || "").trim();
    const serverId = String(req.query.serverId || "").trim();
    const monthsBack = Math.max(1, Math.min(12, Number(req.query.monthsBack || 6)));

    const parsedBu = buId && /^\d+$/.test(buId) ? Number(buId) : null;
    const parsedServer = serverId && /^\d+$/.test(serverId) ? Number(serverId) : null;

    const months = [];
    const now = new Date();
    for (let i = monthsBack - 1; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const ym = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
      const label = d.toLocaleString("en-US", { month: "short", year: "numeric" }).replace(" ", "-");
      months.push({ ym, label });
    }

    const ymList = months.map((m) => `'${m.ym}'`).join(",");

    const existsRs = await conn.request().query("SELECT OBJECT_ID('inventory.SQLDatabaseMonthlyMax','U') AS oid;");
    if (!existsRs.recordset?.[0]?.oid) {
      return res.json({ months, rows: [], server: null });
    }

    let server = null;
    if (parsedServer) {
      const srs = await conn.request().input("ServerID", sql.Int, parsedServer).query(`
        SELECT
          s.ServerID,
          s.ServerName,
          s.Description,
          bu.BusinessUnitName AS BUName,
          env.EnvName AS EnvName
        FROM inventory.Server s
        INNER JOIN inventory.BusinessUnit bu ON bu.BUID = s.BUID
        INNER JOIN inventory.Environment env ON env.EnvID = s.EnvID
        WHERE s.ServerID = @ServerID;
      `);
      server = srs.recordset?.[0] || null;
    }

    const rs = await conn
      .request()
      .input("BUID", sql.Int, parsedBu)
      .input("ServerID", sql.Int, parsedServer)
      .query(`
        SELECT
          bu.BusinessUnitName AS BUName,
          s.ServerName AS ServerName,
          env.EnvName AS Environment,
          si.InstanceName AS SQLInstanceName,
          m.DatabaseName AS DatabaseName,
          m.YearMonth AS YearMonth,
          m.MaxTotalSizeGB AS MaxTotalSizeGB
        FROM inventory.SQLDatabaseMonthlyMax m
        INNER JOIN inventory.SQLInstance si ON si.SQLInstanceID = m.SQLInstanceID
        INNER JOIN inventory.Server s ON s.ServerID = si.ServerID
        INNER JOIN inventory.BusinessUnit bu ON bu.BUID = s.BUID
        INNER JOIN inventory.Environment env ON env.EnvID = s.EnvID
        WHERE m.YearMonth IN (${ymList})
          AND ISNULL(si.IsActive, 1) = 1
          AND (@BUID IS NULL OR s.BUID = @BUID)
          AND (@ServerID IS NULL OR s.ServerID = @ServerID)
        ORDER BY bu.BusinessUnitName, s.ServerName, si.InstanceName, m.DatabaseName, m.YearMonth;
      `);

    return res.json({ months, rows: rs.recordset || [], server });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ message: "Failed to load database trend" });
  }
});

// Send Database Trend report via SQL stored procedure (Database Mail).
// Note: the stored procedure must exist in SQLInventory (override name via SP_EMAIL_DB_TREND).
app.post("/api/db-trend/email-report", authenticate, async (req, res) => {
  try {
    const serverId = Number(req.body?.serverId);
    const recipients = String(req.body?.recipients || "").trim();
    const ccRecipients = String(req.body?.ccRecipients || "").trim();
    const monthsBack = Math.max(1, Math.min(12, Number(req.body?.monthsBack || 6)));

    if (!serverId) return res.status(400).json({ message: "serverId is required" });
    if (!recipients) return res.status(400).json({ message: "recipients is required" });

    const conn = await getPool();

    // Helpful diagnostics if the SP is missing or we are connected to the wrong DB.
    const metaRs = await conn.request().query("SELECT DB_NAME() AS DbName, SUSER_SNAME() AS LoginName;");
    const meta = metaRs.recordset?.[0] || {};

    const spName = String(SP_EMAIL_DB_TREND || "").trim();
    const oidSafe = spName.replace(/'/g, "''");
    const spRs = await conn.request().query(`SELECT OBJECT_ID('${oidSafe}','P') AS oid;`);
    const hasSp = Boolean(spRs.recordset?.[0]?.oid);
    if (!hasSp) {
      return res.status(500).json({
        message: `Stored procedure ${spName} not found in database ${meta.DbName || "(unknown)"} (login ${meta.LoginName || "(unknown)"}).`,
      });
    }

    await conn
      .request()
      .input("Recipients", sql.NVarChar(sql.MAX), recipients)
      .input("ccRecipients", sql.NVarChar(sql.MAX), ccRecipients || null)
      .input("ServerID", sql.Int, serverId)
      .input("MonthsBack", sql.Int, monthsBack)
      .execute(spName);

    return res.json({ ok: true });
  } catch (e) {
    console.error(e);
    const details = e?.originalError?.info?.message || e?.message || "Unknown error";
    return res.status(500).json({ message: `Failed to send email report: ${details}` });
  }
});

// Health check helpers
app.get("/api/health/prod-servers", authenticate, async (req, res) => {
  try {
    const conn = await getPool();
    const buId = String(req.query.buId || "").trim();
    const parsedBu = buId && /^\d+$/.test(buId) ? Number(buId) : null;

    const rs = await conn
      .request()
      .input("BUID", sql.Int, parsedBu)
      .query(`
        SELECT s.ServerID AS id, s.ServerName AS name
        FROM inventory.Server s
        INNER JOIN inventory.Environment env ON env.EnvID = s.EnvID
        INNER JOIN inventory.ServerStatus ss ON ss.StatusID = s.StatusID
        WHERE env.EnvName = 'PROD'
          AND ss.StatusName = 'IN USE'
          AND (@BUID IS NULL OR s.BUID = @BUID)
        ORDER BY s.ServerName;
      `);

    return res.json(rs.recordset || []);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ message: "Failed to load PROD servers" });
  }
});

app.get("/api/health/report", authenticate, async (req, res) => {
  try {
    const serverId = Number(req.query.serverId);
    if (!serverId) return res.status(400).json({ message: "serverId is required" });

    const conn = await getPool();

    const serverRs = await conn.request().input("ServerID", sql.Int, serverId).query(`
      SELECT s.ServerName, s.Description, bu.BusinessUnitName, env.EnvName
      FROM inventory.Server s
      INNER JOIN inventory.BusinessUnit bu ON bu.BUID = s.BUID
      INNER JOIN inventory.Environment env ON env.EnvID = s.EnvID
      WHERE s.ServerID = @ServerID;
    `);
    if (!serverRs.recordset.length) return res.status(404).json({ message: "Server not found" });

    const instRs = await conn.request().input("ServerID", sql.Int, serverId).query(`
      SELECT SQLInstanceID, InstanceName
      FROM inventory.SQLInstance
      WHERE ServerID = @ServerID AND ISNULL(IsActive, 1) = 1
      ORDER BY InstanceName;
    `);
    const instIds = (instRs.recordset || []).map((r) => r.SQLInstanceID).filter(Boolean);

    let backupSummary = [];
    let backupByDb = [];
    let jobs = [];

    if (instIds.length) {
      const idsCsv = instIds.join(",");

      // Summary counts (successful backups only; failures are reported as 0).
      const backupTableExists = await conn.request().query("SELECT OBJECT_ID('inventory.DatabaseBackup','U') AS oid;");
      const hasBackupTable = Boolean(backupTableExists.recordset?.[0]?.oid);
      const sumRs = hasBackupTable ? await conn.request().query(`
        SELECT BackupType, COUNT(1) AS Successful
        FROM inventory.DatabaseBackup
        WHERE BackupFinishDate >= DATEADD(hour, -24, SYSDATETIME())
          AND SQLInstanceID IN (${idsCsv})
        GROUP BY BackupType;
      `) : { recordset: [] };
      const byType = new Map((sumRs.recordset || []).map((r) => [String(r.BackupType), Number(r.Successful)]));
      const typeLabel = { D: "Full", I: "Differential", L: "Transaction Logs" };
      backupSummary = ["L", "I", "D"].map((t) => ({ BackupType: typeLabel[t] || t, Successful: byType.get(t) || 0, Failed: 0 }));

      // Per-DB latest full/diff backup finish timestamps (per instance).
      const byDbRs = hasBackupTable ? await conn.request().query(`
        WITH dbs AS (
          SELECT SQLInstanceID, DatabaseName
          FROM inventory.SQLDatabase
          WHERE IsActive = 1 AND SQLInstanceID IN (${idsCsv})
        ),
        fulls AS (
          SELECT SQLInstanceID, DatabaseName, MAX(BackupFinishDate) AS RecentFullBackupDate
          FROM inventory.DatabaseBackup
          WHERE BackupType = 'D' AND SQLInstanceID IN (${idsCsv})
          GROUP BY SQLInstanceID, DatabaseName
        ),
        diffs AS (
          SELECT SQLInstanceID, DatabaseName, MAX(BackupFinishDate) AS RecentDiffBackupDate
          FROM inventory.DatabaseBackup
          WHERE BackupType = 'I' AND SQLInstanceID IN (${idsCsv})
          GROUP BY SQLInstanceID, DatabaseName
        )
        SELECT
          si.InstanceName AS SQLInstanceName,
          dbs.DatabaseName,
          f.RecentFullBackupDate,
          d.RecentDiffBackupDate
        FROM dbs
        INNER JOIN inventory.SQLInstance si ON si.SQLInstanceID = dbs.SQLInstanceID
        LEFT JOIN fulls f ON f.SQLInstanceID = dbs.SQLInstanceID AND f.DatabaseName = dbs.DatabaseName
        LEFT JOIN diffs d ON d.SQLInstanceID = dbs.SQLInstanceID AND d.DatabaseName = dbs.DatabaseName
        ORDER BY si.InstanceName, dbs.DatabaseName;
      `) : { recordset: [] };
      backupByDb = byDbRs.recordset || [];

      // Job status (latest snapshot date available for these instances).
      const jobTableExists = await conn.request().query("SELECT OBJECT_ID('inventory.SQLMaintenanceJobRun','U') AS oid;");
      const hasJobTable = Boolean(jobTableExists.recordset?.[0]?.oid);
      const maxSnapRs = hasJobTable ? await conn.request().query(`
        SELECT MAX(SnapshotDate) AS MaxSnapshotDate
        FROM inventory.SQLMaintenanceJobRun
        WHERE SQLInstanceID IN (${idsCsv});
      `) : { recordset: [{ MaxSnapshotDate: null }] };
      const maxSnap = maxSnapRs.recordset?.[0]?.MaxSnapshotDate || null;
      if (maxSnap) {
        const jobRs = await conn.request().input("Snap", sql.Date, maxSnap).query(`
          SELECT
            si.InstanceName AS SQLInstanceName,
            j.JobName,
            j.LastRunDateTime,
            j.LastRunDurationSec,
            j.LastRunStatus,
            j.LastRunMessage
          FROM inventory.SQLMaintenanceJobRun j
          INNER JOIN inventory.SQLInstance si ON si.SQLInstanceID = j.SQLInstanceID
          WHERE j.SnapshotDate = @Snap
            AND j.SQLInstanceID IN (${idsCsv})
            AND j.LastRunDateTime IS NOT NULL
          ORDER BY si.InstanceName, j.JobName;
        `);
        jobs = jobRs.recordset || [];
      }
    }

    // Disk space (latest active storage rows in ServerStorage)
    const diskRs = await conn.request().input("ServerID", sql.Int, serverId).query(`
      SELECT
        DriveLetter,
        VolumeLabel,
        TotalSizeGB,
        FreeSpaceGB,
        CASE WHEN TotalSizeGB > 0 THEN CAST((FreeSpaceGB * 100.0) / TotalSizeGB AS decimal(5,2)) ELSE NULL END AS FreePct
      FROM inventory.ServerStorage
      WHERE ServerID = @ServerID AND IsActive = 1
      ORDER BY DriveLetter;
    `);

    return res.json({
      server: serverRs.recordset[0],
      sqlInstances: instRs.recordset || [],
      backupSummary,
      backupByDb,
      disk: diskRs.recordset || [],
      jobs,
    });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ message: "Failed to load health report" });
  }
});


app.post("/api/health/email-report", authenticate, async (req, res) => {
  try {
    const serverId = Number(req.body?.serverId);
    const recipients = String(req.body?.recipients || "").trim();
    const ccRecipients = String(req.body?.ccRecipients || "").trim();

    if (!serverId) return res.status(400).json({ message: "serverId is required" });
    if (!recipients) return res.status(400).json({ message: "recipients is required" });

    const conn = await getPool();

    // ProfileName is defaulted inside the stored procedure.

    // Helpful diagnostics if the SP is missing or we are connected to the wrong DB.
    const metaRs = await conn.request().query("SELECT DB_NAME() AS DbName, SUSER_SNAME() AS LoginName;");
    const meta = metaRs.recordset?.[0] || {};
    const spRs = await conn.request().query("SELECT OBJECT_ID('inventory.usp_Email_HealthReport_Server','P') AS oid;");
    const hasSp = Boolean(spRs.recordset?.[0]?.oid);
    if (!hasSp) {
      return res.status(500).json({
        message: `Stored procedure inventory.usp_Email_HealthReport_Server not found in database ${meta.DbName || '(unknown)'} (login ${meta.LoginName || '(unknown)'}).`,
      });
    }

    await conn
      .request()

      .input("Recipients", sql.NVarChar(sql.MAX), recipients)
      .input("ccRecipients", sql.NVarChar(sql.MAX), ccRecipients || null)
      .input("ServerID", sql.Int, serverId)
      .execute("inventory.usp_Email_HealthReport_Server");

    return res.json({ ok: true });
  } catch (e) {
    console.error(e);
    const details = e?.originalError?.info?.message || e?.message || "Unknown error";
    return res.status(500).json({ message: `Failed to send email report: ${details}` });
  }
});
app.get("/api/dashboard/summary", authenticate, async (req, res) => {
  try {
    const conn = await getPool();
    let selectedBUID = null;
    const buParam = String(req.query.bu || "").trim();

    if (buParam) {
      if (/^\d+$/.test(buParam)) {
        selectedBUID = Number(buParam);
      } else {
        const buLookup = await conn.request().input("BusinessUnitName", sql.VarChar(100), buParam).query(`
          SELECT TOP 1 BUID FROM inventory.BusinessUnit WHERE BusinessUnitName = @BusinessUnitName;
        `);
        if (buLookup.recordset.length) selectedBUID = buLookup.recordset[0].BUID;
      }
    }

    const queries = {
      totalServers: "SELECT COUNT(1) AS total FROM inventory.Server;",
      totalSqlInstancesFiltered: `
        SELECT COUNT(1) AS total
        FROM inventory.SQLInstance si
        INNER JOIN inventory.Server s ON s.ServerID = si.ServerID
        INNER JOIN inventory.ServerStatus ss ON ss.StatusID = s.StatusID
        WHERE ISNULL(si.IsActive, 1) = 1
          AND ss.StatusName = 'IN USE'
          AND (@BUID IS NULL OR s.BUID = @BUID);
      `,
      byPlatform: `
        SELECT p.PlatformName AS label, COUNT(1) AS value
        FROM inventory.Server s
        INNER JOIN inventory.ServerStatus ss ON ss.StatusID = s.StatusID
        INNER JOIN inventory.ServerHardware sh ON sh.ServerID = s.ServerID AND sh.IsCurrent = 1
        INNER JOIN inventory.Platform p ON p.PlatformID = sh.PlatformID
        WHERE ss.StatusName = 'IN USE' AND (@BUID IS NULL OR s.BUID = @BUID)
        GROUP BY p.PlatformName
        ORDER BY value DESC;
      `,
      byLocation: `
        SELECT r.RegionName AS label, COUNT(1) AS value
        FROM inventory.Server s
        INNER JOIN inventory.Region r ON r.RegionID = s.RegionID
        INNER JOIN inventory.ServerStatus ss ON ss.StatusID = s.StatusID
        WHERE ss.StatusName = 'IN USE' AND (@BUID IS NULL OR s.BUID = @BUID)
        GROUP BY r.RegionName
        ORDER BY value DESC;
      `,
      byCategory: `
        SELECT c.CategoryName AS label, COUNT(1) AS value
        FROM inventory.Server s
        INNER JOIN inventory.ServerCategory c ON c.CategoryID = s.CategoryID
        INNER JOIN inventory.ServerStatus ss ON ss.StatusID = s.StatusID
        WHERE ss.StatusName = 'IN USE' AND (@BUID IS NULL OR s.BUID = @BUID)
        GROUP BY c.CategoryName
        ORDER BY value DESC;
      `,
      byOSType: `
        SELECT os.OSCategory AS label, COUNT(1) AS value
        FROM inventory.Server s
        INNER JOIN inventory.ServerStatus ss ON ss.StatusID = s.StatusID
        INNER JOIN inventory.ServerHardware sh ON sh.ServerID = s.ServerID AND sh.IsCurrent = 1
        INNER JOIN inventory.OSType os ON os.OSID = sh.OperatingSystemID
        WHERE ss.StatusName = 'IN USE' AND (@BUID IS NULL OR s.BUID = @BUID)
        GROUP BY os.OSCategory
        ORDER BY value DESC;
      `,
      byServerType: `
        SELECT st.ServerType AS label, COUNT(1) AS value
        FROM inventory.Server s
        INNER JOIN inventory.ServerStatus ss ON ss.StatusID = s.StatusID
        INNER JOIN inventory.ServerHardware sh ON sh.ServerID = s.ServerID AND sh.IsCurrent = 1
        INNER JOIN inventory.ServerType st ON st.ServerTypeID = sh.ServerTypeID
        WHERE ss.StatusName = 'IN USE' AND (@BUID IS NULL OR s.BUID = @BUID)
        GROUP BY st.ServerType
        ORDER BY value DESC;
      `,
      byEnvironment: `
        SELECT e.EnvName AS label, COUNT(1) AS value
        FROM inventory.Server s
        INNER JOIN inventory.ServerStatus ss ON ss.StatusID = s.StatusID
        INNER JOIN inventory.Environment e ON e.EnvID = s.EnvID
        WHERE ss.StatusName = 'IN USE' AND (@BUID IS NULL OR s.BUID = @BUID)
        GROUP BY e.EnvName
        ORDER BY value DESC;
      `,
      byBusinessUnit: `
        SELECT bu.BUID AS id, bu.BusinessUnitName AS label, COUNT(1) AS value
        FROM inventory.Server s
        INNER JOIN inventory.ServerStatus ss ON ss.StatusID = s.StatusID
        INNER JOIN inventory.BusinessUnit bu ON bu.BUID = s.BUID
        WHERE ss.StatusName = 'IN USE'
        GROUP BY bu.BUID, bu.BusinessUnitName
        ORDER BY value DESC;
      `,
      bySQLVersion: `
        SELECT v.SQLVersionName AS label, COUNT(1) AS value
        FROM inventory.SQLInstance si
        INNER JOIN inventory.Server s ON s.ServerID = si.ServerID
        INNER JOIN inventory.ServerStatus ss ON ss.StatusID = s.StatusID
        INNER JOIN inventory.SQLInstanceVersion iv ON iv.SQLInstanceID = si.SQLInstanceID AND iv.IsCurrent = 1
        INNER JOIN inventory.SQLVersion v ON v.SQLVersionID = iv.SQLVersionID
        WHERE ISNULL(si.IsActive, 1) = 1
          AND ss.StatusName = 'IN USE'
          AND (@BUID IS NULL OR s.BUID = @BUID)
        GROUP BY v.SQLVersionName
        ORDER BY value DESC;
      `,
      bySQLEdition: `
        SELECT ed.SQLEditionName AS label, COUNT(1) AS value
        FROM inventory.SQLInstance si
        INNER JOIN inventory.Server s ON s.ServerID = si.ServerID
        INNER JOIN inventory.ServerStatus ss ON ss.StatusID = s.StatusID
        INNER JOIN inventory.SQLInstanceVersion iv ON iv.SQLInstanceID = si.SQLInstanceID AND iv.IsCurrent = 1
        INNER JOIN inventory.SQLEdition ed ON ed.SQLEditionID = iv.SQLEditionID
        WHERE ISNULL(si.IsActive, 1) = 1
          AND ss.StatusName = 'IN USE'
          AND (@BUID IS NULL OR s.BUID = @BUID)
        GROUP BY ed.SQLEditionName
        ORDER BY value DESC;
      `,
      byInstanceType: `
        SELECT it.InstanceTypeName AS label, COUNT(1) AS value
        FROM inventory.SQLInstance si
        INNER JOIN inventory.Server s ON s.ServerID = si.ServerID
        INNER JOIN inventory.ServerStatus ss ON ss.StatusID = s.StatusID
        INNER JOIN inventory.SQLInstanceType it ON it.InstanceTypeID = si.InstanceTypeID
        WHERE ISNULL(si.IsActive, 1) = 1
          AND ss.StatusName = 'IN USE'
          AND (@BUID IS NULL OR s.BUID = @BUID)
        GROUP BY it.InstanceTypeName
        ORDER BY value DESC;
      `,
      recentServers: `
        SELECT TOP 10
          s.ServerName,
          s.CreatedDate,
          s.ModifiedDate,
          bu.BusinessUnitName,
          e.EnvName,
          r.RegionName
        FROM inventory.Server s
        INNER JOIN inventory.BusinessUnit bu ON bu.BUID = s.BUID
        INNER JOIN inventory.Environment e ON e.EnvID = s.EnvID
        INNER JOIN inventory.Region r ON r.RegionID = s.RegionID
        INNER JOIN inventory.ServerStatus ss ON ss.StatusID = s.StatusID
        WHERE ISNULL(s.ModifiedDate, s.CreatedDate) >= DATEADD(MONTH, -1, CONVERT(date, GETDATE()))
          AND ss.StatusName = 'IN USE'
          AND (@BUID IS NULL OR s.BUID = @BUID)
        ORDER BY ISNULL(s.ModifiedDate, s.CreatedDate) DESC;
      `,
      totalServersFiltered: `
        SELECT COUNT(1) AS total
        FROM inventory.Server s
        INNER JOIN inventory.ServerStatus ss ON ss.StatusID = s.StatusID
        WHERE ss.StatusName = 'IN USE' AND (@BUID IS NULL OR s.BUID = @BUID);
      `,
      toBeCommissioned: `
        SELECT TOP 50
          s.ServerName,
          s.CreatedDate,
          s.ModifiedDate,
          bu.BusinessUnitName,
          e.EnvName,
          r.RegionName
        FROM inventory.Server s
        INNER JOIN inventory.BusinessUnit bu ON bu.BUID = s.BUID
        INNER JOIN inventory.Environment e ON e.EnvID = s.EnvID
        INNER JOIN inventory.Region r ON r.RegionID = s.RegionID
        INNER JOIN inventory.ServerStatus ss ON ss.StatusID = s.StatusID
        WHERE ss.StatusName = 'TO BE COMMISSIONED'
          AND (@BUID IS NULL OR s.BUID = @BUID)
        ORDER BY ISNULL(s.ModifiedDate, s.CreatedDate) DESC;
      `,
      decommissionedLast3Months: `
        SELECT TOP 50
          s.ServerName,
          s.CreatedDate,
          s.ModifiedDate,
          bu.BusinessUnitName,
          e.EnvName,
          r.RegionName
        FROM inventory.Server s
        INNER JOIN inventory.BusinessUnit bu ON bu.BUID = s.BUID
        INNER JOIN inventory.Environment e ON e.EnvID = s.EnvID
        INNER JOIN inventory.Region r ON r.RegionID = s.RegionID
        INNER JOIN inventory.ServerStatus ss ON ss.StatusID = s.StatusID
        WHERE ss.StatusName = 'DECOMMISSIONED'
          AND ISNULL(s.ModifiedDate, s.CreatedDate) >= DATEADD(MONTH, -3, CONVERT(date, GETDATE()))
          AND (@BUID IS NULL OR s.BUID = @BUID)
        ORDER BY ISNULL(s.ModifiedDate, s.CreatedDate) DESC;
      `,
    };

    const result = {};
    for (const [k, q] of Object.entries(queries)) {
      const request = conn.request().input("BUID", sql.Int, selectedBUID);
      const rs = await request.query(q);
      result[k] = rs.recordset;
    }

    res.json({
      totalServers: result.totalServersFiltered[0]?.total || 0,
      totalSqlInstances: result.totalSqlInstancesFiltered[0]?.total || 0,
      selectedBUID,
      byPlatform: result.byPlatform,
      byLocation: result.byLocation,
      byCategory: result.byCategory,
      byOSType: result.byOSType,
      byServerType: result.byServerType,
      byEnvironment: result.byEnvironment,
      byBusinessUnit: result.byBusinessUnit,
      bySQLVersion: result.bySQLVersion,
      bySQLEdition: result.bySQLEdition,
      byInstanceType: result.byInstanceType,
      recentServers: result.recentServers,
      toBeCommissioned: result.toBeCommissioned,
      decommissionedLast3Months: result.decommissionedLast3Months,
    });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Failed to load dashboard summary" });
  }
});

app.get("/api/server-search", authenticate, async (req, res) => {
  try {
    const term = String(req.query.name || "").trim();
    if (!term) return res.status(400).json({ message: "Query parameter 'name' is required" });

    const conn = await getPool();
    const serverRs = await conn.request().input("Search", sql.VarChar(200), `%${term}%`).query(`
      SELECT TOP 25 ServerID, ServerName
      FROM inventory.Server
      WHERE ServerName LIKE @Search
      ORDER BY ServerName;
    `);

    const results = [];
    for (const row of serverRs.recordset) {
      const details = await getServerForEdit(row.ServerID);
      if (details) results.push(details);
    }

    return res.json({ count: results.length, results });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ message: "Failed to search server" });
  }
});

// Read-only friendly server details view (joined with lookup names).
app.get("/api/server-details/:serverId", authenticate, async (req, res) => {
  try {
    const serverId = Number(req.params.serverId);
    if (!serverId) return res.status(400).json({ message: "Invalid serverId" });

    const conn = await getPool();

    const base = await conn.request().input("ServerID", sql.Int, serverId).query(`
      SELECT
        s.ServerID,
        s.ServerName,
        s.Description,
        bu.BUID,
        bu.BusinessUnitName,
        env.EnvName,
        reg.RegionName,
        cat.CategoryName,
        ss.StatusName,
        sh.EffectiveDate AS ServerEffectiveFrom,
        sh.OSInstallDate,
        sh.MemoryGB,
        sh.CPUCores,
        sh.ProcessorModel,
        os.OperatingSystem,
        os.OSCategory,
        st.ServerType,
        p.PlatformName,
        d.DomainName,
        tz.Timezone
      FROM inventory.Server s
      INNER JOIN inventory.BusinessUnit bu ON bu.BUID = s.BUID
      INNER JOIN inventory.Environment env ON env.EnvID = s.EnvID
      INNER JOIN inventory.Region reg ON reg.RegionID = s.RegionID
      INNER JOIN inventory.ServerCategory cat ON cat.CategoryID = s.CategoryID
      INNER JOIN inventory.ServerStatus ss ON ss.StatusID = s.StatusID
      INNER JOIN inventory.ServerHardware sh ON sh.ServerID = s.ServerID AND sh.IsCurrent = 1
      INNER JOIN inventory.OSType os ON os.OSID = sh.OperatingSystemID
      INNER JOIN inventory.ServerType st ON st.ServerTypeID = sh.ServerTypeID
      INNER JOIN inventory.Platform p ON p.PlatformID = sh.PlatformID
      LEFT JOIN inventory.Domain d ON d.DomainID = sh.DomainID
      LEFT JOIN inventory.Timezone tz ON tz.TimezoneID = sh.TimezoneID
      WHERE s.ServerID = @ServerID;
    `);

    if (!base.recordset.length) return res.status(404).json({ message: "Server not found" });

    const network = await conn.request().input("ServerID", sql.Int, serverId).query(`
      SELECT ip.IPAddress, t.TypeName
      FROM inventory.ServerIP ip
      INNER JOIN inventory.IPAddressType t ON t.IPAddressTypeID = ip.IPAddressTypeID
      WHERE ip.ServerID = @ServerID AND ip.IsActive = 1
      ORDER BY t.TypeName, ip.IPAddress;
    `);

    const storage = await conn.request().input("ServerID", sql.Int, serverId).query(`
      SELECT
        DriveLetter,
        VolumeLabel,
        TotalSizeGB,
        FreeSpaceGB,
        CASE WHEN TotalSizeGB > 0 THEN CAST((FreeSpaceGB * 100.0) / TotalSizeGB AS decimal(5,2)) ELSE NULL END AS FreeSpacePct
      FROM inventory.ServerStorage
      WHERE ServerID = @ServerID AND IsActive = 1
      ORDER BY DriveLetter;
    `);

    const sqlInst = await conn.request().input("ServerID", sql.Int, serverId).query(`
      SELECT
        si.SQLInstanceID,
        si.InstanceName,
        si.SQLInstallDate,
        it.InstanceTypeName,
        v.SQLVersionName,
        ed.SQLEditionName,
        iv.ProductBuild,
        iv.ProductLevel,
        iv.EffectiveDate AS VersionEffectiveDate,
        col.InstanceCollationName,
        ic.MinMemoryMB,
        ic.MaxMemoryMB,
        ic.MaxDOP,
        ic.CostThresholdParallelism,
        ic.AdhocWorkload,
        ic.LockPageInMemory,
        ic.IFI,
        ic.DatabaseMail,
        ic.FileStream,
        ic.EffectiveDate AS ConfigEffectiveDate
      FROM inventory.SQLInstance si
      INNER JOIN inventory.SQLInstanceType it ON it.InstanceTypeID = si.InstanceTypeID
      OUTER APPLY (
        SELECT TOP 1 SQLVersionID, SQLEditionID, ProductBuild, ProductLevel, EffectiveDate
        FROM inventory.SQLInstanceVersion
        WHERE SQLInstanceID = si.SQLInstanceID AND IsCurrent = 1
        ORDER BY SQLInstanceVersionID DESC
      ) iv
      LEFT JOIN inventory.SQLVersion v ON v.SQLVersionID = iv.SQLVersionID
      LEFT JOIN inventory.SQLEdition ed ON ed.SQLEditionID = iv.SQLEditionID
      OUTER APPLY (
        SELECT TOP 1 InstanceCollationID, MinMemoryMB, MaxMemoryMB, MaxDOP, CostThresholdParallelism, AdhocWorkload, LockPageInMemory, IFI, DatabaseMail, FileStream, EffectiveDate
        FROM inventory.SQLInstanceConfig
        WHERE SQLInstanceID = si.SQLInstanceID AND IsCurrent = 1
        ORDER BY SQLInstanceConfigID DESC
      ) ic
      LEFT JOIN inventory.SQLInstanceCollation col ON col.InstanceCollationID = ic.InstanceCollationID
      WHERE si.ServerID = @ServerID AND ISNULL(si.IsActive, 1) = 1
      ORDER BY si.InstanceName;
    `);

    // Attach database summary per instance (limited fields for detail page).
    let instances = sqlInst.recordset || [];
    const instIds = instances.map((x) => x.SQLInstanceID).filter(Boolean);
    if (instIds.length) {
      const dbRs = await conn.request().query(`
        SELECT SQLInstanceID, DatabaseName, SizeGB, RecoveryModel
        FROM inventory.SQLDatabase
        WHERE IsActive = 1 AND SQLInstanceID IN (${instIds.join(",")})
        ORDER BY SQLInstanceID, DatabaseName;
      `);
      const dbMap = new Map();
      for (const r of dbRs.recordset || []) {
        if (!dbMap.has(r.SQLInstanceID)) dbMap.set(r.SQLInstanceID, []);
        dbMap.get(r.SQLInstanceID).push(r);
      }
      instances = instances.map((inst) => ({ ...inst, Databases: dbMap.get(inst.SQLInstanceID) || [] }));
    } else {
      instances = instances.map((inst) => ({ ...inst, Databases: [] }));
    }

    const serverContacts = await conn.request().input("ServerID", sql.Int, serverId).query(`
      SELECT
        cc.ContactCategoryName,
        c.ContactName,
        c.Email,
        c.Phone
      FROM inventory.ServerContact sc
      INNER JOIN inventory.ContactCategory cc ON cc.ContactCategoryID = sc.ContactCategoryID
      INNER JOIN inventory.Contact c ON c.ContactID = sc.ContactID
      WHERE sc.ServerID = @ServerID
      ORDER BY cc.ContactCategoryName, c.ContactName;
    `);

    let contactSource = "server";
    let supportContacts = serverContacts.recordset || [];
    if (!supportContacts.length) {
      const buContacts = await conn.request().input("ServerID", sql.Int, serverId).query(`
        SELECT
          cc.ContactCategoryName,
          c.ContactName,
          c.Email,
          c.Phone
        FROM inventory.Server s
        INNER JOIN inventory.BusinessUnitContact buc ON buc.BUID = s.BUID
        INNER JOIN inventory.ContactCategory cc ON cc.ContactCategoryID = buc.ContactCategoryID
        INNER JOIN inventory.Contact c ON c.ContactID = buc.ContactID
        WHERE s.ServerID = @ServerID
        ORDER BY cc.ContactCategoryName, c.ContactName;
      `);
      contactSource = "bu";
      supportContacts = buContacts.recordset || [];
    }

    const primary = instances.find((x) => String(x.InstanceName || "").toUpperCase() === "MSSQLSERVER") || instances[0] || null;

    const otherDetails = {
      serverEffectiveFrom: base.recordset[0].ServerEffectiveFrom || null,
      osInstallDate: base.recordset[0].OSInstallDate || null,
      sqlInstallDate: primary ? primary.SQLInstallDate || null : null,
      recentPatchAppliedOn: primary ? primary.VersionEffectiveDate || null : null,
    };

    return res.json({
      serverName: base.recordset[0].ServerName,
      osDetails: base.recordset[0],
      networkDetails: network.recordset,
      sqlInstanceDetails: instances,
      storageDetails: storage.recordset,
      supportContacts,
      contactSource,
      otherDetails,
    });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ message: "Failed to load server details" });
  }
});

app.get("/api/inventory/:serverId", authenticate, requireAdmin, async (req, res) => {
  try {
    const serverId = Number(req.params.serverId);
    const data = await getServerForEdit(serverId);
    if (!data) return res.status(404).json({ message: "Server not found" });
    res.json(data);
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Failed to load server details" });
  }
});

app.post("/api/inventory", authenticate, requireAdmin, async (req, res) => {
  const payload = req.body;
  const errors = validatePayload(payload);
  if (errors.length) return res.status(400).json({ message: "Validation failed", errors });

  const tx = new sql.Transaction(await getPool());
  await tx.begin();

  try {
    const { server, serverHardware, sqlInstances, serverIPs, serverStorages, contacts } = payload;
    const contactMode = String(payload.contactMode || "bu").toLowerCase();
    const createdBy = req.user?.username || server.createdBy;

    const serverInsert = await new sql.Request(tx)
      .input("ServerName", sql.VarChar(150), server.serverName)
      .input("Description", sql.VarChar(255), server.description || null)
      .input("EnvID", sql.Int, Number(server.envId))
      .input("BUID", sql.Int, Number(server.buId))
      .input("CategoryID", sql.Int, Number(server.categoryId))
      .input("RegionID", sql.Int, Number(server.regionId))
      .input("StatusID", sql.Int, Number(server.statusId))
      .input("CreatedBy", sql.VarChar(100), createdBy)
      .query(`
        INSERT INTO inventory.Server (ServerName, Description, EnvID, BUID, CategoryID, RegionID, StatusID, CreatedBy)
        OUTPUT INSERTED.ServerID
        VALUES (@ServerName, @Description, @EnvID, @BUID, @CategoryID, @RegionID, @StatusID, @CreatedBy);
      `);
    const serverId = serverInsert.recordset[0].ServerID;

    await new sql.Request(tx)
      .input("ServerID", sql.Int, serverId)
      .input("DomainID", sql.Int, Number(serverHardware.domainId))
      .input("OperatingSystemID", sql.Int, Number(serverHardware.operatingSystemId))
      .input("MemoryGB", sql.Int, Number(serverHardware.memoryGB))
      .input("CPUCores", sql.Int, Number(serverHardware.cpuCores))
      .input("ProcessorModel", sql.VarChar(150), serverHardware.processorModel || null)
      .input("ServerTypeID", sql.Int, Number(serverHardware.serverTypeId))
      .input("PlatformID", sql.Int, Number(serverHardware.platformId))
      .input("TimezoneID", sql.Int, Number(serverHardware.timezoneId))
      .input("OSInstallDate", sql.Date, serverHardware.osInstallDate || null)
      .input("CreatedBy", sql.VarChar(100), createdBy)
      .input("EffectiveDate", sql.Date, serverHardware.effectiveDate || null)
      .query(`
        INSERT INTO inventory.ServerHardware
        (ServerID, DomainID, OperatingSystemID, MemoryGB, CPUCores, ProcessorModel, ServerTypeID, PlatformID, TimezoneID, OSInstallDate, IsCurrent, EffectiveDate, CreatedBy)
        VALUES (@ServerID, @DomainID, @OperatingSystemID, @MemoryGB, @CPUCores, @ProcessorModel, @ServerTypeID, @PlatformID, @TimezoneID, @OSInstallDate, 1, COALESCE(@EffectiveDate, CONVERT(date, SYSDATETIME())), @CreatedBy);
      `);

    const sqlInstanceIds = [];
    for (const inst of sqlInstances) {
      const instanceInsert = await new sql.Request(tx)
        .input("ServerID", sql.Int, serverId)
        .input("InstanceName", sql.VarChar(150), inst.instanceName)
        .input("InstanceTypeID", sql.Int, Number(inst.instanceTypeId))
        .input("SQLInstallDate", sql.Date, inst.sqlInstallDate || null)
        .input("CreatedBy", sql.VarChar(100), createdBy)
        .query(`
          INSERT INTO inventory.SQLInstance (ServerID, InstanceName, InstanceTypeID, SQLInstallDate, CreatedBy, IsActive)
          OUTPUT INSERTED.SQLInstanceID
          VALUES (@ServerID, @InstanceName, @InstanceTypeID, @SQLInstallDate, @CreatedBy, 1);
        `);
      const sqlInstanceId = instanceInsert.recordset[0].SQLInstanceID;
      sqlInstanceIds.push(sqlInstanceId);

      await new sql.Request(tx)
        .input("SQLInstanceID", sql.Int, sqlInstanceId)
        .input("SQLVersionID", sql.Int, Number(inst.sqlVersionId))
        .input("SQLEditionID", sql.Int, Number(inst.sqlEditionId))
        .input("ProductBuild", sql.VarChar(50), inst.productBuild)
        .input("ProductLevel", sql.VarChar(50), inst.productLevel)
        .input("EffectiveDate", sql.Date, inst.versionEffectiveDate || null)
        .query(`
          INSERT INTO inventory.SQLInstanceVersion
          (SQLInstanceID, SQLVersionID, SQLEditionID, ProductBuild, ProductLevel, IsCurrent, EffectiveDate)
          VALUES (@SQLInstanceID, @SQLVersionID, @SQLEditionID, @ProductBuild, @ProductLevel, 1, COALESCE(@EffectiveDate, CONVERT(date, SYSDATETIME())));
        `);

      await new sql.Request(tx)
        .input("SQLInstanceID", sql.Int, sqlInstanceId)
        .input("InstanceCollationID", sql.Int, Number(inst.instanceCollationId))
        .input("MinMemoryMB", sql.Int, inst.minMemoryMB ?? null)
        .input("MaxMemoryMB", sql.Int, inst.maxMemoryMB ?? null)
        .input("MaxDOP", sql.Int, inst.maxDOP ?? null)
        .input("CostThresholdParallelism", sql.Int, inst.costThresholdParallelism ?? null)
        .input("AdhocWorkload", sql.Bit, inst.adhocWorkload ? 1 : 0)
        .input("LockPageInMemory", sql.Bit, inst.lockPageInMemory ? 1 : 0)
        .input("IFI", sql.Bit, inst.ifi ? 1 : 0)
        .input("DatabaseMail", sql.Bit, inst.databaseMail ? 1 : 0)
        .input("FileStream", sql.Bit, inst.fileStream ? 1 : 0)
        .input("EffectiveDate", sql.Date, inst.configEffectiveDate || null)
        .query(`
          INSERT INTO inventory.SQLInstanceConfig
          (SQLInstanceID, InstanceCollationID, MinMemoryMB, MaxMemoryMB, MaxDOP, CostThresholdParallelism, AdhocWorkload, LockPageInMemory, IFI, DatabaseMail, FileStream, IsCurrent, EffectiveDate)
          VALUES (@SQLInstanceID, @InstanceCollationID, @MinMemoryMB, @MaxMemoryMB, @MaxDOP, @CostThresholdParallelism, @AdhocWorkload, @LockPageInMemory, @IFI, @DatabaseMail, @FileStream, 1, COALESCE(@EffectiveDate, CONVERT(date, SYSDATETIME())));
        `);

      // Databases (optional, per instance)
      for (const db of inst.databases || []) {
        if (!db || !required(db.databaseName)) continue;
        await new sql.Request(tx)
          .input("SQLInstanceID", sql.Int, sqlInstanceId)
          .input("DatabaseName", sql.VarChar(256), db.databaseName)
          .input("Owner", sql.VarChar(128), db.owner || null)
          .input("SizeGB", sql.Decimal(18, 2), db.sizeGB === null || db.sizeGB === undefined || db.sizeGB === "" ? null : Number(db.sizeGB))
          .input("CreatedOn", sql.DateTime2, db.createdOn || null)
          .input("RecoveryModel", sql.VarChar(30), db.recoveryModel || null)
          .input("DatabaseCollation", sql.VarChar(128), db.databaseCollation || null)
          .input("CDC", sql.Bit, db.cdc ? 1 : 0)
          .input("CompatibilityLevel", sql.Int, db.compatibilityLevel === null || db.compatibilityLevel === undefined || db.compatibilityLevel === "" ? null : Number(db.compatibilityLevel))
          .input("Encryption", sql.Bit, db.encryption ? 1 : 0)
          .input("QueryStore", sql.Bit, db.queryStore ? 1 : 0)
          .input("AutoUpdateStats", sql.Bit, db.autoUpdateStats === false ? 0 : 1)
          .input("IsActive", sql.Bit, db.isActive === false ? 0 : 1)
          .input("CreatedBy", sql.VarChar(100), createdBy)
          .query(`
            INSERT INTO inventory.SQLDatabase
            (SQLInstanceID, DatabaseName, Owner, SizeGB, CreatedOn, RecoveryModel, DatabaseCollation, CDC, CompatibilityLevel, Encryption, QueryStore, AutoUpdateStats, IsActive, CreatedBy)
            VALUES
            (@SQLInstanceID, @DatabaseName, @Owner, @SizeGB, @CreatedOn, @RecoveryModel, @DatabaseCollation, @CDC, @CompatibilityLevel, @Encryption, @QueryStore, @AutoUpdateStats, @IsActive, @CreatedBy);
          `);
      }
    }

    for (const ip of serverIPs) {
      await new sql.Request(tx)
        .input("ServerID", sql.Int, serverId)
        .input("IPAddress", sql.VarChar(50), ip.ipAddress)
        .input("IPAddressTypeID", sql.Int, Number(ip.ipAddressTypeId))
        .input("IsActive", sql.Bit, ip.isActive === false ? 0 : 1)
        .query("INSERT INTO inventory.ServerIP (ServerID, IPAddress, IPAddressTypeID, IsActive) VALUES (@ServerID, @IPAddress, @IPAddressTypeID, @IsActive);");
    }

    for (const s of serverStorages) {
      await new sql.Request(tx)
        .input("ServerID", sql.Int, serverId)
        .input("DriveLetter", sql.Char(1), s.driveLetter)
        .input("VolumeLabel", sql.VarChar(100), s.volumeLabel || null)
        .input("TotalSizeGB", sql.Decimal(18, 2), Number(s.totalSizeGB))
        .input("FreeSpaceGB", sql.Decimal(18, 2), Number(s.freeSpaceGB))
        .input("IsActive", sql.Bit, s.isActive === false ? 0 : 1)
        .query("INSERT INTO inventory.ServerStorage (ServerID, DriveLetter, VolumeLabel, TotalSizeGB, FreeSpaceGB, IsActive) VALUES (@ServerID, @DriveLetter, @VolumeLabel, @TotalSizeGB, @FreeSpaceGB, @IsActive);");
    }

    // Server contacts:
    // - custom: store mappings in inventory.ServerContact
    // - bu: do not store server mappings (server will display BU defaults as fallback)
    if (contactMode === "custom") {
      for (const c of contacts || []) {
        if (!c || (!c.contactName && !c.email && !c.phone) || !c.contactCategoryId) continue;

        let contactId;
        if (c.email) {
          const existing = await new sql.Request(tx).input("Email", sql.VarChar(150), c.email).query("SELECT ContactID FROM inventory.Contact WHERE Email = @Email;");
          if (existing.recordset.length) contactId = existing.recordset[0].ContactID;
        }
        if (!contactId) {
          const inserted = await new sql.Request(tx)
            .input("ContactName", sql.VarChar(150), c.contactName)
            .input("Email", sql.VarChar(150), c.email || null)
            .input("Phone", sql.VarChar(50), c.phone || null)
            .query("INSERT INTO inventory.Contact (ContactName, Email, Phone) OUTPUT INSERTED.ContactID VALUES (@ContactName, @Email, @Phone);");
          contactId = inserted.recordset[0].ContactID;
        }

        await new sql.Request(tx)
          .input("ServerID", sql.Int, serverId)
          .input("ContactID", sql.Int, contactId)
          .input("ContactCategoryID", sql.Int, Number(c.contactCategoryId))
          .input("CreatedBy", sql.VarChar(100), createdBy)
          .query(`
            IF NOT EXISTS (
              SELECT 1 FROM inventory.ServerContact
              WHERE ServerID = @ServerID AND ContactID = @ContactID AND ContactCategoryID = @ContactCategoryID
            )
              INSERT INTO inventory.ServerContact (ServerID, ContactID, ContactCategoryID, CreatedBy)
              VALUES (@ServerID, @ContactID, @ContactCategoryID, @CreatedBy);
          `);
      }
    }

    await tx.commit();
    res.status(201).json({ message: "Inventory saved successfully", ids: { serverId, sqlInstanceIds } });
  } catch (e) {
    if (!tx._aborted) await tx.rollback();
    console.error(e);
    res.status(500).json({ message: "Failed to save inventory", error: e.originalError?.info?.message || e.message });
  }
});

app.put("/api/inventory/:serverId", authenticate, requireAdmin, async (req, res) => {
  const serverId = Number(req.params.serverId);
  const payload = req.body;
  const errors = validatePayload(payload);
  if (errors.length) return res.status(400).json({ message: "Validation failed", errors });

  const existing = await getServerForEdit(serverId);
  if (!existing) return res.status(404).json({ message: "Server not found" });

  const tx = new sql.Transaction(await getPool());
  await tx.begin();

  try {
    const { server, serverHardware, sqlInstances, serverIPs, serverStorages, contacts } = payload;
    const contactMode = String(payload.contactMode || "bu").toLowerCase();
    const changedBy = req.user?.username || server.createdBy;

    await new sql.Request(tx)
      .input("ServerID", sql.Int, serverId)
      .input("ServerName", sql.VarChar(150), server.serverName)
      .input("Description", sql.VarChar(255), server.description || null)
      .input("EnvID", sql.Int, Number(server.envId))
      .input("BUID", sql.Int, Number(server.buId))
      .input("CategoryID", sql.Int, Number(server.categoryId))
      .input("RegionID", sql.Int, Number(server.regionId))
      .input("StatusID", sql.Int, Number(server.statusId))
      .input("ModifiedBy", sql.VarChar(100), changedBy)
      .query(`
        UPDATE inventory.Server
        SET ServerName=@ServerName, Description=@Description, EnvID=@EnvID, BUID=@BUID, CategoryID=@CategoryID, RegionID=@RegionID, StatusID=@StatusID,
            ModifiedDate=SYSDATETIME(), ModifiedBy=@ModifiedBy
        WHERE ServerID=@ServerID;
      `);

    const serverFieldMap = [
      ["ServerName", existing.server.ServerName, server.serverName],
      ["Description", existing.server.Description, server.description || null],
      ["EnvID", existing.server.EnvID, Number(server.envId)],
      ["BUID", existing.server.BUID, Number(server.buId)],
      ["CategoryID", existing.server.CategoryID, Number(server.categoryId)],
      ["RegionID", existing.server.RegionID, Number(server.regionId)],
      ["StatusID", existing.server.StatusID, Number(server.statusId)],
    ];
    for (const [f, oldV, newV] of serverFieldMap) await logChange(tx, "Server", serverId, f, oldV, newV, changedBy);

    await new sql.Request(tx).input("ServerID", sql.Int, serverId).query("UPDATE inventory.ServerHardware SET IsCurrent = 0 WHERE ServerID=@ServerID AND IsCurrent=1;");
    const hwIns = await new sql.Request(tx)
      .input("ServerID", sql.Int, serverId)
      .input("DomainID", sql.Int, Number(serverHardware.domainId))
      .input("OperatingSystemID", sql.Int, Number(serverHardware.operatingSystemId))
      .input("MemoryGB", sql.Int, Number(serverHardware.memoryGB))
      .input("CPUCores", sql.Int, Number(serverHardware.cpuCores))
      .input("ProcessorModel", sql.VarChar(150), serverHardware.processorModel || null)
      .input("ServerTypeID", sql.Int, Number(serverHardware.serverTypeId))
      .input("PlatformID", sql.Int, Number(serverHardware.platformId))
      .input("TimezoneID", sql.Int, Number(serverHardware.timezoneId))
      .input("OSInstallDate", sql.Date, serverHardware.osInstallDate || null)
      .input("CreatedBy", sql.VarChar(100), changedBy)
      .input("EffectiveDate", sql.Date, serverHardware.effectiveDate || null)
      .query(`
        INSERT INTO inventory.ServerHardware
        (ServerID, DomainID, OperatingSystemID, MemoryGB, CPUCores, ProcessorModel, ServerTypeID, PlatformID, TimezoneID, OSInstallDate, IsCurrent, EffectiveDate, CreatedBy)
        OUTPUT INSERTED.ServerHardwareID
        VALUES (@ServerID, @DomainID, @OperatingSystemID, @MemoryGB, @CPUCores, @ProcessorModel, @ServerTypeID, @PlatformID, @TimezoneID, @OSInstallDate, 1, COALESCE(@EffectiveDate, CONVERT(date, SYSDATETIME())), @CreatedBy);
      `);
    const hwId = hwIns.recordset[0].ServerHardwareID;
    await logChange(tx, "ServerHardware", hwId, "VersionRollOver", "PreviousCurrent", "NewCurrent", changedBy);

    const existingInstancesRs = await new sql.Request(tx)
      .input("ServerID", sql.Int, serverId)
      .query("SELECT SQLInstanceID, InstanceName, InstanceTypeID, SQLInstallDate, IsActive FROM inventory.SQLInstance WHERE ServerID = @ServerID;");
    const existingMap = new Map(existingInstancesRs.recordset.map((r) => [String(r.InstanceName).toLowerCase(), r]));
    const incomingNames = new Set();
    const sqlInstanceIds = [];

    for (const inst of sqlInstances) {
      const nameKey = String(inst.instanceName).toLowerCase();
      incomingNames.add(nameKey);
      const existingInst = existingMap.get(nameKey);
      let sqlInstanceId;

      if (existingInst) {
        sqlInstanceId = existingInst.SQLInstanceID;
        await new sql.Request(tx)
          .input("SQLInstanceID", sql.Int, sqlInstanceId)
          .input("InstanceTypeID", sql.Int, Number(inst.instanceTypeId))
          .input("SQLInstallDate", sql.Date, inst.sqlInstallDate || null)
          .input("ModifiedBy", sql.VarChar(100), changedBy)
          .query(`
            UPDATE inventory.SQLInstance
            SET InstanceTypeID=@InstanceTypeID, SQLInstallDate=@SQLInstallDate, IsActive=1, ModifiedDate=SYSDATETIME(), ModifiedBy=@ModifiedBy
            WHERE SQLInstanceID=@SQLInstanceID;
          `);
        await logChange(tx, "SQLInstance", sqlInstanceId, "InstanceTypeID", existingInst.InstanceTypeID, Number(inst.instanceTypeId), changedBy);
        await logChange(tx, "SQLInstance", sqlInstanceId, "SQLInstallDate", existingInst.SQLInstallDate, inst.sqlInstallDate || null, changedBy);
      } else {
        const ins = await new sql.Request(tx)
          .input("ServerID", sql.Int, serverId)
          .input("InstanceName", sql.VarChar(150), inst.instanceName)
          .input("InstanceTypeID", sql.Int, Number(inst.instanceTypeId))
          .input("SQLInstallDate", sql.Date, inst.sqlInstallDate || null)
          .input("CreatedBy", sql.VarChar(100), changedBy)
          .query(`
            INSERT INTO inventory.SQLInstance (ServerID, InstanceName, InstanceTypeID, SQLInstallDate, CreatedBy, IsActive)
            OUTPUT INSERTED.SQLInstanceID
            VALUES (@ServerID, @InstanceName, @InstanceTypeID, @SQLInstallDate, @CreatedBy, 1);
          `);
        sqlInstanceId = ins.recordset[0].SQLInstanceID;
      }
      sqlInstanceIds.push(sqlInstanceId);

      await new sql.Request(tx).input("SQLInstanceID", sql.Int, sqlInstanceId).query("UPDATE inventory.SQLInstanceVersion SET IsCurrent = 0 WHERE SQLInstanceID=@SQLInstanceID AND IsCurrent=1;");
      await new sql.Request(tx)
        .input("SQLInstanceID", sql.Int, sqlInstanceId)
        .input("SQLVersionID", sql.Int, Number(inst.sqlVersionId))
        .input("SQLEditionID", sql.Int, Number(inst.sqlEditionId))
        .input("ProductBuild", sql.VarChar(50), inst.productBuild)
        .input("ProductLevel", sql.VarChar(50), inst.productLevel)
        .input("EffectiveDate", sql.Date, inst.versionEffectiveDate || null)
        .query(`
          INSERT INTO inventory.SQLInstanceVersion
          (SQLInstanceID, SQLVersionID, SQLEditionID, ProductBuild, ProductLevel, IsCurrent, EffectiveDate)
          VALUES (@SQLInstanceID, @SQLVersionID, @SQLEditionID, @ProductBuild, @ProductLevel, 1, COALESCE(@EffectiveDate, CONVERT(date, SYSDATETIME())));
        `);

      await new sql.Request(tx).input("SQLInstanceID", sql.Int, sqlInstanceId).query("UPDATE inventory.SQLInstanceConfig SET IsCurrent = 0 WHERE SQLInstanceID=@SQLInstanceID AND IsCurrent=1;");
      await new sql.Request(tx)
        .input("SQLInstanceID", sql.Int, sqlInstanceId)
        .input("InstanceCollationID", sql.Int, Number(inst.instanceCollationId))
        .input("MinMemoryMB", sql.Int, inst.minMemoryMB ?? null)
        .input("MaxMemoryMB", sql.Int, inst.maxMemoryMB ?? null)
        .input("MaxDOP", sql.Int, inst.maxDOP ?? null)
        .input("CostThresholdParallelism", sql.Int, inst.costThresholdParallelism ?? null)
        .input("AdhocWorkload", sql.Bit, inst.adhocWorkload ? 1 : 0)
        .input("LockPageInMemory", sql.Bit, inst.lockPageInMemory ? 1 : 0)
        .input("IFI", sql.Bit, inst.ifi ? 1 : 0)
        .input("DatabaseMail", sql.Bit, inst.databaseMail ? 1 : 0)
        .input("FileStream", sql.Bit, inst.fileStream ? 1 : 0)
        .input("EffectiveDate", sql.Date, inst.configEffectiveDate || null)
        .query(`
          INSERT INTO inventory.SQLInstanceConfig
          (SQLInstanceID, InstanceCollationID, MinMemoryMB, MaxMemoryMB, MaxDOP, CostThresholdParallelism, AdhocWorkload, LockPageInMemory, IFI, DatabaseMail, FileStream, IsCurrent, EffectiveDate)
          VALUES (@SQLInstanceID, @InstanceCollationID, @MinMemoryMB, @MaxMemoryMB, @MaxDOP, @CostThresholdParallelism, @AdhocWorkload, @LockPageInMemory, @IFI, @DatabaseMail, @FileStream, 1, COALESCE(@EffectiveDate, CONVERT(date, SYSDATETIME())));
        `);

      // Databases sync (optional, per instance):
      // - Only runs when payload provides at least one named database row.
      //   (Prevents accidental wiping when DB-level inventory isn't maintained.)
      if (Array.isArray(inst.databases) && inst.databases.some((db) => required(db?.databaseName))) {
        // - soft deactivate all existing rows for this instance
        // - upsert incoming rows by (SQLInstanceID, DatabaseName)
        const existingDbRs = await new sql.Request(tx)
          .input("SQLInstanceID", sql.Int, sqlInstanceId)
          .query(`
            SELECT
              SQLDatabaseID,
              DatabaseName,
              Owner,
              SizeGB,
              CreatedOn,
              RecoveryModel,
              DatabaseCollation,
              CDC,
              CompatibilityLevel,
              Encryption,
              QueryStore,
              AutoUpdateStats,
              IsActive
            FROM inventory.SQLDatabase
            WHERE SQLInstanceID = @SQLInstanceID;
          `);
        const existingDbMap = new Map((existingDbRs.recordset || []).map((r) => [String(r.DatabaseName || "").toLowerCase(), r]));

        await new sql.Request(tx)
          .input("SQLInstanceID", sql.Int, sqlInstanceId)
          .input("ModifiedBy", sql.VarChar(100), changedBy)
          .query(`
            UPDATE inventory.SQLDatabase
            SET IsActive = 0, ModifiedDate = SYSDATETIME(), ModifiedBy = @ModifiedBy
            WHERE SQLInstanceID = @SQLInstanceID;
          `);

        const incomingDbNames = new Set();
        for (const db of inst.databases || []) {
          if (!db || !required(db.databaseName)) continue;
          const nameKey = String(db.databaseName).toLowerCase();
          incomingDbNames.add(nameKey);
          const ex = existingDbMap.get(nameKey);

        const sizeVal = db.sizeGB === null || db.sizeGB === undefined || db.sizeGB === "" ? null : Number(db.sizeGB);
        const compatVal = db.compatibilityLevel === null || db.compatibilityLevel === undefined || db.compatibilityLevel === "" ? null : Number(db.compatibilityLevel);
        const isActiveVal = db.isActive === false ? 0 : 1;

          if (ex) {
          // Field-level logging (best-effort; only for key fields).
          await logChange(tx, "SQLDatabase", ex.SQLDatabaseID, "Owner", ex.Owner, db.owner || null, changedBy);
          await logChange(tx, "SQLDatabase", ex.SQLDatabaseID, "SizeGB", ex.SizeGB, sizeVal, changedBy);
          await logChange(tx, "SQLDatabase", ex.SQLDatabaseID, "RecoveryModel", ex.RecoveryModel, db.recoveryModel || null, changedBy);
          await logChange(tx, "SQLDatabase", ex.SQLDatabaseID, "IsActive", ex.IsActive, isActiveVal, changedBy);

          await new sql.Request(tx)
            .input("SQLDatabaseID", sql.Int, ex.SQLDatabaseID)
            .input("Owner", sql.VarChar(128), db.owner || null)
            .input("SizeGB", sql.Decimal(18, 2), sizeVal)
            .input("CreatedOn", sql.DateTime2, db.createdOn || null)
            .input("RecoveryModel", sql.VarChar(30), db.recoveryModel || null)
            .input("DatabaseCollation", sql.VarChar(128), db.databaseCollation || null)
            .input("CDC", sql.Bit, db.cdc ? 1 : 0)
            .input("CompatibilityLevel", sql.Int, compatVal)
            .input("Encryption", sql.Bit, db.encryption ? 1 : 0)
            .input("QueryStore", sql.Bit, db.queryStore ? 1 : 0)
            .input("AutoUpdateStats", sql.Bit, db.autoUpdateStats === false ? 0 : 1)
            .input("IsActive", sql.Bit, isActiveVal)
            .input("ModifiedBy", sql.VarChar(100), changedBy)
            .query(`
              UPDATE inventory.SQLDatabase
              SET Owner=@Owner,
                  SizeGB=@SizeGB,
                  CreatedOn=@CreatedOn,
                  RecoveryModel=@RecoveryModel,
                  DatabaseCollation=@DatabaseCollation,
                  CDC=@CDC,
                  CompatibilityLevel=@CompatibilityLevel,
                  Encryption=@Encryption,
                  QueryStore=@QueryStore,
                  AutoUpdateStats=@AutoUpdateStats,
                  IsActive=@IsActive,
                  ModifiedDate=SYSDATETIME(),
                  ModifiedBy=@ModifiedBy
              WHERE SQLDatabaseID=@SQLDatabaseID;
            `);
          } else {
          await new sql.Request(tx)
            .input("SQLInstanceID", sql.Int, sqlInstanceId)
            .input("DatabaseName", sql.VarChar(256), db.databaseName)
            .input("Owner", sql.VarChar(128), db.owner || null)
            .input("SizeGB", sql.Decimal(18, 2), sizeVal)
            .input("CreatedOn", sql.DateTime2, db.createdOn || null)
            .input("RecoveryModel", sql.VarChar(30), db.recoveryModel || null)
            .input("DatabaseCollation", sql.VarChar(128), db.databaseCollation || null)
            .input("CDC", sql.Bit, db.cdc ? 1 : 0)
            .input("CompatibilityLevel", sql.Int, compatVal)
            .input("Encryption", sql.Bit, db.encryption ? 1 : 0)
            .input("QueryStore", sql.Bit, db.queryStore ? 1 : 0)
            .input("AutoUpdateStats", sql.Bit, db.autoUpdateStats === false ? 0 : 1)
            .input("IsActive", sql.Bit, isActiveVal)
            .input("CreatedBy", sql.VarChar(100), changedBy)
            .query(`
              INSERT INTO inventory.SQLDatabase
              (SQLInstanceID, DatabaseName, Owner, SizeGB, CreatedOn, RecoveryModel, DatabaseCollation, CDC, CompatibilityLevel, Encryption, QueryStore, AutoUpdateStats, IsActive, CreatedBy)
              VALUES
              (@SQLInstanceID, @DatabaseName, @Owner, @SizeGB, @CreatedOn, @RecoveryModel, @DatabaseCollation, @CDC, @CompatibilityLevel, @Encryption, @QueryStore, @AutoUpdateStats, @IsActive, @CreatedBy);
            `);
          }
        }

        // Deactivation logging for previously-active DBs no longer present in payload.
        for (const ex of existingDbRs.recordset || []) {
          const key = String(ex.DatabaseName || "").toLowerCase();
          if (ex.IsActive && !incomingDbNames.has(key)) {
            await logChange(tx, "SQLDatabase", ex.SQLDatabaseID, "IsActive", 1, 0, changedBy);
          }
        }
      }
    }

    for (const existingInst of existingInstancesRs.recordset) {
      const key = String(existingInst.InstanceName).toLowerCase();
      if (!incomingNames.has(key) && existingInst.IsActive) {
        await new sql.Request(tx)
          .input("SQLInstanceID", sql.Int, existingInst.SQLInstanceID)
          .input("ModifiedBy", sql.VarChar(100), changedBy)
          .query(`
            UPDATE inventory.SQLInstance
            SET IsActive = 0, ModifiedDate = SYSDATETIME(), ModifiedBy=@ModifiedBy
            WHERE SQLInstanceID = @SQLInstanceID;
          `);
        await logChange(tx, "SQLInstance", existingInst.SQLInstanceID, "IsActive", 1, 0, changedBy);
      }
    }

    await new sql.Request(tx).input("ServerID", sql.Int, serverId).query("UPDATE inventory.ServerIP SET IsActive = 0 WHERE ServerID=@ServerID;");
    for (const ip of serverIPs) {
      const existingIp = await new sql.Request(tx)
        .input("IPAddress", sql.VarChar(50), ip.ipAddress)
        .query("SELECT TOP 1 IPID, ServerID FROM inventory.ServerIP WHERE IPAddress = @IPAddress;");

      if (existingIp.recordset.length > 0) {
        const ownerServerId = Number(existingIp.recordset[0].ServerID);
        if (ownerServerId !== serverId) {
          throw new Error(`IP address ${ip.ipAddress} already belongs to server ID ${ownerServerId}.`);
        }

        await new sql.Request(tx)
          .input("ServerID", sql.Int, serverId)
          .input("IPAddress", sql.VarChar(50), ip.ipAddress)
          .input("IPAddressTypeID", sql.Int, Number(ip.ipAddressTypeId))
          .input("IsActive", sql.Bit, ip.isActive === false ? 0 : 1)
          .query(`
            UPDATE inventory.ServerIP
            SET ServerID = @ServerID, IPAddressTypeID = @IPAddressTypeID, IsActive = @IsActive
            WHERE IPAddress = @IPAddress;
          `);
      } else {
        await new sql.Request(tx)
          .input("ServerID", sql.Int, serverId)
          .input("IPAddress", sql.VarChar(50), ip.ipAddress)
          .input("IPAddressTypeID", sql.Int, Number(ip.ipAddressTypeId))
          .input("IsActive", sql.Bit, ip.isActive === false ? 0 : 1)
          .query("INSERT INTO inventory.ServerIP (ServerID, IPAddress, IPAddressTypeID, IsActive) VALUES (@ServerID, @IPAddress, @IPAddressTypeID, @IsActive);");
      }
    }

    await new sql.Request(tx).input("ServerID", sql.Int, serverId).query("UPDATE inventory.ServerStorage SET IsActive = 0 WHERE ServerID=@ServerID;");
    for (const s of serverStorages) {
      const existingStorage = await new sql.Request(tx)
        .input("ServerID", sql.Int, serverId)
        .input("DriveLetter", sql.Char(1), s.driveLetter)
        .query("SELECT TOP 1 StorageID FROM inventory.ServerStorage WHERE ServerID = @ServerID AND DriveLetter = @DriveLetter;");

      if (existingStorage.recordset.length > 0) {
        await new sql.Request(tx)
          .input("ServerID", sql.Int, serverId)
          .input("DriveLetter", sql.Char(1), s.driveLetter)
          .input("VolumeLabel", sql.VarChar(100), s.volumeLabel || null)
          .input("TotalSizeGB", sql.Decimal(18, 2), Number(s.totalSizeGB))
          .input("FreeSpaceGB", sql.Decimal(18, 2), Number(s.freeSpaceGB))
          .input("IsActive", sql.Bit, s.isActive === false ? 0 : 1)
          .query(`
            UPDATE inventory.ServerStorage
            SET VolumeLabel = @VolumeLabel, TotalSizeGB = @TotalSizeGB, FreeSpaceGB = @FreeSpaceGB, IsActive = @IsActive
            WHERE ServerID = @ServerID AND DriveLetter = @DriveLetter;
          `);
      } else {
        await new sql.Request(tx)
          .input("ServerID", sql.Int, serverId)
          .input("DriveLetter", sql.Char(1), s.driveLetter)
          .input("VolumeLabel", sql.VarChar(100), s.volumeLabel || null)
          .input("TotalSizeGB", sql.Decimal(18, 2), Number(s.totalSizeGB))
          .input("FreeSpaceGB", sql.Decimal(18, 2), Number(s.freeSpaceGB))
          .input("IsActive", sql.Bit, s.isActive === false ? 0 : 1)
          .query("INSERT INTO inventory.ServerStorage (ServerID, DriveLetter, VolumeLabel, TotalSizeGB, FreeSpaceGB, IsActive) VALUES (@ServerID, @DriveLetter, @VolumeLabel, @TotalSizeGB, @FreeSpaceGB, @IsActive);");
      }
    }

    // Contact mode:
    // - custom: replace server-specific contacts
    // - bu: remove any server-specific contacts so the UI falls back to BU defaults
    await new sql.Request(tx).input("ServerID", sql.Int, serverId).query("DELETE FROM inventory.ServerContact WHERE ServerID = @ServerID;");
    await logChange(tx, "Server", serverId, "ContactMode", existing.contactMode || "bu", contactMode, changedBy);

    if (contactMode === "custom") {
      for (const c of contacts || []) {
        if (!c || (!c.contactName && !c.email && !c.phone) || !c.contactCategoryId) continue;

        let contactId;
        if (c.email) {
          const existingContact = await new sql.Request(tx).input("Email", sql.VarChar(150), c.email).query("SELECT ContactID FROM inventory.Contact WHERE Email = @Email;");
          if (existingContact.recordset.length) contactId = existingContact.recordset[0].ContactID;
        }
        if (!contactId) {
          const ins = await new sql.Request(tx)
            .input("ContactName", sql.VarChar(150), c.contactName)
            .input("Email", sql.VarChar(150), c.email || null)
            .input("Phone", sql.VarChar(50), c.phone || null)
            .query("INSERT INTO inventory.Contact (ContactName, Email, Phone) OUTPUT INSERTED.ContactID VALUES (@ContactName, @Email, @Phone);");
          contactId = ins.recordset[0].ContactID;
        }
        await new sql.Request(tx)
          .input("ServerID", sql.Int, serverId)
          .input("ContactID", sql.Int, contactId)
          .input("ContactCategoryID", sql.Int, Number(c.contactCategoryId))
          .input("CreatedBy", sql.VarChar(100), changedBy)
          .query(`
            INSERT INTO inventory.ServerContact (ServerID, ContactID, ContactCategoryID, CreatedBy)
            VALUES (@ServerID, @ContactID, @ContactCategoryID, @CreatedBy);
          `);
      }
    }

    await logChange(tx, "Server", serverId, "UpdatedAt", existing.server.ModifiedDate, new Date().toISOString(), changedBy);

    await tx.commit();
    res.json({ message: "Inventory updated successfully", ids: { serverId, sqlInstanceIds } });
  } catch (e) {
    if (!tx._aborted) await tx.rollback();
    console.error(e);
    res.status(500).json({ message: "Failed to update inventory", error: e.originalError?.info?.message || e.message });
  }
});

app.listen(PORT, async () => {
  try {
    await getPool();
    console.log(`Server running on port ${PORT}`);
  } catch (e) {
    console.error("Database connection failed on startup:", e.message);
  }
});
