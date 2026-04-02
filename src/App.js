import React, { useEffect, useMemo, useState } from "react";
import axios from "axios";
import "./App.css";

// API base selection:
// - In IIS reverse-proxy deployments, the frontend should call same-origin (/api/..).
// - Keep localhost:5000 for local dev.
// - If someone accidentally builds with REACT_APP_API_BASE_URL=http://localhost:5000, ignore it on non-localhost.
const ENV_API_BASE = String(process.env.REACT_APP_API_BASE_URL || "").trim();
const isBrowser = typeof window !== "undefined";
const isLocalhost = isBrowser ? String(window.location.hostname || "").toLowerCase() === "localhost" : true;
const DEFAULT_API_BASE = isLocalhost ? "http://localhost:5000" : "";
const API_BASE = !isLocalhost && ENV_API_BASE.toLowerCase().includes("localhost")
  ? ""
  : (ENV_API_BASE || DEFAULT_API_BASE);
const tabs = ["Server", "Hardware", "SQL", "Network", "Contacts", "Review"];

const emptyIp = { ipAddress: "", ipAddressTypeId: "", isActive: true };
const emptyStorage = { driveLetter: "", volumeLabel: "", totalSizeGB: "", freeSpaceGB: "", isActive: true };
const emptyContact = { contactName: "", email: "", phone: "", contactCategoryId: "" };
const emptyDatabase = {
  databaseName: "",
  owner: "",
  sizeGB: "",
  createdOn: "",
  recoveryModel: "",
  databaseCollation: "",
  cdc: false,
  compatibilityLevel: "",
  encryption: false,
  queryStore: false,
  autoUpdateStats: false,
  isActive: true,
};
const emptySqlInstanceBase = {
  instanceName: "MSSQLSERVER",
  instanceTypeId: "",
  sqlInstallDate: "",
  sqlVersionId: "",
  sqlEditionId: "",
  productBuild: "",
  productLevel: "",
  versionEffectiveDate: "",
  instanceCollationId: "",
  minMemoryMB: "",
  maxMemoryMB: "",
  maxDOP: "",
  costThresholdParallelism: "",
  adhocWorkload: false,
  lockPageInMemory: false,
  ifi: false,
  databaseMail: false,
  fileStream: false,
  configEffectiveDate: "",
};
const newSqlInstance = () => ({ ...emptySqlInstanceBase, databases: [{ ...emptyDatabase }] });

const BU_LOGOS = {
  "ShopLC-US": "/logos/shoplc-us.png",
  "ShopLC-DE": "/logos/shoplc-de.png",
  "TJC-UK": "/logos/tjc-uk.png",
  "VGL-India": "/logos/vgl-india.png",
};
function getAuthData() {
  const token = localStorage.getItem("inventory_token");
  const username = localStorage.getItem("inventory_user");
  const role = localStorage.getItem("inventory_role");
  return { token, username, role };
}

function setAuthData(token, username, role) {
  localStorage.setItem("inventory_token", token);
  localStorage.setItem("inventory_user", username);
  localStorage.setItem("inventory_role", role);
}

function clearAuthData() {
  localStorage.removeItem("inventory_token");
  localStorage.removeItem("inventory_user");
  localStorage.removeItem("inventory_role");
}

function authHeaders(token) {
  return { headers: { Authorization: `Bearer ${token}` } };
}

const baseForm = (username = "") => ({
  server: { serverName: "", description: "", envId: "", buId: "", categoryId: "", regionId: "", statusId: "", createdBy: username },
  serverHardware: {
    domainId: "",
    operatingSystemId: "",
    memoryGB: "",
    cpuCores: "",
    processorModel: "",
    serverTypeId: "",
    platformId: "",
    timezoneId: "",
    osInstallDate: "",
    effectiveDate: "",
  },
  sqlInstances: [newSqlInstance()],
  serverIPs: [{ ...emptyIp }],
  serverStorages: [{ ...emptyStorage }],
  contactMode: "bu", // 'bu' (use BU default) or 'custom' (server-specific)
  contacts: [{ ...emptyContact }],
  buDefaultContacts: [],
});

function LoginView({ onLogin, busy, error }) {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [forgotInfo, setForgotInfo] = useState("");

  const submit = (e) => {
    e.preventDefault();
    onLogin(username.trim(), password);
  };

  return (
    <div className="app-shell login-shell">
      <section className="card login-card">
        <div className="brand-block" style={{ flexDirection: "column", alignItems: "center", textAlign: "center", gap: 10 }}>
          <div style={{ display: "flex", gap: 14, flexWrap: "wrap", justifyContent: "center", marginBottom: 4 }}>
            {Object.entries(BU_LOGOS).map(([name, src]) => (
              <img
                key={name}
                src={src}
                alt={`${name} logo`}
                style={{ height: 26, width: "auto" }}
                onError={(e) => {
                  e.currentTarget.style.display = "none";
                }}
              />
            ))}
          </div>
          <div>
            <h1>SQL Inventory</h1>
            <p className="brand-sub">SQL Server Inventory Management Portal</p>
          </div>
        </div>

        <h2 className="brand-sub">Login</h2>
        <p className="login-subtitle">Use your valid username and password to continue.</p>

        {error ? <div className="alert error">{error}</div> : null}
        {forgotInfo ? <div className="alert success">{forgotInfo}</div> : null}

        <form onSubmit={submit} className="login-form">
          <label>
            Username
            <input placeholder="Enter username" value={username} onChange={(e) => setUsername(e.target.value)} required />
          </label>
          <label>
            Password
            <div className="password-row">
              <input type={showPassword ? "text" : "password"} placeholder="Enter password" value={password} onChange={(e) => setPassword(e.target.value)} required />
              <button type="button" className="ghost-btn" onClick={() => setShowPassword((v) => !v)}>
                {showPassword ? "Hide" : "Show"}
              </button>
            </div>
          </label>

          <div className="login-links">
            <button
              type="button"
              className="link-btn"
              onClick={() => setForgotInfo("Please contact the DBA support team to reset your password.")}
            >
              Forgot Password?
            </button>
          </div>

          <button className="submit-btn" type="submit" disabled={busy}>
            {busy ? "Signing In..." : "Login"}
          </button>
        </form>
      </section>
    </div>
  );
}

function BuLogo({ name }) {
  const image = BU_LOGOS[name];
  const initials = String(name || "")
    .split(/[\s-]+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((x) => x[0]?.toUpperCase() || "")
    .join("");

  if (image) {
    return (
      <span className="bu-logo-image-wrap">
        <img className="bu-logo-image" src={image} alt={`${name} logo`} onError={(e) => { e.currentTarget.style.display = "none"; }} />
      </span>
    );
  }
  return <span className="bu-logo">{initials || "BU"}</span>;
}

function ExecutiveDashboard({ token, username, role, onLogout }) {
  const [data, setData] = useState(null);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);
  const [selectedBU, setSelectedBU] = useState(null);
  const [searchText, setSearchText] = useState("");
  const [searchResult, setSearchResult] = useState(null);
  const [searchBusy, setSearchBusy] = useState(false);

  useEffect(() => {
    (async () => {
      try {
        setLoading(true);
        const query = selectedBU ? `?bu=${encodeURIComponent(selectedBU)}` : "";
        const res = await axios.get(`${API_BASE}/api/dashboard/summary${query}`, authHeaders(token));
        setData(res.data);
      } catch (err) {
        setError(err.response?.data?.message || err.message);
      } finally {
        setLoading(false);
      }
    })();
  }, [token, selectedBU]);
  const IconEnv = (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" style={{ verticalAlign: "text-bottom" }} aria-hidden="true">
      <path d="M12 22c5.523 0 10-4.477 10-10S17.523 2 12 2 2 6.477 2 12s4.477 10 10 10Z" stroke="currentColor" strokeWidth="2" />
      <path d="M2 12h20" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
      <path d="M12 2c2.8 2.7 4.4 6.2 4.4 10S14.8 19.3 12 22c-2.8-2.7-4.4-6.2-4.4-10S9.2 4.7 12 2Z" stroke="currentColor" strokeWidth="2" />
    </svg>
  );

  const IconRegion = (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" style={{ verticalAlign: "text-bottom" }} aria-hidden="true">
      <path
        d="M12 22s7-4.5 7-11a7 7 0 1 0-14 0c0 6.5 7 11 7 11Z"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinejoin="round"
      />
      <path d="M12 13.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5Z" stroke="currentColor" strokeWidth="2" />
    </svg>
  );

  const metricBlock = (title, rows, icon = null) => (
    <section className="dash-card">
      <h3>
        {icon ? <span style={{ marginRight: 8, color: "#0f4fa8" }}>{icon}</span> : null}
        {title}
      </h3>
      <div className="metric-list">
        {(rows || []).map((r) => (
          <div key={`${title}-${r.label}`} className="metric-row">
            <span>{r.label}</span>
            <div className="metric-bar-wrap">
              <div className="metric-bar" style={{ width: `${Math.max(8, (r.value / Math.max(...rows.map((x) => x.value), 1)) * 100)}%` }} />
            </div>
            <strong>{r.value}</strong>
          </div>
        ))}
      </div>
    </section>
  );

  async function onSearchServer(e) {
    e.preventDefault();
    if (!searchText.trim()) return;
    try {
      setSearchBusy(true);
      const res = await axios.get(`${API_BASE}/api/server-search?name=${encodeURIComponent(searchText.trim())}`, authHeaders(token));
      setSearchResult(res.data);
      const firstId = res.data?.results?.[0]?.server?.ServerID;
      if (res.data?.count === 1 && firstId) {
        window.location.assign(`/server/${firstId}`);
      }
    } catch (err) {
      setError(err.response?.data?.message || err.message);
    } finally {
      setSearchBusy(false);
    }
  }

  if (loading) return <div className="app-shell">Loading executive dashboard...</div>;
  if (error) return <div className="app-shell"><div className="alert error">{error}</div></div>;

  return (
    <div className="app-shell">
      <header className="hero">
        <h1>SQL Server Inventory Management Portal</h1>
        <h3>Inventory Dashboard</h3>
        <p>Real-time Interactive Dashboard of SQL Server Inventory for visibility across Business Units.</p>
        <div className="hero-actions">
          <div className="top-nav">
            <a href="/dashboard" className="active-link">Dashboard</a>
            <a href="/health">Health Report</a>
            <a href="/serverlist">Server List</a>
            <a href="/databaselist">Database List</a>
            <a href="/databasetrend">Database Trend</a>
            {role === "admin" ? <a href="/inventory">Inventory Form</a> : null}
          </div>
          <span>Logged in as: <strong>{username}</strong></span>
          <button type="button" onClick={onLogout}>Logout</button>
        </div>
      </header>

      <div className="kpi-strip">
        <div className="kpi-card">
          <div>🖥️ Total Servers</div>
          <strong>{data.totalServers}</strong>
        </div>
        <div className="kpi-card" title="Total active SQL instances on IN USE servers (respects BU filter)">
          <div style={{ display: "inline-flex", alignItems: "center", gap: 8 }}>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" aria-hidden="true">
              <ellipse cx="12" cy="5" rx="8" ry="3" stroke="currentColor" strokeWidth="2" />
              <path d="M4 5v6c0 1.7 3.6 3 8 3s8-1.3 8-3V5" stroke="currentColor" strokeWidth="2" />
              <path d="M4 11v6c0 1.7 3.6 3 8 3s8-1.3 8-3v-6" stroke="currentColor" strokeWidth="2" />
            </svg>
            <span>SQL Instances</span>
          </div>
          <strong>{data.totalSqlInstances ?? 0}</strong>
        </div>
        {(data.byBusinessUnit || []).map((bu) => (
          <button
            type="button"
            key={bu.label}
            className={`kpi-card bu-kpi-btn ${selectedBU === bu.id ? "selected" : ""}`}
            onClick={() => setSelectedBU(selectedBU === bu.id ? null : bu.id)}
          >
            <div className="bu-kpi-name"><BuLogo name={bu.label} /> {bu.label}</div>
            <strong>{bu.value}</strong>
          </button>
        ))}
      </div>

      <div className="dash-top-row">
        {metricBlock("Servers by Environment", data.byEnvironment, IconEnv)}
        {metricBlock("Servers by Region", data.byLocation, IconRegion)}
        <section className="dash-card">
          <h3>🔎 Server Search</h3>
          <form className="search-row" onSubmit={onSearchServer}>
            <input value={searchText} onChange={(e) => setSearchText(e.target.value)} placeholder="Enter server name" />
            <button type="submit" disabled={searchBusy}>{searchBusy ? "Searching..." : "Search"}</button>
          </form>
          {searchResult ? (
            <div style={{ marginTop: 10 }}>
              <div><strong>Matches:</strong> {searchResult.count}</div>
              {(searchResult.results || []).slice(0, 5).map((r) => (
                <div
                  key={r.server?.ServerID}
                  className="search-result-card"
                  role="button"
                  tabIndex={0}
                  onClick={() => r.server?.ServerID && window.location.assign(`/server/${r.server.ServerID}`)}
                  onKeyDown={(e) => {
                    if (e.key === "Enter" && r.server?.ServerID) window.location.assign(`/server/${r.server.ServerID}`);
                  }}
                  style={{ cursor: r.server?.ServerID ? "pointer" : "default" }}
                >
                  <div><strong>{r.server?.ServerName}</strong></div>
                  <div>{r.server?.Description || "No description"}</div>
                  <div>Instances: {(r.sqlInstances || []).length}</div>
                </div>
              ))}
            </div>
          ) : null}
        </section>
      </div>

      <div className="dash-grid kpi-row">
        {metricBlock("Servers by Platform", data.byPlatform, "🧩")}
        {metricBlock("Servers by OS Category", data.byOSType, "💻")}
        {metricBlock("Servers by Server Type", data.byServerType, "🗂️")}
      </div>

      <div className="dash-grid">
        {metricBlock("Servers by SQL Version", data.bySQLVersion, "🧠")}
        {metricBlock("Servers by SQL Edition", data.bySQLEdition, "📦")}
        {metricBlock("Servers by Instance Type", data.byInstanceType, "🧷")}
      </div>

      <section className="dash-card">
        <h3>🕒 Recently Added / Modified Servers (Last 1 Month)</h3>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Server</th>
                <th>Business Unit</th>
                <th>Environment</th>
                <th>Region</th>
                <th>Created Date</th>
                <th>Modified Date</th>
              </tr>
            </thead>
            <tbody>
              {(data.recentServers || []).map((r) => (
                <tr key={`${r.ServerName}-${r.CreatedDate}`}>
                  <td>{r.ServerName}</td>
                  <td><BuLogo name={r.BusinessUnitName} /> {r.BusinessUnitName}</td>
                  <td>{r.EnvName}</td>
                  <td>{r.RegionName}</td>
                  <td>{String(r.CreatedDate).slice(0, 10)}</td>
                  <td>{r.ModifiedDate ? String(r.ModifiedDate).slice(0, 10) : "-"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="dash-card">
        <h3>🟡 Servers To Be Commissioned</h3>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Server</th>
                <th>Business Unit</th>
                <th>Environment</th>
                <th>Region</th>
                <th>Created Date</th>
                <th>Modified Date</th>
              </tr>
            </thead>
            <tbody>
              {(data.toBeCommissioned || []).map((r) => (
                <tr key={`${r.ServerName}-${r.CreatedDate}`}>
                  <td>{r.ServerName}</td>
                  <td><BuLogo name={r.BusinessUnitName} /> {r.BusinessUnitName}</td>
                  <td>{r.EnvName}</td>
                  <td>{r.RegionName}</td>
                  <td>{String(r.CreatedDate).slice(0, 10)}</td>
                  <td>{r.ModifiedDate ? String(r.ModifiedDate).slice(0, 10) : "-"}</td>
                </tr>
              ))}
              {(!data.toBeCommissioned || data.toBeCommissioned.length === 0) ? (
                <tr><td colSpan="6">No records.</td></tr>
              ) : null}
            </tbody>
          </table>
        </div>
      </section>

      <section className="dash-card">
        <h3>🔴 Servers Decommissioned In Last 3 Months</h3>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Server</th>
                <th>Business Unit</th>
                <th>Environment</th>
                <th>Region</th>
                <th>Created Date</th>
                <th>Modified Date</th>
              </tr>
            </thead>
            <tbody>
              {(data.decommissionedLast3Months || []).map((r) => (
                <tr key={`${r.ServerName}-${r.CreatedDate}`}>
                  <td>{r.ServerName}</td>
                  <td><BuLogo name={r.BusinessUnitName} /> {r.BusinessUnitName}</td>
                  <td>{r.EnvName}</td>
                  <td>{r.RegionName}</td>
                  <td>{String(r.CreatedDate).slice(0, 10)}</td>
                  <td>{r.ModifiedDate ? String(r.ModifiedDate).slice(0, 10) : "-"}</td>
                </tr>
              ))}
              {(!data.decommissionedLast3Months || data.decommissionedLast3Months.length === 0) ? (
                <tr><td colSpan="6">No records.</td></tr>
              ) : null}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}

function downloadCsv(filename, rows, columns) {
  const escape = (v) => {
    if (v === null || v === undefined) return "";
    const s = String(v);
    if (/[",\r\n]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
    return s;
  };
  const header = columns.map((c) => escape(c.header)).join(",");
  const body = rows
    .map((r) => columns.map((c) => escape(r[c.key])).join(","))
    .join("\r\n");
  const csv = `${header}\r\n${body}\r\n`;
  const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

function downloadCsvSections(filename, sections) {
  const escape = (v) => {
    if (v === null || v === undefined) return "";
    const s = String(v);
    if (/[",\r\n]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
    return s;
  };

  const lines = [];
  for (const sec of sections || []) {
    if (!sec) continue;
    lines.push(escape(sec.title || ""));
    if (sec.subtitle) lines.push(escape(sec.subtitle));
    if (sec.columns && sec.columns.length) {
      lines.push(sec.columns.map((c) => escape(c.header)).join(","));
      for (const r of sec.rows || []) {
        lines.push(sec.columns.map((c) => escape(r[c.key])).join(","));
      }
    }
    lines.push(""); // spacer line
  }

  const csv = `${lines.join("\r\n")}\r\n`;
  const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

function ServerListPage({ token, username, role, onLogout }) {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [selectedBU, setSelectedBU] = useState(null);
  const [filterText, setFilterText] = useState("");

  useEffect(() => {
    (async () => {
      try {
        setLoading(true);
        setError("");
        const query = selectedBU ? `?bu=${encodeURIComponent(selectedBU)}` : "";
        const res = await axios.get(`${API_BASE}/api/server-list${query}`, authHeaders(token));
        setRows(res.data || []);
      } catch (err) {
        setError(err.response?.data?.message || err.message);
      } finally {
        setLoading(false);
      }
    })();
  }, [token, selectedBU]);

  const columns = useMemo(
    () => [
      { header: "BUName", key: "BUName" },
      { header: "ServerName", key: "ServerName" },
      { header: "Environment", key: "Environment" },
      { header: "ServerDescription", key: "ServerDescription" },
      { header: "Region", key: "Region" },
      { header: "Platform", key: "Platform" },
      { header: "ServerType", key: "ServerType" },
      { header: "Domain", key: "Domain" },
      { header: "IPAddress", key: "IPAddress" },
      { header: "Cores", key: "Cores" },
      { header: "RAM", key: "RAM" },
      { header: "Operating System", key: "OperatingSystem" },
      { header: "SQLInstanceName", key: "SQLInstanceName" },
      { header: "SQlInstance Type", key: "SQLInstanceType" },
      { header: "SQL Version", key: "SQLVersion" },
      { header: "SQL Edition", key: "SQLEdition" },
      { header: "ProductBuild", key: "ProductBuild" },
      { header: "ProductLevel", key: "ProductLevel" },
    ],
    []
  );

  const buCards = useMemo(() => {
    const by = new Map(); // BUName -> Set(ServerID)
    for (const r of rows) {
      const k = r.BUName || "Unknown";
      if (!by.has(k)) by.set(k, new Set());
      if (r.ServerID != null) by.get(k).add(r.ServerID);
    }
    return Array.from(by.entries())
      .map(([label, set]) => ({ label, id: label, value: set.size }))
      .sort((a, b) => b.value - a.value || a.label.localeCompare(b.label));
  }, [rows]);

  const totalUniqueServers = useMemo(() => {
    const s = new Set();
    for (const r of rows) if (r.ServerID != null) s.add(r.ServerID);
    return s.size;
  }, [rows]);

  const filteredRows = useMemo(() => {
    const t = filterText.trim().toLowerCase();
    if (!t) return rows;
    return rows.filter((r) => {
      const hay = [
        r.BUName,
        r.ServerName,
        r.Environment,
        r.ServerDescription,
        r.Region,
        r.Platform,
        r.ServerType,
        r.Domain,
        r.IPAddress,
        r.OperatingSystem,
        r.SQLInstanceName,
        r.SQLInstanceType,
        r.SQLVersion,
        r.SQLEdition,
        r.ProductBuild,
        r.ProductLevel,
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();
      return hay.includes(t);
    });
  }, [rows, filterText]);

  if (loading) return <div className="app-shell">Loading server list...</div>;
  if (error) return <div className="app-shell"><div className="alert error">{error}</div></div>;

  return (
    <div className="app-shell">
      <header className="hero">
        <h1>SQL Server Inventory Management Portal</h1>
        <h3>Inventory List</h3>
        <p>Interactive Instance-level catalog for quick filtering and export.</p>
        <div className="hero-actions">
          <div className="top-nav">
            <a href="/dashboard">Dashboard</a>
            <a href="/health">Health Report</a>
            <a href="/serverlist" className="active-link">Server List</a>
            <a href="/databaselist">Database List</a>
            <a href="/databasetrend">Database Trend</a>
            {role === "admin" ? <a href="/inventory">Inventory Form</a> : null}
          </div>
          <span>Logged in as: <strong>{username}</strong></span>
          <button type="button" onClick={onLogout}>Logout</button>
        </div>
      </header>

      <div className="kpi-strip">
        <div className="kpi-card">
          <div>🗄️ Total Servers</div>
          <strong>{totalUniqueServers}</strong>
        </div>
        {buCards.map((bu) => (
          <button
            type="button"
            key={bu.label}
            className={`kpi-card bu-kpi-btn ${selectedBU === bu.id ? "selected" : ""}`}
            onClick={() => setSelectedBU(selectedBU === bu.id ? null : bu.id)}
          >
            <div className="bu-kpi-name"><BuLogo name={bu.label} /> {bu.label}</div>
            <strong>{bu.value}</strong>
          </button>
        ))}
      </div>

      <section className="dash-card" style={{ marginTop: 16 }}>
        <div className="search-row">
          <div className="search-box">
            <label>Filter rows</label>
            <div className="search-inline">
              <input value={filterText} placeholder="Type to filter (server, version, IP, BU...)" onChange={(e) => setFilterText(e.target.value)} />
              <button type="button" onClick={() => setFilterText("")}>Clear</button>
            </div>
          </div>
          <div className="search-box">
            <label>Export</label>
            <div className="search-inline">
              <button type="button" onClick={() => downloadCsv(`serverlist_${new Date().toISOString().slice(0, 10)}.csv`, filteredRows, columns)}>
                Export CSV
              </button>
            </div>
          </div>
        </div>

        <div className="table-wrap">
          <table className="data-table">
            <thead>
              <tr>
                {columns.map((c) => (
                  <th key={c.header}>{c.header}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filteredRows.map((r, idx) => (
                <tr key={`${r.ServerID || "s"}-${r.SQLInstanceName || "i"}-${idx}`}>
                  {columns.map((c) => (
                    <td key={`${c.header}-${idx}`}>
                      {c.key === "ServerName" && r.ServerID ? (
                        <a href={`/server/${r.ServerID}`} title="Open server details">
                          {r.ServerName ?? ""}
                        </a>
                      ) : (
                        r[c.key] ?? ""
                      )}
                    </td>
                  ))}
                </tr>
              ))}
              {!filteredRows.length ? (
                <tr>
                  <td colSpan={columns.length} style={{ textAlign: "center", padding: 16 }}>
                    No rows found.
                  </td>
                </tr>
              ) : null}
            </tbody>
          </table>
        </div>
      </section>

      <footer className="footer-note">
        <div>Counts and list are scoped to servers with status <strong>IN USE</strong>.</div>
        <div>Use CSV export for Excel-compatible download.</div>
      </footer>
    </div>
  );
}

function DatabaseListPage({ token, username, role, onLogout }) {
  const [businessUnits, setBusinessUnits] = useState([]);
  const [servers, setServers] = useState([]);
  const [selectedBuId, setSelectedBuId] = useState("");
  const [selectedServerId, setSelectedServerId] = useState("");
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [filterText, setFilterText] = useState("");

  useEffect(() => {
    (async () => {
      try {
        setError("");
        const res = await axios.get(`${API_BASE}/api/business-units`, authHeaders(token));
        setBusinessUnits(res.data || []);
      } catch (err) {
        setError(err.response?.data?.message || err.message);
      }
    })();
  }, [token]);

  useEffect(() => {
    (async () => {
      try {
        setError("");
        const q = selectedBuId ? `?buId=${encodeURIComponent(selectedBuId)}` : "";
        const res = await axios.get(`${API_BASE}/api/servers-by-bu${q}`, authHeaders(token));
        setServers(res.data || []);
      } catch (err) {
        setError(err.response?.data?.message || err.message);
      }
    })();
  }, [token, selectedBuId]);

  useEffect(() => {
    (async () => {
      try {
        setLoading(true);
        setError("");
        const params = new URLSearchParams();
        if (selectedBuId) params.set("buId", selectedBuId);
        if (selectedServerId) params.set("serverId", selectedServerId);
        const q = params.toString() ? `?${params.toString()}` : "";
        const res = await axios.get(`${API_BASE}/api/database-list${q}`, authHeaders(token));
        setRows(res.data || []);
      } catch (err) {
        setError(err.response?.data?.message || err.message);
      } finally {
        setLoading(false);
      }
    })();
  }, [token, selectedBuId, selectedServerId]);

  const columns = useMemo(
    () => [
      { header: "BUName", key: "BUName" },
      { header: "ServerName", key: "ServerName" },
      { header: "SQLInstanceName", key: "SQLInstanceName" },
      { header: "Environment", key: "Environment" },
      { header: "DatabaseName", key: "DatabaseName" },
      { header: "Owner", key: "Owner" },
      { header: "SizeGB", key: "SizeGB" },
      { header: "CreatedOn", key: "CreatedOn" },
      { header: "RecoveryModel", key: "RecoveryModel" },
      { header: "DatabaseCollation", key: "DatabaseCollation" },
      { header: "CDC", key: "CDC" },
      { header: "CompatabilityLevel", key: "CompatibilityLevel" },
      { header: "Encryption", key: "Encryption" },
      { header: "QueryStore", key: "QueryStore" },
      { header: "AutoUpdateStats", key: "AutoUpdateStats" },
    ],
    []
  );

  const renderCellValue = (key, value) => {
    if (key === "CreatedOn") return fmtDate(value);

    // React renders boolean false as empty, so show explicit Yes/No for flags.
    const flagKeys = new Set(["CDC", "Encryption", "QueryStore", "AutoUpdateStats"]);
    if (typeof value === "boolean") return value ? "Yes" : "No";
    if (flagKeys.has(key) && (value === 0 || value === 1)) return value === 1 ? "Yes" : "No";

    return value ?? "";
  };

  const filteredRows = useMemo(() => {
    const t = filterText.trim().toLowerCase();
    if (!t) return rows;
    return rows.filter((r) => {
      const hay = [
        r.BUName,
        r.ServerName,
        r.SQLInstanceName,
        r.Environment,
        r.DatabaseName,
        r.Owner,
        r.RecoveryModel,
        r.DatabaseCollation,
        r.CompatibilityLevel,
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();
      return hay.includes(t);
    });
  }, [rows, filterText]);

  const totalDatabases = rows.length;

  if (loading) return <div className="app-shell">Loading database list...</div>;
  if (error) return <div className="app-shell"><div className="alert error">{error}</div></div>;

  return (
    <div className="app-shell">
      <header className="hero">
        <h1>SQL Server Inventory Management Portal</h1>
        <h3>Database List</h3>
        <p>Instance-scoped database catalog for filtering, export, and quick validation of ownership and configuration flags.</p>
        <div className="hero-actions">
          <div className="top-nav">
            <a href="/dashboard">Dashboard</a>
            <a href="/health">Health Report</a>
            <a href="/serverlist">Server List</a>
            <a href="/databaselist" className="active-link">Database List</a>
            <a href="/databasetrend">Database Trend</a>
            {role === "admin" ? <a href="/inventory">Inventory Form</a> : null}
          </div>
          <span>Logged in as: <strong>{username}</strong></span>
          <button type="button" onClick={onLogout}>Logout</button>
        </div>
      </header>

      <section className="dash-card" style={{ marginTop: 12 }}>
        <div className="search-row">
          <div className="search-box">
            <label>Business Unit</label>
            <select
              value={selectedBuId}
              onChange={(e) => {
                setSelectedBuId(e.target.value);
                setSelectedServerId("");
              }}
            >
              <option value="">All Business Units</option>
              {(businessUnits || []).map((bu) => (
                <option key={bu.id} value={bu.id}>{bu.name}</option>
              ))}
            </select>
          </div>
          <div className="search-box">
            <label>Server</label>
            <select
              value={selectedServerId}
              onChange={(e) => setSelectedServerId(e.target.value)}
            >
              <option value="">All Servers</option>
              {(servers || []).map((s) => (
                <option key={s.id} value={s.id}>{s.name}</option>
              ))}
            </select>
          </div>
          <div className="kpi-card" style={{ alignSelf: "end", minWidth: 240 }}>
            <div>Total Databases</div>
            <strong>{totalDatabases}</strong>
          </div>
        </div>
      </section>

      <section className="dash-card" style={{ marginTop: 16 }}>
        <div className="search-row">
          <div className="search-box">
            <label>Filter rows</label>
            <div className="search-inline">
              <input value={filterText} placeholder="Type to filter (db, owner, server, instance...)" onChange={(e) => setFilterText(e.target.value)} />
              <button type="button" onClick={() => setFilterText("")}>Clear</button>
            </div>
          </div>
          <div className="search-box">
            <label>Export</label>
            <div className="search-inline">
              <button type="button" onClick={() => downloadCsv(`databaselist_${new Date().toISOString().slice(0, 10)}.csv`, filteredRows, columns)}>
                Export CSV
              </button>
            </div>
          </div>
        </div>

        <div className="table-wrap">
          <table className="data-table">
            <thead>
              <tr>
                {columns.map((c) => (
                  <th key={c.header}>{c.header}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filteredRows.map((r, idx) => (
                <tr key={`${r.SQLDatabaseID || "db"}-${idx}`}>
                  {columns.map((c) => (
                    <td key={`${c.header}-${idx}`}>
                      {renderCellValue(c.key, r[c.key])}
                    </td>
                  ))}
                </tr>
              ))}
              {!filteredRows.length ? (
                <tr>
                  <td colSpan={columns.length} style={{ textAlign: "center", padding: 16 }}>
                    No rows found.
                  </td>
                </tr>
              ) : null}
            </tbody>
          </table>
        </div>
      </section>

      <footer className="footer-note">
        <div>Filters are applied via BU and Server dropdowns; leaving both empty shows the full catalog.</div>
        <div>Export downloads CSV for Excel-compatible usage.</div>
      </footer>
    </div>
  );
}

function DatabaseTrendPage({ token, username, role, onLogout }) {
  const [businessUnits, setBusinessUnits] = useState([]);
  const [prodServers, setProdServers] = useState([]);
  const [selectedBuId, setSelectedBuId] = useState("");
  const [selectedServerId, setSelectedServerId] = useState("");
  const [months, setMonths] = useState([]);
  const [rawRows, setRawRows] = useState([]);
  const [serverMeta, setServerMeta] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    (async () => {
      try {
        setError("");
        const res = await axios.get(`${API_BASE}/api/business-units`, authHeaders(token));
        setBusinessUnits(res.data || []);
      } catch (err) {
        setError(err.response?.data?.message || err.message);
      }
    })();
  }, [token]);

  useEffect(() => {
    (async () => {
      try {
        setError("");
        const q = selectedBuId ? `?buId=${encodeURIComponent(selectedBuId)}` : "";
        const res = await axios.get(`${API_BASE}/api/health/prod-servers${q}`, authHeaders(token));
        setProdServers(res.data || []);
      } catch (err) {
        setError(err.response?.data?.message || err.message);
      }
    })();
  }, [token, selectedBuId]);

  useEffect(() => {
    (async () => {
      try {
        setLoading(true);
        setError("");
        const params = new URLSearchParams();
        if (selectedBuId) params.set("buId", selectedBuId);
        if (selectedServerId) params.set("serverId", selectedServerId);
        const q = params.toString() ? `?${params.toString()}` : "";
        const res = await axios.get(`${API_BASE}/api/db-trend${q}`, authHeaders(token));
        setMonths(res.data?.months || []);
        setRawRows(res.data?.rows || []);
        setServerMeta(res.data?.server || null);
      } catch (err) {
        setError(err.response?.data?.message || err.message);
      } finally {
        setLoading(false);
      }
    })();
  }, [token, selectedBuId, selectedServerId]);

  const pivotRows = useMemo(() => {
    const by = new Map();
    for (const r of rawRows || []) {
      const key = `${r.ServerName}||${r.SQLInstanceName}||${r.DatabaseName}`;
      if (!by.has(key)) {
        by.set(key, {
          BUName: r.BUName,
          ServerName: r.ServerName,
          Environment: r.Environment,
          SQLInstanceName: r.SQLInstanceName,
          DatabaseName: r.DatabaseName,
          values: {},
        });
      }
      by.get(key).values[r.YearMonth] = r.MaxTotalSizeGB;
    }
    return Array.from(by.values()).sort((a, b) =>
      (a.ServerName || "").localeCompare(b.ServerName || "") ||
      (a.SQLInstanceName || "").localeCompare(b.SQLInstanceName || "") ||
      (a.DatabaseName || "").localeCompare(b.DatabaseName || "")
    );
  }, [rawRows]);

  const tableRows = useMemo(() => {
    const ms = months || [];
    const startYm = ms[0]?.ym || null;
    const endYm = ms[ms.length - 1]?.ym || null;
    return pivotRows.map((r) => {
      const start = startYm ? (r.values[startYm] ?? null) : null;
      const end = endYm ? (r.values[endYm] ?? null) : null;
      let pct = null;
      if (start != null && end != null) {
        const s = Number(start);
        const e = Number(end);
        if (!Number.isNaN(s) && !Number.isNaN(e) && s > 0) pct = ((e - s) / s) * 100.0;
      }
      return { ...r, pctChange6m: pct };
    });
  }, [pivotRows, months]);

  if (loading) return <div className="app-shell">Loading database trend...</div>;
  if (error) return <div className="app-shell"><div className="alert error">{error}</div></div>;

  return (
    <div className="app-shell">
      <header className="hero">
        <h1>SQL Server Inventory Management Portal</h1>
        <h3>Database Trend</h3>
        <p>Six-month comparison of monthly maximum database size, based on daily snapshots.</p>
        <div className="hero-actions">
          <div className="top-nav">
            <a href="/dashboard">Dashboard</a>
            <a href="/health">Health Report</a>
            <a href="/serverlist">Server List</a>
            <a href="/databaselist">Database List</a>
            <a href="/databasetrend" className="active-link">Database Trend</a>
            {role === "admin" ? <a href="/inventory">Inventory Form</a> : null}
          </div>
          <span>Logged in as: <strong>{username}</strong></span>
          <button type="button" onClick={onLogout}>Logout</button>
        </div>
      </header>

      <section className="dash-card" style={{ marginTop: 12 }}>
        <div className="search-row">
          <div className="search-box">
            <label>Business Unit</label>
            <select
              value={selectedBuId}
              onChange={(e) => {
                setSelectedBuId(e.target.value);
                setSelectedServerId("");
              }}
            >
              <option value="">Select Business Unit</option>
              {(businessUnits || []).map((bu) => (
                <option key={bu.id} value={bu.id}>{bu.name}</option>
              ))}
            </select>
          </div>
          <div className="search-box">
            <label>PROD Server</label>
            <select value={selectedServerId} onChange={(e) => setSelectedServerId(e.target.value)}>
              <option value="">Select Server</option>
              {(prodServers || []).map((s) => (
                <option key={s.id} value={s.id}>{s.name}</option>
              ))}
            </select>
          </div>
        </div>
      </section>

      {!selectedBuId || !selectedServerId ? (
        <section className="card" style={{ marginTop: 16 }}>
          <div>Select a BU and PROD Server to view Database Size Trend Report.</div>
        </section>
      ) : (
        <>
          <section className="card" style={{ marginTop: 16 }}>
            <h2 style={{ textAlign: "center", fontSize: 34, margin: "6px 0 2px" }}>{serverMeta?.ServerName || ""}</h2>
            <p className="brand-sub" style={{ textAlign: "center", marginTop: 0 }}>
              {(serverMeta?.BUName || "")} | {(serverMeta?.EnvName || "")}
            </p>
            {serverMeta?.Description ? (
              <p className="brand-sub" style={{ textAlign: "center", marginTop: -4 }}>
                {serverMeta.Description}
              </p>
            ) : null}
          </section>

          <section className="card">
            <div className="search-row" style={{ alignItems: "end" }}>
              <div>
                <h2 style={{ marginBottom: 0 }}>Database Size Trend (Last 6 Months)</h2>
                <p className="brand-sub" style={{ marginTop: 6 }}>
                  Monthly maximum size derived from daily snapshots.
                </p>
              </div>
              <div className="search-inline" style={{ justifyContent: "flex-end" }}>
                <button
                  type="button"
                  onClick={() => {
                    const cols = [
                      { header: "SQLInstance", key: "SQLInstanceName" },
                      { header: "Database", key: "DatabaseName" },
                      ...(months || []).map((m) => ({ header: m.label, key: m.ym })),
                      { header: "PctChange6M", key: "PctChange6M" },
                    ];
                    const out = tableRows.map((r) => {
                      const row = {
                        SQLInstanceName: r.SQLInstanceName,
                        DatabaseName: r.DatabaseName,
                        PctChange6M: r.pctChange6m == null ? "" : r.pctChange6m.toFixed(2),
                      };
                      for (const m of months || []) row[m.ym] = r.values[m.ym] == null ? "" : Number(r.values[m.ym]).toFixed(2);
                      return row;
                    });
                    downloadCsv(`dbtrend_${new Date().toISOString().slice(0, 10)}.csv`, out, cols);
                  }}
                >
                  Export CSV
                </button>
              </div>
            </div>

            <div className="table-wrap">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>SQL Instance</th>
                    <th>Database</th>
                    {(months || []).map((m) => (
                      <th key={m.ym}>{m.label}</th>
                    ))}
                    <th>% Change (6M)</th>
                  </tr>
                </thead>
                <tbody>
                  {tableRows.map((r, idx) => (
                    <tr key={`trend-${r.ServerName}-${r.SQLInstanceName}-${r.DatabaseName}-${idx}`}>
                      <td>{r.SQLInstanceName}</td>
                      <td>{r.DatabaseName}</td>
                      {(months || []).map((m, mi) => {
                        const cur = r.values[m.ym] ?? null;
                        return (
                          <td key={`${m.ym}-${idx}`}>
                            {cur == null ? "" : Number(cur).toFixed(2)}
                          </td>
                        );
                      })}
                      {(() => {
                        const pct = r.pctChange6m;
                        let style = undefined;
                        if (pct != null) {
                          if (pct > 20) style = { background: "rgba(231, 76, 60, 0.16)" };
                          else style = { background: "rgba(46, 204, 113, 0.18)" };
                        }
                        return (
                          <td style={style}>
                            {pct == null ? "" : `${pct.toFixed(2)}%`}
                          </td>
                        );
                      })()}
                    </tr>
                  ))}
                  {!tableRows.length ? (
                    <tr><td colSpan={3 + (months || []).length} style={{ textAlign: "center", padding: 16 }}>No trend data yet.</td></tr>
                  ) : null}
                </tbody>
              </table>
            </div>
          </section>
        </>
      )}

      <footer className="footer-note">
        <div>Trend uses monthly maximum size derived from daily snapshots (requires scheduled stored procedure runs).</div>
        <div>% Change (6M): red if increase &gt; 20%, otherwise green.</div>
      </footer>
    </div>
  );
}

function HealthReportPage({ token, username, role, onLogout }) {
  const [businessUnits, setBusinessUnits] = useState([]);
  const [prodServers, setProdServers] = useState([]);
  const [selectedBuId, setSelectedBuId] = useState("");
  const [selectedServerId, setSelectedServerId] = useState("");
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const sendEmailReport = async () => {
    if (!selectedServerId) {
      alert("Select a PROD server first.");
      return;
    }

    const recipients = window.prompt("Recipients (separate multiple emails with ;)", "");
    if (recipients === null) return; // cancelled
    if (!String(recipients || "").trim()) {
      alert("Recipients is required.");
      return;
    }

    const ccRecipients = window.prompt("CC Recipients (optional, separate with ;)", "");
    if (ccRecipients === null) return; // cancelled

    if (!window.confirm("Send Health Report email now?")) return;

    try {
      await axios.post(
        `${API_BASE}/api/health/email-report`,
        {
          serverId: Number(selectedServerId),
          recipients: String(recipients).trim(),
          ccRecipients: String(ccRecipients || "").trim(),
        },
        authHeaders(token)
      );
      alert("Email report sent (request accepted).");
    } catch (err) {
      alert(err.response?.data?.message || "Failed to send email report.");
    }
  };

  useEffect(() => {
    (async () => {
      try {
        setError("");
        const res = await axios.get(`${API_BASE}/api/business-units`, authHeaders(token));
        setBusinessUnits(res.data || []);
      } catch (err) {
        setError(err.response?.data?.message || err.message);
      }
    })();
  }, [token]);

  useEffect(() => {
    (async () => {
      try {
        setError("");
        const q = selectedBuId ? `?buId=${encodeURIComponent(selectedBuId)}` : "";
        const res = await axios.get(`${API_BASE}/api/health/prod-servers${q}`, authHeaders(token));
        setProdServers(res.data || []);
      } catch (err) {
        setError(err.response?.data?.message || err.message);
      }
    })();
  }, [token, selectedBuId]);

  useEffect(() => {
    (async () => {
      try {
        setLoading(true);
        setError("");
        if (!selectedServerId) {
          setData(null);
          return;
        }
        const res = await axios.get(`${API_BASE}/api/health/report?serverId=${encodeURIComponent(selectedServerId)}`, authHeaders(token));
        setData(res.data);
      } catch (err) {
        setError(err.response?.data?.message || err.message);
      } finally {
        setLoading(false);
      }
    })();
  }, [token, selectedServerId]);

  if (loading) return <div className="app-shell">Loading health report...</div>;
  if (error) return <div className="app-shell"><div className="alert error">{error}</div></div>;

  return (
    <div className="app-shell">
      <header className="hero">
        <h1>SQL Server Inventory Management Portal</h1>
        <h3>Server Health Check</h3>
        <p>Daily operational view for PROD servers: backups, disk space, and maintenance job status.</p>
        <div className="hero-actions">
          <div className="top-nav">
            <a href="/dashboard">Dashboard</a>
            <a href="/health" className="active-link">Health Report</a>
            <a href="/serverlist">Server List</a>
            <a href="/databaselist">Database List</a>
            <a href="/databasetrend">Database Trend</a>
            {role === "admin" ? <a href="/inventory">Inventory Form</a> : null}
          </div>
          <span>Logged in as: <strong>{username}</strong></span>
          <button type="button" onClick={onLogout}>Logout</button>
        </div>
      </header>

      <section className="dash-card" style={{ marginTop: 12 }}>
        <div className="search-row">
          <div className="search-box">
            <label>Business Unit</label>
            <select
              value={selectedBuId}
              onChange={(e) => {
                setSelectedBuId(e.target.value);
                setSelectedServerId("");
              }}
            >
              <option value="">Select Business Unit</option>
              {(businessUnits || []).map((bu) => (
                <option key={bu.id} value={bu.id}>{bu.name}</option>
              ))}
            </select>
          </div>
          <div className="search-box">
            <label>PROD Server</label>
            <select value={selectedServerId} onChange={(e) => setSelectedServerId(e.target.value)}>
              <option value="">Select Server</option>
              {(prodServers || []).map((s) => (
                <option key={s.id} value={s.id}>{s.name}</option>
              ))}
            </select>
          </div>
        </div>
      </section>

      {data ? (
        <>
          <section className="card" style={{ marginTop: 16 }}>
            <h2 style={{ textAlign: "center", fontSize: 34, margin: "6px 0 2px" }}>{data.server?.ServerName || ""}</h2>
            <p className="brand-sub" style={{ textAlign: "center", marginTop: 0 }}>
              {data.server?.BusinessUnitName || ""} | {data.server?.EnvName || ""}
            </p>
            {data.server?.Description ? (
              <p className="brand-sub" style={{ textAlign: "center", marginTop: -4 }}>
                {data.server.Description}
              </p>
            ) : null}
            <div style={{ display: "flex", justifyContent: "center", marginTop: 10 }}>
              <button
                type="button"
                onClick={() => {
                  const serverName = data.server?.ServerName || "server";
                  const today = new Date().toISOString().slice(0, 10);
                  const sections = [
                    {
                      title: "Backup Summary",
                      subtitle: "Druva Backup summary report from last 24 hours",
                      columns: [
                        { header: "BackupType", key: "BackupType" },
                        { header: "Successful", key: "Successful" },
                        { header: "Failed", key: "Failed" },
                      ],
                      rows: data.backupSummary || [],
                    },
                    {
                      title: "Recent Backups By Database",
                      columns: [
                        { header: "SQLInstanceName", key: "SQLInstanceName" },
                        { header: "DatabaseName", key: "DatabaseName" },
                        { header: "RecentFullBackupDate", key: "RecentFullBackupDate" },
                        { header: "RecentDiffBackupDate", key: "RecentDiffBackupDate" },
                      ],
                      rows: (data.backupByDb || []).map((r) => ({
                        ...r,
                        RecentFullBackupDate: fmtDateTime(r.RecentFullBackupDate),
                        RecentDiffBackupDate: fmtDateTime(r.RecentDiffBackupDate),
                      })),
                    },
                    {
                      title: "Disk Space Details (SQL Disks Only)",
                      columns: [
                        { header: "DriveLetter", key: "DriveLetter" },
                        { header: "VolumeLabel", key: "VolumeLabel" },
                        { header: "TotalSizeGB", key: "TotalSizeGB" },
                        { header: "FreeSpaceGB", key: "FreeSpaceGB" },
                        { header: "FreePct", key: "FreePct" },
                      ],
                      rows: data.disk || [],
                    },
                    {
                      title: "Maintenance Job Details (Latest Snapshot)",
                      columns: [
                        { header: "SQLInstanceName", key: "SQLInstanceName" },
                        { header: "JobName", key: "JobName" },
                        { header: "LastRunDateTime", key: "LastRunDateTime" },
                        { header: "LastRunDurationSec", key: "LastRunDurationSec" },
                        { header: "LastRunStatus", key: "LastRunStatus" },
                      ],
                      rows: (data.jobs || []).map((r) => ({
                        ...r,
                        LastRunDateTime: fmtDateTime(r.LastRunDateTime),
                      })),
                    },
                  ];
                  downloadCsvSections(`healthreport_${serverName}_${today}.csv`, sections);
                }}
              >
                Export All (CSV)
              </button>
              <button
                type="button"
                style={{ marginLeft: 10 }}
                onClick={sendEmailReport}
              >
                Send Email Report
              </button>
            </div>
          </section>

          <section className="card">
            <h2>Database Backup Details</h2>
            <p className="brand-sub" style={{ marginTop: -6 }}>
              Druva Backup summary report from last 24 hours
            </p>
            <div className="table-wrap">
              <table className="data-table">
                <thead>
                  <tr><th>Backup Type</th><th>Successful</th><th>Failed</th></tr>
                </thead>
                <tbody>
                  {(() => {
                    const rows = data.backupSummary || [];
                    const totalSuccessful = rows.reduce((a, x) => a + (Number(x.Successful) || 0), 0);
                    const totalFailed = rows.reduce((a, x) => a + (Number(x.Failed) || 0), 0);
                    const successStyle = { background: "rgba(46, 204, 113, 0.18)", fontWeight: 700 };
                    const failStyle = (n) => (Number(n) > 0 ? { background: "rgba(231, 76, 60, 0.16)", fontWeight: 700 } : { background: "rgba(149, 165, 166, 0.12)", fontWeight: 700 });
                    const totalStyle = { background: "rgba(52, 152, 219, 0.14)", fontWeight: 800 };

                    return (
                      <>
                        {rows.map((r, idx) => (
                          <tr key={`bks-${idx}`}>
                            <td>{r.BackupType}</td>
                            <td style={successStyle}>{r.Successful}</td>
                            <td style={failStyle(r.Failed)}>{r.Failed}</td>
                          </tr>
                        ))}
                        {rows.length ? (
                          <tr>
                            <td><strong>Total</strong></td>
                            <td style={totalStyle}>{totalSuccessful}</td>
                            <td style={totalStyle}>{totalFailed}</td>
                          </tr>
                        ) : null}
                      </>
                    );
                  })()}
                  {!(data.backupSummary || []).length ? <tr><td colSpan={3} style={{ textAlign: "center" }}>No backup rows found.</td></tr> : null}
                </tbody>
              </table>
            </div>

            <div className="table-wrap" style={{ marginTop: 12 }}>
              <table className="data-table">
                <thead>
                  <tr><th>SQL Instance</th><th>DatabaseName</th><th>RecentFullBackupDate</th><th>RecentDiffBackupDate</th></tr>
                </thead>
                <tbody>
                  {(data.backupByDb || []).map((r, idx) => (
                    <tr key={`bkdb-${idx}`}>
                      <td>{r.SQLInstanceName}</td>
                      <td>{r.DatabaseName}</td>
                      <td>{fmtDateTime(r.RecentFullBackupDate)}</td>
                      <td>{fmtDateTime(r.RecentDiffBackupDate)}</td>
                    </tr>
                  ))}
                  {!(data.backupByDb || []).length ? <tr><td colSpan={4} style={{ textAlign: "center" }}>No per-database backup rows found.</td></tr> : null}
                </tbody>
              </table>
            </div>
          </section>

          <section className="card">
            <h2>Disk Space Details</h2>
            <p className="brand-sub" style={{ marginTop: -6 }}>
              Disk space details for disk containing SQL files only(mdf/ldf). For OS and Backup disks or any additional storage history detail refer site 24x7.
            </p>
            <div className="table-wrap">
              <table className="data-table">
                <thead>
                  <tr><th>Drive</th><th>Volume Label</th><th>Total (GB)</th><th>Free (GB)</th><th>Free (%)</th></tr>
                </thead>
                <tbody>
                  {(data.disk || []).map((r, idx) => (
                    <tr key={`disk-${idx}`}>
                      <td>{r.DriveLetter}</td>
                      <td>{r.VolumeLabel || ""}</td>
                      <td>{r.TotalSizeGB}</td>
                      <td>{r.FreeSpaceGB}</td>
                      {(() => {
                        const pct = r.FreePct == null ? null : Number(r.FreePct);
                        let style = undefined;
                        if (pct != null && !Number.isNaN(pct)) {
                          if (pct < 10) style = { background: "rgba(231, 76, 60, 0.16)", fontWeight: 700 };
                          else if (pct < 20) style = { background: "rgba(241, 196, 15, 0.20)", fontWeight: 700 };
                        }
                        return <td style={style}>{r.FreePct ?? ""}</td>;
                      })()}
                    </tr>
                  ))}
                  {!(data.disk || []).length ? <tr><td colSpan={5} style={{ textAlign: "center" }}>No disk rows found.</td></tr> : null}
                </tbody>
              </table>
            </div>
          </section>

          <section className="card">
            <h2>Maintenance Job Details</h2>
            <p className="brand-sub" style={{ marginTop: -6 }}>
              Latest status of DBA jobs such as Maintenance/Backups/Monitoring, etc.
            </p>
            <div className="table-wrap">
              <table className="data-table">
                <thead>
                  <tr><th>SQL Instance</th><th>Job Name</th><th>Last Run</th><th>Duration (sec)</th><th>Status</th></tr>
                </thead>
                <tbody>
                  {(data.jobs || []).map((r, idx) => (
                    <tr key={`job-${idx}`}>
                      <td>{r.SQLInstanceName}</td>
                      <td>{r.JobName}</td>
                      <td>{fmtDate(r.LastRunDateTime)}</td>
                      <td>{r.LastRunDurationSec ?? ""}</td>
                      {(() => {
                        const st = String(r.LastRunStatus || "");
                        const stLower = st.toLowerCase();
                        const isFail = stLower.includes("fail") || stLower.includes("canceled") || stLower.includes("retry");
                        const style = isFail ? { background: "rgba(231, 76, 60, 0.16)", fontWeight: 700 } : undefined;
                        return <td style={style}>{st}</td>;
                      })()}
                    </tr>
                  ))}
                  {!(data.jobs || []).length ? <tr><td colSpan={5} style={{ textAlign: "center" }}>No job rows found.</td></tr> : null}
                </tbody>
              </table>
            </div>
          </section>
        </>
      ) : (
        <section className="card" style={{ marginTop: 16 }}>
          <div>Select a BU and PROD server to view the daily health report.</div>
        </section>
      )}

      <footer className="footer-note">
        <div>Health data depends on scheduled collection stored procedures (hourly refresh).</div>
        <div>Backup table stores successful backups from msdb; failed counts are reported as 0 unless extended logic is added.</div>
      </footer>
    </div>
  );
}

function fmtDate(v) {
  if (!v) return "";
  const s = String(v);
  return s.length >= 10 ? s.slice(0, 10) : s;
}

function fmtDateTime(v) {
  if (!v) return "";
  const s = String(v);
  // Handles "2026-03-19T06:00:09.000Z" or "2026-03-19 06:00:09.000"
  if (s.includes("T")) return s.replace("T", " ").slice(0, 19);
  return s.length >= 19 ? s.slice(0, 19) : s;
}

function ServerDetailsPage({ token, username, role, onLogout, serverId }) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    (async () => {
      try {
        setLoading(true);
        setError("");
        const res = await axios.get(`${API_BASE}/api/server-details/${encodeURIComponent(serverId)}`, authHeaders(token));
        setData(res.data);
      } catch (err) {
        setError(err.response?.data?.message || err.message);
      } finally {
        setLoading(false);
      }
    })();
  }, [token, serverId]);

  if (loading) return <div className="app-shell">Loading server details...</div>;
  if (error) return <div className="app-shell"><div className="alert error">{error}</div></div>;
  if (!data) return <div className="app-shell"><div className="alert error">No data.</div></div>;

  const os = data.osDetails || {};
  const other = data.otherDetails || {};
  const instances = data.sqlInstanceDetails || [];

  return (
    <div className="app-shell">
      <header className="hero">
        <h1>SQL Server Inventory</h1>
        <h3>Server Detail View</h3>
        <p>Single-server overview across OS, network, SQL instances, storage, and support ownership.</p>
        <div className="hero-actions">
          <div className="top-nav">
            <a href="/dashboard">Dashboard</a>
            <a href="/health">Health Report</a>
            <a href="/serverlist">Server List</a>
            <a href="/databaselist">Database List</a>
            <a href="/databasetrend">Database Trend</a>
            {role === "admin" ? <a href="/inventory">Inventory Form</a> : null}
          </div>
          <span>Logged in as: <strong>{username}</strong></span>
          <button type="button" onClick={onLogout}>Logout</button>
        </div>
      </header>

      <div style={{ textAlign: "center", fontSize: 34, fontWeight: 800, margin: "8px 0 18px" }}>
        {data.serverName}
      </div>

      <section className="card">
        <h2>OS Details</h2>
        <div className="table-wrap">
          <table className="data-table">
            <tbody>
              <tr><td><strong>Server Status</strong></td><td>{os.StatusName || ""}</td></tr>
              <tr><td><strong>Business Unit</strong></td><td><BuLogo name={os.BusinessUnitName} /> {os.BusinessUnitName || ""}</td></tr>
              <tr><td><strong>Description</strong></td><td>{os.Description || ""}</td></tr>
              <tr><td><strong>Environment</strong></td><td>{os.EnvName || ""}</td></tr>
              <tr><td><strong>Category</strong></td><td>{os.CategoryName || ""}</td></tr>
              <tr><td><strong>Region</strong></td><td>{os.RegionName || ""}</td></tr>
              <tr><td><strong>Platform</strong></td><td>{os.PlatformName || ""}</td></tr>
              <tr><td><strong>Server Type</strong></td><td>{os.ServerType || ""}</td></tr>
              <tr><td><strong>Operating System</strong></td><td>{os.OperatingSystem || ""}</td></tr>
              <tr><td><strong>OS Category</strong></td><td>{os.OSCategory || ""}</td></tr>
              <tr><td><strong>CPU Cores</strong></td><td>{os.CPUCores ?? ""}</td></tr>
              <tr><td><strong>RAM (GB)</strong></td><td>{os.MemoryGB ?? ""}</td></tr>
              <tr><td><strong>Processor</strong></td><td>{os.ProcessorModel || ""}</td></tr>
              <tr><td><strong>Domain</strong></td><td>{os.DomainName || ""}</td></tr>
              <tr><td><strong>TimeZone</strong></td><td>{os.Timezone || ""}</td></tr>
            </tbody>
          </table>
        </div>
      </section>

      <section className="card">
        <h2>Network Details</h2>
        <div className="table-wrap">
          <table className="data-table">
            <thead>
              <tr><th>Type</th><th>IP Address</th></tr>
            </thead>
            <tbody>
              {(data.networkDetails || []).map((r, idx) => (
                <tr key={`ip-${idx}`}><td>{r.TypeName}</td><td>{r.IPAddress}</td></tr>
              ))}
              {!(data.networkDetails || []).length ? <tr><td colSpan={2} style={{ textAlign: "center" }}>No IP rows</td></tr> : null}
            </tbody>
          </table>
        </div>
      </section>

      <section className="card">
        <h2>SQL Instance Details</h2>
        {instances.length ? instances.map((inst, idx) => (
          <div key={`inst-${inst.SQLInstanceID || idx}`} className="card" style={{ marginTop: 10 }}>
            <h3>Instance #{idx + 1}: {inst.InstanceName}</h3>
            <div className="table-wrap">
              <table className="data-table">
                <tbody>
                  <tr><td><strong>SQL Instance Name</strong></td><td>{inst.InstanceName || ""}</td></tr>
                  <tr><td><strong>SQL Instance Type</strong></td><td>{inst.InstanceTypeName || ""}</td></tr>
                  <tr><td><strong>SQL Install Date</strong></td><td>{fmtDate(inst.SQLInstallDate)}</td></tr>
                  <tr><td><strong>SQL Version</strong></td><td>{inst.SQLVersionName || ""}</td></tr>
                  <tr><td><strong>SQL Edition</strong></td><td>{inst.SQLEditionName || ""}</td></tr>
                  <tr><td><strong>Product Build</strong></td><td>{inst.ProductBuild || ""}</td></tr>
                  <tr><td><strong>Product Level</strong></td><td>{inst.ProductLevel || ""}</td></tr>
                  <tr><td><strong>Patch Effective Date</strong></td><td>{fmtDate(inst.VersionEffectiveDate)}</td></tr>
                  <tr><td><strong>SQL Collation</strong></td><td>{inst.InstanceCollationName || ""}</td></tr>
                  <tr><td><strong>Min Memory (MB)</strong></td><td>{inst.MinMemoryMB ?? ""}</td></tr>
                  <tr><td><strong>Max Memory (MB)</strong></td><td>{inst.MaxMemoryMB ?? ""}</td></tr>
                  <tr><td><strong>MaxDOP</strong></td><td>{inst.MaxDOP ?? ""}</td></tr>
                  <tr><td><strong>Cost Threshold</strong></td><td>{inst.CostThresholdParallelism ?? ""}</td></tr>
                  <tr><td><strong>Adhoc Workload</strong></td><td>{inst.AdhocWorkload ? "Enabled" : "Disabled"}</td></tr>
                  <tr><td><strong>Lock Page In Memory</strong></td><td>{inst.LockPageInMemory ? "Enabled" : "Disabled"}</td></tr>
                  <tr><td><strong>IFI</strong></td><td>{inst.IFI ? "Enabled" : "Disabled"}</td></tr>
                  <tr><td><strong>Database Mail</strong></td><td>{inst.DatabaseMail ? "Enabled" : "Disabled"}</td></tr>
                  <tr><td><strong>FileStream</strong></td><td>{inst.FileStream ? "Enabled" : "Disabled"}</td></tr>
                </tbody>
              </table>
            </div>

            <div className="card" style={{ marginTop: 10 }}>
              <h4>Database Details</h4>
              <p className="brand-sub" style={{ marginTop: -6 }}>Limited view: Name, Size, and Recovery model.</p>
              <div className="table-wrap">
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>DatabaseName</th>
                      <th>SizeGB</th>
                      <th>RecoveryModel</th>
                    </tr>
                  </thead>
                  <tbody>
                    {(inst.Databases || inst.databases || []).map((db, di) => (
                      <tr key={`instdb-${inst.SQLInstanceID || idx}-${di}`}>
                        <td>{db.DatabaseName || db.databaseName || ""}</td>
                        <td>{db.SizeGB ?? db.sizeGB ?? ""}</td>
                        <td>{db.RecoveryModel || db.recoveryModel || ""}</td>
                      </tr>
                    ))}
                    {!(inst.Databases || inst.databases || []).length ? (
                      <tr><td colSpan={3} style={{ textAlign: "center" }}>No database rows</td></tr>
                    ) : null}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )) : <div className="alert error">No SQL instances found.</div>}
      </section>

      <section className="card">
        <h2>Storage Details</h2>
        <div className="table-wrap">
          <table className="data-table">
            <thead>
              <tr><th>Drive</th><th>Volume Label</th><th>Total (GB)</th><th>Free (GB)</th><th>Free (%)</th></tr>
            </thead>
            <tbody>
              {(data.storageDetails || []).map((r, idx) => (
                <tr key={`st-${idx}`}>
                  <td>{r.DriveLetter}</td>
                  <td>{r.VolumeLabel || ""}</td>
                  <td>{r.TotalSizeGB}</td>
                  <td>{r.FreeSpaceGB}</td>
                  <td>{r.FreeSpacePct ?? ""}</td>
                </tr>
              ))}
              {!(data.storageDetails || []).length ? <tr><td colSpan={5} style={{ textAlign: "center" }}>No storage rows</td></tr> : null}
            </tbody>
          </table>
        </div>
      </section>

      <section className="card">
        <h2>Support Contact</h2>
        <p className="brand-sub" style={{ marginTop: -6 }}>
          Source: <strong>{String(data.contactSource || "server").toLowerCase() === "bu" ? "BU Default" : "Server Specific"}</strong>
        </p>
        <div className="table-wrap">
          <table className="data-table">
            <thead>
              <tr><th>Role</th><th>Name</th><th>Email</th><th>Phone</th></tr>
            </thead>
            <tbody>
              {(data.supportContacts || []).map((r, idx) => (
                <tr key={`ct-${idx}`}>
                  <td>{r.ContactCategoryName}</td>
                  <td>{r.ContactName}</td>
                  <td>{r.Email || ""}</td>
                  <td>{r.Phone || ""}</td>
                </tr>
              ))}
              {!(data.supportContacts || []).length ? <tr><td colSpan={4} style={{ textAlign: "center" }}>No contacts</td></tr> : null}
            </tbody>
          </table>
        </div>
      </section>

      <section className="card">
        <h2>Other Details</h2>
        <div className="table-wrap">
          <table className="data-table">
            <tbody>
              <tr><td><strong>Server Effective From</strong></td><td>{fmtDate(other.serverEffectiveFrom)}</td></tr>
              <tr><td><strong>OS Install Date</strong></td><td>{fmtDate(other.osInstallDate)}</td></tr>
              <tr><td><strong>SQL Install Date</strong></td><td>{fmtDate(other.sqlInstallDate)}</td></tr>
              <tr><td><strong>Recent Patch Applied On</strong></td><td>{fmtDate(other.recentPatchAppliedOn)}</td></tr>
            </tbody>
          </table>
        </div>
      </section>

      <footer className="footer-note">
        <div>Details are pulled from current rows (IsCurrent=1) and active entities.</div>
        <div>For edit/update operations, use the Inventory Form (admin only).</div>
      </footer>
    </div>
  );
}

function App() {
  const pathname = typeof window !== "undefined" ? window.location.pathname.toLowerCase() : "/";
  const isDashboardRoute = pathname.startsWith("/dashboard") || pathname === "/" || pathname === "/login";
  const isHealthRoute = pathname.startsWith("/health");
  const isServerListRoute = pathname.startsWith("/serverlist");
  const isDatabaseListRoute = pathname.startsWith("/databaselist");
  const isDatabaseTrendRoute = pathname.startsWith("/databasetrend");
  const parts = pathname.split("/").filter(Boolean);
  const isServerDetailsRoute = parts[0] === "server" && parts[1] && /^\d+$/.test(parts[1]);
  const serverDetailsId = isServerDetailsRoute ? Number(parts[1]) : null;
  const isInventoryRoute = pathname.startsWith("/inventory");
  const [activeTab, setActiveTab] = useState("Server");
  const [mode, setMode] = useState("create");
  const [editServerId, setEditServerId] = useState("");
  const [servers, setServers] = useState([]);
  const [lookups, setLookups] = useState({});
  const [form, setForm] = useState(baseForm());
  const [loading, setLoading] = useState(true);
  const [errors, setErrors] = useState([]);
  const [msg, setMsg] = useState({ type: "", text: "" });
  const [saving, setSaving] = useState(false);

  const [token, setToken] = useState(getAuthData().token || "");
  const [username, setUsername] = useState(getAuthData().username || "");
  const [role, setRole] = useState(getAuthData().role || "");
  const [loginBusy, setLoginBusy] = useState(false);
  const [loginError, setLoginError] = useState("");

  useEffect(() => {
    if (!token) {
      setLoading(false);
      return;
    }
    bootstrap();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token]);

  useEffect(() => {
    if (token && (pathname === "/" || pathname === "/login")) {
      window.history.replaceState({}, "", "/dashboard");
    }
  }, [token, pathname]);

  // When using BU defaults, load the BU contact set for display (admin only - form is admin-only anyway).
  useEffect(() => {
    if (!token || role !== "admin") return;
    if (form.contactMode !== "bu") return;
    const buId = form.server.buId;
    if (!buId) {
      setForm((p) => ({ ...p, buDefaultContacts: [] }));
      return;
    }

    (async () => {
      try {
        const res = await axios.get(`${API_BASE}/api/bu-default-contacts/${encodeURIComponent(buId)}`, authHeaders(token));
        const list = (res.data || []).map((x) => ({
          contactName: x.ContactName,
          email: x.Email || "",
          phone: x.Phone || "",
          contactCategoryId: String(x.ContactCategoryID || ""),
        }));
        setForm((p) => ({ ...p, buDefaultContacts: list }));
      } catch {
        // best-effort display only
      }
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token, role, form.contactMode, form.server.buId]);

  async function bootstrap() {
    try {
      setLoading(true);
      const meRes = await axios.get(`${API_BASE}/api/auth/me`, authHeaders(token));
      const user = meRes.data.user?.username || username;
      const userRole = (meRes.data.user?.role || role || "readonly").toLowerCase();
      setUsername(user);
      setRole(userRole);
      setAuthData(token, user, userRole);
      if (userRole === "admin") {
        const [lookupRes, serverRes] = await Promise.all([
          axios.get(`${API_BASE}/api/lookups`, authHeaders(token)),
          axios.get(`${API_BASE}/api/servers`, authHeaders(token)),
        ]);
        setLookups(lookupRes.data);
        setServers(serverRes.data);
      } else {
        setLookups({});
        setServers([]);
      }
      setForm(baseForm(user));
      setLoginError("");
    } catch (err) {
      clearAuthData();
      setToken("");
      setUsername("");
      setRole("");
      setLoginError("Session expired. Please sign in again.");
    } finally {
      setLoading(false);
    }
  }

  async function handleLogin(user, pass) {
    try {
      setLoginBusy(true);
      setLoginError("");
      const res = await axios.post(`${API_BASE}/api/auth/login`, { username: user, password: pass });
      const newToken = res.data.token;
      const uname = res.data.user.username;
      const userRole = (res.data.user.role || "readonly").toLowerCase();
      setAuthData(newToken, uname, userRole);
      setToken(newToken);
      setUsername(uname);
      setRole(userRole);
      window.location.assign("/dashboard");
    } catch (err) {
      setLoginError(err.response?.data?.message || "Login failed");
    } finally {
      setLoginBusy(false);
    }
  }

  function handleLogout() {
    clearAuthData();
    setToken("");
    setUsername("");
    setRole("");
    setLookups({});
    setServers([]);
    setForm(baseForm());
  }

  const options = useMemo(() => lookups, [lookups]);
  const setSection = (section, key, value) => setForm((p) => ({ ...p, [section]: { ...p[section], [key]: value } }));
  const setArrayValue = (section, index, key, value) =>
    setForm((p) => {
      const copy = [...p[section]];
      copy[index] = { ...copy[index], [key]: value };
      return { ...p, [section]: copy };
    });
  const setInstanceDbValue = (instIndex, dbIndex, key, value) =>
    setForm((p) => {
      const sqlInstances = [...p.sqlInstances];
      const inst = { ...sqlInstances[instIndex] };
      const dbs = [...(inst.databases || [])];
      dbs[dbIndex] = { ...(dbs[dbIndex] || { ...emptyDatabase }), [key]: value };
      inst.databases = dbs;
      sqlInstances[instIndex] = inst;
      return { ...p, sqlInstances };
    });
  const addInstanceDb = (instIndex) =>
    setForm((p) => {
      const sqlInstances = [...p.sqlInstances];
      const inst = { ...sqlInstances[instIndex] };
      inst.databases = [...(inst.databases || []), { ...emptyDatabase }];
      sqlInstances[instIndex] = inst;
      return { ...p, sqlInstances };
    });
  const removeInstanceDb = (instIndex, dbIndex) =>
    setForm((p) => {
      const sqlInstances = [...p.sqlInstances];
      const inst = { ...sqlInstances[instIndex] };
      const dbs = [...(inst.databases || [])];
      dbs.splice(dbIndex, 1);
      inst.databases = dbs.length ? dbs : [{ ...emptyDatabase }];
      sqlInstances[instIndex] = inst;
      return { ...p, sqlInstances };
    });
  const addRow = (section, item) => setForm((p) => ({ ...p, [section]: [...p[section], { ...item }] }));
  const removeRow = (section, index) =>
    setForm((p) => {
      const copy = [...p[section]];
      copy.splice(index, 1);
      const fallback =
        section === "serverIPs"
          ? emptyIp
          : section === "serverStorages"
            ? emptyStorage
            : section === "sqlInstances"
              ? newSqlInstance()
              : emptyContact;
      return { ...p, [section]: copy.length ? copy : [{ ...fallback }] };
    });

  const toInt = (v) => (v === "" || v === null || v === undefined ? null : Number(v));
  const clean = (v) => (v || "").trim();

  const validate = () => {
    const e = [];
    const { server, serverHardware, sqlInstances, serverIPs, serverStorages } = form;
    if (!clean(server.serverName)) e.push("Server Name is required.");
    ["envId", "buId", "categoryId", "regionId", "statusId"].forEach((k) => !server[k] && e.push(`Server ${k} is required.`));
    ["domainId", "operatingSystemId", "memoryGB", "cpuCores", "serverTypeId", "platformId", "timezoneId"].forEach((k) => !serverHardware[k] && e.push(`Hardware ${k} is required.`));
    if (!sqlInstances.length) e.push("At least one SQL instance is required.");
    sqlInstances.forEach((inst, idx) => {
      if (!inst.instanceTypeId) e.push(`SQL Instance row ${idx + 1}: Instance Type is required.`);
      if (!clean(inst.instanceName)) e.push(`SQL Instance row ${idx + 1}: Instance Name is required.`);
      ["sqlVersionId", "sqlEditionId", "productBuild", "productLevel"].forEach((k) => !inst[k] && e.push(`SQL Instance row ${idx + 1}: ${k} is required.`));
      if (!inst.instanceCollationId) e.push(`SQL Instance row ${idx + 1}: SQL Collation is required.`);

      const dbs = inst.databases || [];
      dbs.forEach((db, di) => {
        const any = Boolean(
          clean(db.databaseName) ||
          clean(db.owner) ||
          String(db.sizeGB || "").trim() ||
          String(db.createdOn || "").trim() ||
          clean(db.recoveryModel) ||
          clean(db.databaseCollation) ||
          db.cdc ||
          String(db.compatibilityLevel || "").trim() ||
          db.encryption ||
          db.queryStore ||
          db.autoUpdateStats
        );
        if (!any) return;
        if (!clean(db.databaseName)) e.push(`Instance ${idx + 1} database row ${di + 1}: Database Name is required.`);
        if (String(db.sizeGB || "").trim() && Number(db.sizeGB) < 0) e.push(`Instance ${idx + 1} database row ${di + 1}: SizeGB must be >= 0.`);
        if (String(db.compatibilityLevel || "").trim() && Number(db.compatibilityLevel) < 0) e.push(`Instance ${idx + 1} database row ${di + 1}: CompatibilityLevel must be >= 0.`);
      });
    });
    if (!serverIPs.length) e.push("At least one IP row is required.");
    if (!serverStorages.length) e.push("At least one storage row is required.");
    serverStorages.forEach((r, i) => Number(r.freeSpaceGB) > Number(r.totalSizeGB) && e.push(`Storage row ${i + 1}: free space cannot exceed total size.`));
    return e;
  };

  const payload = () => ({
    contactMode: form.contactMode,
    server: {
      serverName: clean(form.server.serverName),
      description: clean(form.server.description) || null,
      envId: Number(form.server.envId),
      buId: Number(form.server.buId),
      categoryId: Number(form.server.categoryId),
      regionId: Number(form.server.regionId),
      statusId: Number(form.server.statusId),
      createdBy: username,
    },
    serverHardware: {
      domainId: Number(form.serverHardware.domainId),
      operatingSystemId: Number(form.serverHardware.operatingSystemId),
      memoryGB: Number(form.serverHardware.memoryGB),
      cpuCores: Number(form.serverHardware.cpuCores),
      processorModel: clean(form.serverHardware.processorModel) || null,
      serverTypeId: Number(form.serverHardware.serverTypeId),
      platformId: Number(form.serverHardware.platformId),
      timezoneId: Number(form.serverHardware.timezoneId),
      osInstallDate: form.serverHardware.osInstallDate || null,
      effectiveDate: form.serverHardware.effectiveDate || null,
    },
    sqlInstances: form.sqlInstances.map((inst) => ({
      instanceName: clean(inst.instanceName),
      instanceTypeId: Number(inst.instanceTypeId),
      sqlInstallDate: inst.sqlInstallDate || null,
      sqlVersionId: Number(inst.sqlVersionId),
      sqlEditionId: Number(inst.sqlEditionId),
      productBuild: clean(inst.productBuild),
      productLevel: clean(inst.productLevel),
      versionEffectiveDate: inst.versionEffectiveDate || null,
      instanceCollationId: Number(inst.instanceCollationId),
      minMemoryMB: toInt(inst.minMemoryMB),
      maxMemoryMB: toInt(inst.maxMemoryMB),
      maxDOP: toInt(inst.maxDOP),
      costThresholdParallelism: toInt(inst.costThresholdParallelism),
      adhocWorkload: Boolean(inst.adhocWorkload),
      lockPageInMemory: Boolean(inst.lockPageInMemory),
      ifi: Boolean(inst.ifi),
      databaseMail: Boolean(inst.databaseMail),
      fileStream: Boolean(inst.fileStream),
      configEffectiveDate: inst.configEffectiveDate || null,
      databases: (inst.databases || [])
        .filter((db) => clean(db.databaseName))
        .map((db) => ({
          databaseName: clean(db.databaseName),
          owner: clean(db.owner) || null,
          sizeGB: String(db.sizeGB || "").trim() === "" ? null : Number(db.sizeGB),
          createdOn: db.createdOn || null,
          recoveryModel: clean(db.recoveryModel) || null,
          databaseCollation: clean(db.databaseCollation) || null,
          cdc: Boolean(db.cdc),
          compatibilityLevel: toInt(db.compatibilityLevel),
          encryption: Boolean(db.encryption),
          queryStore: Boolean(db.queryStore),
          autoUpdateStats: Boolean(db.autoUpdateStats),
          isActive: db.isActive !== false,
        })),
    })),
    serverIPs: form.serverIPs.map((i) => ({ ipAddress: clean(i.ipAddress), ipAddressTypeId: Number(i.ipAddressTypeId), isActive: i.isActive !== false })),
    serverStorages: form.serverStorages.map((s) => ({
      driveLetter: clean(s.driveLetter).toUpperCase(),
      volumeLabel: clean(s.volumeLabel) || null,
      totalSizeGB: Number(s.totalSizeGB),
      freeSpaceGB: Number(s.freeSpaceGB),
      isActive: s.isActive !== false,
    })),
    contacts:
      form.contactMode === "custom"
        ? (form.contacts || [])
            .filter((c) => clean(c.contactName) || clean(c.email) || clean(c.phone) || c.contactCategoryId)
            .map((c) => ({
              contactName: clean(c.contactName),
              email: clean(c.email) || null,
              phone: clean(c.phone) || null,
              contactCategoryId: Number(c.contactCategoryId),
            }))
        : [],
  });

  async function resetAfterSave() {
    setForm(baseForm(username));
    setMode("create");
    setEditServerId("");
    setActiveTab("Server");
    const res = await axios.get(`${API_BASE}/api/servers`, authHeaders(token));
    setServers(res.data);
  }

  async function onSave(e) {
    e.preventDefault();
    setMsg({ type: "", text: "" });
    const list = validate();
    setErrors(list);
    if (list.length) return;

    try {
      setSaving(true);
      let res;
      if (mode === "edit" && editServerId) {
        res = await axios.put(`${API_BASE}/api/inventory/${editServerId}`, payload(), authHeaders(token));
      } else {
        res = await axios.post(`${API_BASE}/api/inventory`, payload(), authHeaders(token));
      }
      setMsg({ type: "success", text: `${res.data.message}. Form reset completed.` });
      setErrors([]);
      await resetAfterSave();
    } catch (err) {
      if (err.response?.status === 401) handleLogout();
      const backendErrors = err.response?.data?.errors;
      if (Array.isArray(backendErrors) && backendErrors.length) {
        setErrors(backendErrors);
      }
      setMsg({ type: "error", text: err.response?.data?.error || err.response?.data?.message || err.message });
    } finally {
      setSaving(false);
    }
  }

  async function loadForEdit(serverId) {
    if (!serverId) return;
    try {
      const res = await axios.get(`${API_BASE}/api/inventory/${serverId}`, authHeaders(token));
      const d = res.data;
      const legacySqlInstance =
        d.sqlInstance && (d.sqlInstance.InstanceName || d.sqlInstance.InstanceTypeID)
          ? [
              {
                InstanceName: d.sqlInstance.InstanceName || "",
                InstanceTypeID: d.sqlInstance.InstanceTypeID || "",
                SQLInstallDate: d.sqlInstance.SQLInstallDate || "",
                SQLVersionID: d.sqlInstanceVersion?.SQLVersionID || "",
                SQLEditionID: d.sqlInstanceVersion?.SQLEditionID || "",
                ProductBuild: d.sqlInstanceVersion?.ProductBuild || "",
                ProductLevel: d.sqlInstanceVersion?.ProductLevel || "",
                VersionEffectiveDate: d.sqlInstanceVersion?.EffectiveDate || "",
                InstanceCollationID: d.sqlInstanceConfig?.InstanceCollationID || "",
                MinMemoryMB: d.sqlInstanceConfig?.MinMemoryMB ?? "",
                MaxMemoryMB: d.sqlInstanceConfig?.MaxMemoryMB ?? "",
                MaxDOP: d.sqlInstanceConfig?.MaxDOP ?? "",
                CostThresholdParallelism: d.sqlInstanceConfig?.CostThresholdParallelism ?? "",
                AdhocWorkload: d.sqlInstanceConfig?.AdhocWorkload ?? false,
                LockPageInMemory: d.sqlInstanceConfig?.LockPageInMemory ?? false,
                IFI: d.sqlInstanceConfig?.IFI ?? false,
                DatabaseMail: d.sqlInstanceConfig?.DatabaseMail ?? false,
                FileStream: d.sqlInstanceConfig?.FileStream ?? false,
                ConfigEffectiveDate: d.sqlInstanceConfig?.EffectiveDate || "",
              },
            ]
          : [];

      const sqlRows = (d.sqlInstances && d.sqlInstances.length ? d.sqlInstances : legacySqlInstance).length
        ? (d.sqlInstances && d.sqlInstances.length ? d.sqlInstances : legacySqlInstance)
        : [newSqlInstance()];

      setForm({
        server: {
          serverName: d.server.ServerName || "",
          description: d.server.Description || "",
          envId: String(d.server.EnvID || ""),
          buId: String(d.server.BUID || ""),
          categoryId: String(d.server.CategoryID || ""),
          regionId: String(d.server.RegionID || ""),
          statusId: String(d.server.StatusID || ""),
          createdBy: username,
        },
        serverHardware: {
          domainId: String(d.serverHardware.DomainID || ""),
          operatingSystemId: String(d.serverHardware.OperatingSystemID || ""),
          memoryGB: d.serverHardware.MemoryGB ?? "",
          cpuCores: d.serverHardware.CPUCores ?? "",
          processorModel: d.serverHardware.ProcessorModel || "",
          serverTypeId: String(d.serverHardware.ServerTypeID || ""),
          platformId: String(d.serverHardware.PlatformID || ""),
          timezoneId: String(d.serverHardware.TimezoneID || ""),
          osInstallDate: d.serverHardware.OSInstallDate ? String(d.serverHardware.OSInstallDate).slice(0, 10) : "",
          effectiveDate: d.serverHardware.EffectiveDate ? String(d.serverHardware.EffectiveDate).slice(0, 10) : "",
        },
        sqlInstances: sqlRows.map((inst) => ({
          instanceName: inst.InstanceName || "",
          instanceTypeId: String(inst.InstanceTypeID || ""),
          sqlInstallDate: inst.SQLInstallDate ? String(inst.SQLInstallDate).slice(0, 10) : "",
          sqlVersionId: String(inst.SQLVersionID || ""),
          sqlEditionId: String(inst.SQLEditionID || ""),
          productBuild: inst.ProductBuild || "",
          productLevel: inst.ProductLevel || "",
          versionEffectiveDate: inst.VersionEffectiveDate ? String(inst.VersionEffectiveDate).slice(0, 10) : "",
          instanceCollationId: String(inst.InstanceCollationID || ""),
          minMemoryMB: inst.MinMemoryMB ?? "",
          maxMemoryMB: inst.MaxMemoryMB ?? "",
          maxDOP: inst.MaxDOP ?? "",
          costThresholdParallelism: inst.CostThresholdParallelism ?? "",
          adhocWorkload: Boolean(inst.AdhocWorkload),
          lockPageInMemory: Boolean(inst.LockPageInMemory),
          ifi: Boolean(inst.IFI),
          databaseMail: Boolean(inst.DatabaseMail),
          fileStream: Boolean(inst.FileStream),
          configEffectiveDate: inst.ConfigEffectiveDate ? String(inst.ConfigEffectiveDate).slice(0, 10) : "",
          databases: (inst.Databases || inst.databases || []).length
            ? (inst.Databases || inst.databases || []).map((db) => ({
                databaseName: db.DatabaseName || db.databaseName || "",
                owner: db.Owner || db.owner || "",
                sizeGB: db.SizeGB ?? db.sizeGB ?? "",
                createdOn: db.CreatedOn ? String(db.CreatedOn).slice(0, 10) : (db.createdOn ? String(db.createdOn).slice(0, 10) : ""),
                recoveryModel: db.RecoveryModel || db.recoveryModel || "",
                databaseCollation: db.DatabaseCollation || db.databaseCollation || "",
                cdc: Boolean(db.CDC ?? db.cdc),
                compatibilityLevel: db.CompatibilityLevel ?? db.compatibilityLevel ?? "",
                encryption: Boolean(db.Encryption ?? db.encryption),
                queryStore: Boolean(db.QueryStore ?? db.queryStore),
                autoUpdateStats: Boolean(db.AutoUpdateStats ?? db.autoUpdateStats),
                isActive: db.IsActive !== false,
              }))
            : [{ ...emptyDatabase }],
        })),
        serverIPs: (d.serverIPs || []).map((x) => ({ ipAddress: x.IPAddress, ipAddressTypeId: String(x.IPAddressTypeID), isActive: Boolean(x.IsActive) })),
        serverStorages: (d.serverStorages || []).map((x) => ({
          driveLetter: x.DriveLetter,
          volumeLabel: x.VolumeLabel || "",
          totalSizeGB: x.TotalSizeGB,
          freeSpaceGB: x.FreeSpaceGB,
          isActive: Boolean(x.IsActive),
        })),
        contactMode: (d.contactMode || "bu").toLowerCase(),
        contacts: (d.contacts || []).length
          ? (d.contacts || []).map((x) => ({ contactName: x.ContactName, email: x.Email || "", phone: x.Phone || "", contactCategoryId: String(x.ContactCategoryID) }))
          : [{ ...emptyContact }],
        buDefaultContacts: (d.buDefaultContacts || []).map((x) => ({ contactName: x.ContactName, email: x.Email || "", phone: x.Phone || "", contactCategoryId: String(x.ContactCategoryID) })),
      });
      setActiveTab("Server");
      setMsg({ type: "", text: "" });
    } catch (err) {
      if (err.response?.status === 401) handleLogout();
      setMsg({ type: "error", text: err.response?.data?.message || err.message });
    }
  }

  if (!token) return <LoginView onLogin={handleLogin} busy={loginBusy} error={loginError} />;
  if (loading) return <div className="app-shell">Loading portal...</div>;
  if (isDashboardRoute) return <ExecutiveDashboard token={token} username={username} role={role} onLogout={handleLogout} />;
  if (isHealthRoute) return <HealthReportPage token={token} username={username} role={role} onLogout={handleLogout} />;
  if (isServerListRoute) return <ServerListPage token={token} username={username} role={role} onLogout={handleLogout} />;
  if (isDatabaseListRoute) return <DatabaseListPage token={token} username={username} role={role} onLogout={handleLogout} />;
  if (isDatabaseTrendRoute) return <DatabaseTrendPage token={token} username={username} role={role} onLogout={handleLogout} />;
  if (isServerDetailsRoute && serverDetailsId) return <ServerDetailsPage token={token} username={username} role={role} onLogout={handleLogout} serverId={serverDetailsId} />;
  if (isInventoryRoute && role !== "admin") {
    return (
      <div className="app-shell">
        <div className="alert error">You have read-only access. Inventory Form is available only to admin users.</div>
        <a href="/dashboard">Go to Dashboard</a>{" "}
        <a href="/health">Go to Health Report</a>{" "}
        <a href="/serverlist">Go to Server List</a>
        {" "}<a href="/databaselist">Go to Database List</a>
        {" "}<a href="/databasetrend">Go to Database Trend</a>
      </div>
    );
  }

  const sel = (label, value, list, onChange) => (
    <label>
      {label}
      <select value={value} onChange={onChange} required>
        <option value="">Select {label}</option>
        {(list || []).map((x) => (
          <option key={x.id} value={x.id}>
            {x.name}
          </option>
        ))}
      </select>
    </label>
  );

  return (
    <div className="app-shell">
      <header className="hero">
        <h1>SQL Server Inventory Management Portal</h1>
        <h3>Inventory Form</h3>
        <p>Captures, maintains, and audits SQL Server infrastructure metadata across the enterprise with validated lookup-driven
          inputs and version-aware update control.
        </p>
        <div className="hero-actions">
          <div className="top-nav">
            <a href="/dashboard">Dashboard</a>
            <a href="/health">Health Report</a>
            <a href="/serverlist">Server List</a>
            <a href="/databaselist">Database List</a>
            <a href="/databasetrend">Database Trend</a>
            <a href="/inventory" className="active-link">Inventory Form</a>
          </div>
          <span>Logged in as: <strong>{username}</strong></span>
          <button type="button" onClick={handleLogout}>Logout</button>
        </div>
      </header>

      <div className="mode-panel">
        <label>
          Mode
          <select
            value={mode}
            onChange={(e) => {
              const m = e.target.value;
              setMode(m);
              setEditServerId("");
              if (m === "create") setForm(baseForm(username));
            }}
          >
            <option value="create">Create New</option>
            <option value="edit">Edit Existing</option>
          </select>
        </label>
        {mode === "edit" && (
          <label>
            Select Server
            <select
              value={editServerId}
              onChange={(e) => {
                const id = e.target.value;
                setEditServerId(id);
                if (id) loadForEdit(id);
              }}
            >
              <option value="">Select Server</option>
              {servers.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name}
                </option>
              ))}
            </select>
          </label>
        )}
      </div>

      {errors.length > 0 ? <div className="alert error">{errors.map((e) => <div key={e}>{e}</div>)}</div> : null}
      {msg.text ? <div className={`alert ${msg.type === "success" ? "success" : "error"}`}>{msg.text}</div> : null}

      <form onSubmit={onSave}>
        <div className="tabs">
          {tabs.map((t) => (
            <button key={t} type="button" className={activeTab === t ? "tab active" : "tab"} onClick={() => setActiveTab(t)}>
              {t}
            </button>
          ))}
        </div>

        {activeTab === "Server" ? (
          <section className="card">
            <h2>Server Registration & Classification</h2>
            <div className="grid">
              <label>Server Name<input value={form.server.serverName} onChange={(e) => setSection("server", "serverName", e.target.value)} required /></label>
              <label>Description<input value={form.server.description} onChange={(e) => setSection("server", "description", e.target.value)} /></label>
              {sel("Environment", form.server.envId, options.environments, (e) => setSection("server", "envId", e.target.value))}
              {sel("Business Unit", form.server.buId, options.businessUnits, (e) => setSection("server", "buId", e.target.value))}
              {sel("Category", form.server.categoryId, options.categories, (e) => setSection("server", "categoryId", e.target.value))}
              {sel("Region", form.server.regionId, options.regions, (e) => setSection("server", "regionId", e.target.value))}
              {sel("Status", form.server.statusId, options.statuses, (e) => setSection("server", "statusId", e.target.value))}
              <label>Created/Updated By<input value={username} readOnly /></label>
            </div>
          </section>
        ) : null}

        {activeTab === "Hardware" ? (
          <section className="card">
            <h2>Hardware and OS Profile</h2>
            <div className="grid">
              {sel("Domain", form.serverHardware.domainId, options.domains, (e) => setSection("serverHardware", "domainId", e.target.value))}
              {sel("Operating System", form.serverHardware.operatingSystemId, options.osTypes, (e) => setSection("serverHardware", "operatingSystemId", e.target.value))}
              <label>Memory (GB)<input type="number" min="0" value={form.serverHardware.memoryGB} onChange={(e) => setSection("serverHardware", "memoryGB", e.target.value)} /></label>
              <label>CPU Cores<input type="number" min="0" value={form.serverHardware.cpuCores} onChange={(e) => setSection("serverHardware", "cpuCores", e.target.value)} /></label>
              <label>Processor Model<input value={form.serverHardware.processorModel} onChange={(e) => setSection("serverHardware", "processorModel", e.target.value)} /></label>
              {sel("Server Type", form.serverHardware.serverTypeId, options.serverTypes, (e) => setSection("serverHardware", "serverTypeId", e.target.value))}
              {sel("Platform", form.serverHardware.platformId, options.platforms, (e) => setSection("serverHardware", "platformId", e.target.value))}
              {sel("Timezone", form.serverHardware.timezoneId, options.timezones, (e) => setSection("serverHardware", "timezoneId", e.target.value))}
              <label>OS Install Date<input type="date" value={form.serverHardware.osInstallDate} onChange={(e) => setSection("serverHardware", "osInstallDate", e.target.value)} /></label>
              <label>Effective Date<input type="date" value={form.serverHardware.effectiveDate} onChange={(e) => setSection("serverHardware", "effectiveDate", e.target.value)} /></label>
            </div>
          </section>
        ) : null}

        {activeTab === "SQL" ? (
          <section className="card">
            <h2>SQL Instances</h2>
            {form.sqlInstances.map((inst, idx) => (
              <div key={`sql-inst-${idx}`} className="card" style={{ marginTop: 10 }}>
                <h3>Instance #{idx + 1}</h3>
                <div className="grid">
                  <label>Instance Name<input value={inst.instanceName} onChange={(e) => setArrayValue("sqlInstances", idx, "instanceName", e.target.value)} /></label>
                  {sel("Instance Type", inst.instanceTypeId, options.sqlInstanceTypes, (e) => setArrayValue("sqlInstances", idx, "instanceTypeId", e.target.value))}
                  <label>SQL Install Date<input type="date" value={inst.sqlInstallDate} onChange={(e) => setArrayValue("sqlInstances", idx, "sqlInstallDate", e.target.value)} /></label>
                  {sel("SQL Version", inst.sqlVersionId, options.sqlVersions, (e) => setArrayValue("sqlInstances", idx, "sqlVersionId", e.target.value))}
                  {sel("SQL Edition", inst.sqlEditionId, options.sqlEditions, (e) => setArrayValue("sqlInstances", idx, "sqlEditionId", e.target.value))}
                  <label>Product Build<input placeholder="e.g. 17.0.1000.7" value={inst.productBuild} onChange={(e) => setArrayValue("sqlInstances", idx, "productBuild", e.target.value)} /></label>
                  <label>Product Level<input placeholder="e.g. RTM, SP1, SP2" value={inst.productLevel} onChange={(e) => setArrayValue("sqlInstances", idx, "productLevel", e.target.value)} /></label>
                  <label>Version Effective Date<input type="date" value={inst.versionEffectiveDate} onChange={(e) => setArrayValue("sqlInstances", idx, "versionEffectiveDate", e.target.value)} /></label>
                  {sel("Instance Collation", inst.instanceCollationId, options.sqlInstanceCollations, (e) => setArrayValue("sqlInstances", idx, "instanceCollationId", e.target.value))}
                  <label>Min Memory (MB)<input type="number" min="0" value={inst.minMemoryMB} onChange={(e) => setArrayValue("sqlInstances", idx, "minMemoryMB", e.target.value)} /></label>
                  <label>Max Memory (MB)<input type="number" min="0" value={inst.maxMemoryMB} onChange={(e) => setArrayValue("sqlInstances", idx, "maxMemoryMB", e.target.value)} /></label>
                  <label>MaxDOP<input type="number" min="0" value={inst.maxDOP} onChange={(e) => setArrayValue("sqlInstances", idx, "maxDOP", e.target.value)} /></label>
                  <label>Cost Threshold Parallelism<input type="number" min="0" value={inst.costThresholdParallelism} onChange={(e) => setArrayValue("sqlInstances", idx, "costThresholdParallelism", e.target.value)} /></label>
                  <label className="checkbox"><input type="checkbox" checked={inst.adhocWorkload} onChange={(e) => setArrayValue("sqlInstances", idx, "adhocWorkload", e.target.checked)} />Adhoc Workload</label>
                  <label className="checkbox"><input type="checkbox" checked={inst.lockPageInMemory} onChange={(e) => setArrayValue("sqlInstances", idx, "lockPageInMemory", e.target.checked)} />Lock Page In Memory</label>
                  <label className="checkbox"><input type="checkbox" checked={inst.ifi} onChange={(e) => setArrayValue("sqlInstances", idx, "ifi", e.target.checked)} />IFI</label>
                  <label className="checkbox"><input type="checkbox" checked={inst.databaseMail} onChange={(e) => setArrayValue("sqlInstances", idx, "databaseMail", e.target.checked)} />Database Mail</label>
                  <label className="checkbox"><input type="checkbox" checked={inst.fileStream} onChange={(e) => setArrayValue("sqlInstances", idx, "fileStream", e.target.checked)} />FileStream</label>
                  <label>Config Effective Date<input type="date" value={inst.configEffectiveDate} onChange={(e) => setArrayValue("sqlInstances", idx, "configEffectiveDate", e.target.value)} /></label>
                </div>

                <div className="card" style={{ marginTop: 12 }}>
                  <h4>Databases (Per Instance)</h4>
                  <p className="brand-sub" style={{ marginTop: -6 }}>
                    Add database metadata for this instance. Leave empty if you do not want to maintain database-level inventory yet.
                  </p>
                  <div className="table-wrap">
                    <table className="data-table">
                      <thead>
                        <tr>
                          <th>Database Name</th>
                          <th>Owner</th>
                          <th>Size (GB)</th>
                          <th>Created On</th>
                          <th>Recovery</th>
                          <th>Collation</th>
                          <th>CDC</th>
                          <th>Compat</th>
                          <th>Encryption</th>
                          <th>QueryStore</th>
                          <th>AutoUpdateStats</th>
                          <th></th>
                        </tr>
                      </thead>
                      <tbody>
                        {(inst.databases || [{ ...emptyDatabase }]).map((db, di) => (
                          <tr key={`db-${idx}-${di}`}>
                            <td><input value={db.databaseName} placeholder="DatabaseName" onChange={(e) => setInstanceDbValue(idx, di, "databaseName", e.target.value)} /></td>
                            <td><input value={db.owner} placeholder="Owner" onChange={(e) => setInstanceDbValue(idx, di, "owner", e.target.value)} /></td>
                            <td><input type="number" min="0" step="0.01" value={db.sizeGB} placeholder="SizeGB" onChange={(e) => setInstanceDbValue(idx, di, "sizeGB", e.target.value)} /></td>
                            <td><input type="date" value={db.createdOn} onChange={(e) => setInstanceDbValue(idx, di, "createdOn", e.target.value)} /></td>
                            <td><input value={db.recoveryModel} placeholder="FULL/SIMPLE" onChange={(e) => setInstanceDbValue(idx, di, "recoveryModel", e.target.value)} /></td>
                            <td><input value={db.databaseCollation} placeholder="Collation" onChange={(e) => setInstanceDbValue(idx, di, "databaseCollation", e.target.value)} /></td>
                            <td style={{ textAlign: "center" }}><input type="checkbox" checked={Boolean(db.cdc)} onChange={(e) => setInstanceDbValue(idx, di, "cdc", e.target.checked)} /></td>
                            <td><input type="number" min="0" step="1" value={db.compatibilityLevel} placeholder="e.g. 160" onChange={(e) => setInstanceDbValue(idx, di, "compatibilityLevel", e.target.value)} /></td>
                            <td style={{ textAlign: "center" }}><input type="checkbox" checked={Boolean(db.encryption)} onChange={(e) => setInstanceDbValue(idx, di, "encryption", e.target.checked)} /></td>
                            <td style={{ textAlign: "center" }}><input type="checkbox" checked={Boolean(db.queryStore)} onChange={(e) => setInstanceDbValue(idx, di, "queryStore", e.target.checked)} /></td>
                            <td style={{ textAlign: "center" }}><input type="checkbox" checked={Boolean(db.autoUpdateStats)} onChange={(e) => setInstanceDbValue(idx, di, "autoUpdateStats", e.target.checked)} /></td>
                            <td>
                              <button type="button" onClick={() => removeInstanceDb(idx, di)}>Remove</button>
                            </td>
                          </tr>
                        ))}
                        {!(inst.databases || []).length ? (
                          <tr><td colSpan={12} style={{ textAlign: "center" }}>No databases</td></tr>
                        ) : null}
                      </tbody>
                    </table>
                  </div>
                  <button type="button" onClick={() => addInstanceDb(idx)} style={{ marginTop: 8 }}>
                    Add Database
                  </button>
                </div>

                <button type="button" onClick={() => removeRow("sqlInstances", idx)} style={{ marginTop: 10 }}>
                  Remove Instance
                </button>
              </div>
            ))}
            <button type="button" onClick={() => setForm((p) => ({ ...p, sqlInstances: [...p.sqlInstances, newSqlInstance()] }))}>
              Add SQL Instance
            </button>
          </section>
        ) : null}

        {activeTab === "Network" ? (
          <>
            <section className="card">
              <h2>IP Addresses</h2>
              {form.serverIPs.map((r, i) => (
                <div key={`ip-${i}`} className="repeat-row">
                  <input placeholder="IP Address" value={r.ipAddress} onChange={(e) => setArrayValue("serverIPs", i, "ipAddress", e.target.value)} />
                  <select value={r.ipAddressTypeId} onChange={(e) => setArrayValue("serverIPs", i, "ipAddressTypeId", e.target.value)}>
                    <option value="">Select IP Type</option>
                    {(options.ipAddressTypes || []).map((x) => (
                      <option key={x.id} value={x.id}>
                        {x.name}
                      </option>
                    ))}
                  </select>
                  <button type="button" onClick={() => removeRow("serverIPs", i)}>Remove</button>
                </div>
              ))}
              <button type="button" onClick={() => addRow("serverIPs", emptyIp)}>Add IP</button>
            </section>
            <section className="card">
              <h2>Storage Volumes</h2>
              {form.serverStorages.map((r, i) => (
                <div key={`st-${i}`} className="repeat-row">
                  <input maxLength={1} placeholder="Drive" value={r.driveLetter} onChange={(e) => setArrayValue("serverStorages", i, "driveLetter", e.target.value)} />
                  <input placeholder="Volume Label" value={r.volumeLabel} onChange={(e) => setArrayValue("serverStorages", i, "volumeLabel", e.target.value)} />
                  <input type="number" min="0" step="0.01" placeholder="Total GB" value={r.totalSizeGB} onChange={(e) => setArrayValue("serverStorages", i, "totalSizeGB", e.target.value)} />
                  <input type="number" min="0" step="0.01" placeholder="Free GB" value={r.freeSpaceGB} onChange={(e) => setArrayValue("serverStorages", i, "freeSpaceGB", e.target.value)} />
                  <button type="button" onClick={() => removeRow("serverStorages", i)}>Remove</button>
                </div>
              ))}
              <button type="button" onClick={() => addRow("serverStorages", emptyStorage)}>Add Storage</button>
            </section>
          </>
        ) : null}

        {activeTab === "Contacts" ? (
          <section className="card">
            <h2>Ownership and Support Contacts</h2>

            <div className="mode-panel" style={{ marginTop: 10 }}>
              <label>
                Contact Mode
                <select
                  value={form.contactMode}
                  onChange={(e) => {
                    const v = e.target.value;
                    setForm((p) => ({
                      ...p,
                      contactMode: v,
                      contacts: v === "custom" ? (p.contacts && p.contacts.length ? p.contacts : [{ ...emptyContact }]) : [{ ...emptyContact }],
                    }));
                  }}
                >
                  <option value="bu">Use BU Default</option>
                  <option value="custom">Custom per Server</option>
                </select>
              </label>
            </div>

            {form.contactMode === "bu" ? (
              <>
                <div className="alert success" style={{ marginTop: 10 }}>
                  Using BU default contacts. You can switch to <strong>Custom per Server</strong> to override for this server.
                </div>
                <div className="table-wrap" style={{ marginTop: 10 }}>
                  <table className="data-table">
                    <thead>
                      <tr>
                        <th>Category</th>
                        <th>Name</th>
                        <th>Email</th>
                        <th>Phone</th>
                      </tr>
                    </thead>
                    <tbody>
                      {(form.buDefaultContacts || []).map((c, idx) => (
                        <tr key={`bu-ct-${idx}`}>
                          <td>{(options.contactCategories || []).find((x) => String(x.id) === String(c.contactCategoryId))?.name || ""}</td>
                          <td>{c.contactName}</td>
                          <td>{c.email || ""}</td>
                          <td>{c.phone || ""}</td>
                        </tr>
                      ))}
                      {!(form.buDefaultContacts || []).length ? (
                        <tr>
                          <td colSpan={4} style={{ textAlign: "center" }}>No BU default contacts configured.</td>
                        </tr>
                      ) : null}
                    </tbody>
                  </table>
                </div>
              </>
            ) : (
              <>
                {form.contacts.map((r, i) => (
                  <div key={`ct-${i}`} className="repeat-row">
                    <input placeholder="Contact Name" value={r.contactName} onChange={(e) => setArrayValue("contacts", i, "contactName", e.target.value)} />
                    <input placeholder="Email" value={r.email} onChange={(e) => setArrayValue("contacts", i, "email", e.target.value)} />
                    <input placeholder="Phone" value={r.phone} onChange={(e) => setArrayValue("contacts", i, "phone", e.target.value)} />
                    <select value={r.contactCategoryId} onChange={(e) => setArrayValue("contacts", i, "contactCategoryId", e.target.value)}>
                      <option value="">Select Category</option>
                      {(options.contactCategories || []).map((x) => (
                        <option key={x.id} value={x.id}>
                          {x.name}
                        </option>
                      ))}
                    </select>
                    <button type="button" onClick={() => removeRow("contacts", i)}>Remove</button>
                  </div>
                ))}
                <button type="button" onClick={() => addRow("contacts", emptyContact)}>Add Contact</button>
              </>
            )}
          </section>
        ) : null}

        {activeTab === "Review" ? (
          <section className="card">
            <h2>Final Review</h2>
            <p>In edit mode, updates are logged into <code>inventory.ChangeHistory</code>.</p>
            <ul>
              <li>Mode: {mode === "edit" ? "Edit Existing" : "Create New"}</li>
              <li>Server Name: {form.server.serverName || "-"}</li>
              <li>Requested By: {username || "-"}</li>
              <li>SQL Instances: {form.sqlInstances.length}</li>
              <li>IP Rows: {form.serverIPs.length}</li>
              <li>Storage Rows: {form.serverStorages.length}</li>
              <li>Contact Mode: {form.contactMode === "custom" ? "Custom per Server" : "Use BU Default"}</li>
              <li>Custom Contacts Rows: {form.contactMode === "custom" ? form.contacts.length : 0}</li>
            </ul>
          </section>
        ) : null}

        <div className="actions">
          <button type="button" onClick={() => setActiveTab(tabs[Math.max(0, tabs.indexOf(activeTab) - 1)])}>Previous</button>
          <button type="button" onClick={() => setActiveTab(tabs[Math.min(tabs.length - 1, tabs.indexOf(activeTab) + 1)])}>Next</button>
          <button className="submit-btn" type="submit" disabled={saving}>{saving ? "Saving..." : mode === "edit" ? "Update Inventory" : "Save Inventory"}</button>
        </div>
      </form>

      <footer className="footer-note">
        <div>All inventory entries must align with approved enterprise infrastructure standards.</div>
        <div>Changes to server, hardware, or SQL configuration are version-controlled and audit logged.</div>
      </footer>
    </div>
  );
}

export default App;
