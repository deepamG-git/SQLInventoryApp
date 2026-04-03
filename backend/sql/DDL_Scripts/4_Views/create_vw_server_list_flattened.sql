USE SQLInventory;
GO

/*
  Flattened server list view (one row per SQL instance) matching the API endpoint:
    GET /api/server-list

  Notes:
  - Uses FOR XML PATH aggregation for IP addresses for compatibility with older SQL Server versions (e.g. 2016).
  - Does not filter by ServerStatus; consumers can filter (e.g. WHERE StatusName = 'IN USE').
  - Does not include ORDER BY (not allowed in a view).
*/

CREATE OR ALTER VIEW inventory.vw_ServerListFlattened
AS
WITH ipAgg AS (
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
  s.ServerID,
  s.ServerName,
  ss.StatusName,
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
  i.SQLInstanceID,
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
LEFT JOIN inventory.SQLInstance i ON i.ServerID = s.ServerID AND ISNULL(i.IsActive, 1) = 1
LEFT JOIN inventory.SQLInstanceType it ON it.InstanceTypeID = i.InstanceTypeID
LEFT JOIN inventory.SQLInstanceVersion iv ON iv.SQLInstanceID = i.SQLInstanceID AND iv.IsCurrent = 1
LEFT JOIN inventory.SQLVersion sv ON sv.SQLVersionID = iv.SQLVersionID
LEFT JOIN inventory.SQLEdition se ON se.SQLEditionID = iv.SQLEditionID;
GO

/*
  Examples:

  -- Default server list behavior (IN USE only), order like the API:
  SELECT *
  FROM inventory.vw_ServerListFlattened
  WHERE StatusName = 'IN USE'
  ORDER BY BUName, ServerName, SQLInstanceName;

  -- Filter to a single BU:
  SELECT *
  FROM inventory.vw_ServerListFlattened
  WHERE StatusName = 'IN USE' AND BUName = 'My BU'
  ORDER BY ServerName, SQLInstanceName;
*/

