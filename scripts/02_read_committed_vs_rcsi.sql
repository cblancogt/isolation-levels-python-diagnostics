-- ============================================================
-- C1300S03 | Script 02 — Read Committed vs RCSI
-- Run SESSION A first, then SESSION B, observe blocking behavior.
-- Then enable RCSI and repeat to observe the difference.
-- SQL Server 2019+ | Database: STN_Lab
-- ============================================================

USE STN_Lab;
GO

-- ============================================================
-- PART 1 — DEFAULT BEHAVIOR (Read Committed, no RCSI)
-- ============================================================

-- Verify RCSI is OFF before starting
SELECT
    name,
    CASE WHEN is_read_committed_snapshot_on = 0 THEN 'OFF' ELSE 'ON' END AS RCSI_Enabled
FROM sys.databases
WHERE name = 'STN_Lab';
-- Expected: RCSI_Enabled = OFF
GO

-- ==================================================
--2.2 Simulation long-running write transaction
-- SESSION A — Run this first and LEAVE IT OPEN
-- ==================================================
-- This simulates a long-running write transaction
-- (e.g., batch recalculation of declarations)

BEGIN TRANSACTION;

    UPDATE TOP (1000) dbo.Declaracion
    SET MontoDeclarado = MontoDeclarado * 1.05
    WHERE TipoImpuestoId = 1;

    -- DO NOT COMMIT YET — simulate a slow process
    -- Wait here while you run Session B
    WAITFOR DELAY '00:00:50'; -- 50 seconds window to run Session B

ROLLBACK;
-- (Session A will rollback after 50s — observe Session B blocking)

-- ==================================================
-- SESSION B — Run this WHILE Session A is open
-- ==================================================
-- This simulates a read request from a portal user

-- OBSERVE: This query will BLOCK until Session A commits or rolls back
SELECT TOP 10
    d.ContribuyenteID,
    d.PeriodoFiscal,
    d.MontoDeclarado
FROM dbo.Declaracion d
WHERE d.TipoImpuestoId = 1
ORDER BY d.MontoDeclarado DESC;

-- Check blocking in a THIRD session while both above are running:
SELECT
    r.session_id AS Sesiones_bloqueadas,
    r.blocking_session_id AS Sesion_Bloqueo,
    r.wait_type AS TipoBloqueo,
    r.wait_time/1000 AS Espera_Seg,
    (r.wait_time/1000)/60 AS Espera_Min,
    r.wait_resource
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.blocking_session_id <> 0;

-- ============================================================
-- PART 2 — ENABLE RCSI (eliminates blocking for readers)
-- ============================================================

-- Must run with no active connections to STN_Lab (single-user briefly)
-- Backup before enabling in production.

ALTER DATABASE STN_Lab SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
GO

-- Verify RCSI is now ON
SELECT
    name,
    CASE WHEN is_read_committed_snapshot_on = 0 THEN 'OFF' ELSE 'ON' END AS RCSI_Enabled
FROM sys.databases
WHERE name = 'STN_Lab';
-- Expected: RCSI_Enabled = OFF
GO

-- ==================================================
-- SESSION A (REPEAT) — Long-running write, same as before
-- ==================================================
BEGIN TRANSACTION;

    UPDATE TOP (1000) dbo.Declaracion
    SET MontoDeclarado = MontoDeclarado * 1.05
    WHERE TipoImpuestoId = 1;

    WAITFOR DELAY '00:00:30';

ROLLBACK;

-- ==================================================
-- SESSION B (REPEAT) — Same read query
-- ==================================================
-- OBSERVE: This query NO LONGER BLOCKS.
-- It reads the last committed version from the version store (TempDB).
-- The data returned reflects the state BEFORE Session A started.

SELECT TOP 10
    d.ContribuyenteID,
    d.PeriodoFiscal,
    d.MontoDeclarado
FROM dbo.Declaracion d
WHERE d.TipoImpuestoId = 1
ORDER BY d.MontoDeclarado DESC;

-- Verify: no blocking sessions
SELECT
    r.session_id AS Sesiones_bloqueadas,
    r.blocking_session_id AS Sesion_Bloqueo,
    r.wait_type AS TipoBloqueo,
    r.wait_time/1000 AS Espera_Seg,
    (r.wait_time/1000)/60 AS Espera_Min,
    r.wait_resource
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.blocking_session_id <> 0;
-- Expected: 0 rows

-- ============================================================
-- CLEANUP — Restore default for rest of demos if needed
-- ============================================================
-- ALTER DATABASE STN_Lab SET READ_COMMITTED_SNAPSHOT OFF WITH ROLLBACK IMMEDIATE;
-- GO

/*
==================================================
ARCHITECTURAL OBSERVATION SUMMARY
==================================================
Without RCSI:
  - Writers block readers
  - Readers block writers
  - Under high concurrency, latency spikes and timeouts

With RCSI:
  - Readers never block writers
  - Writers never block readers
  - Row version stored in TempDB (monitor tempdb size in production)
  - TRADE-OFF: TempDB pressure increases; version store must be managed

Recommendation for STN_Lab:
  RCSI is the correct default for the STN_Lab workload pattern:
  heavy concurrent reads from portal + batch writes from processing.
==================================================
*/
