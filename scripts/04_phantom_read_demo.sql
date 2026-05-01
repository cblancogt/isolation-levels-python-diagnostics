-- ============================================================
-- C1300S03 | Script 04 — Phantom Read Demo
-- Shows phantom reads under Repeatable Read and
-- how Serializable prevents them.
-- SQL Server 2019+ | Database: STN_Lab
-- ============================================================

USE STN_Lab;
GO

-- ============================================================
-- SETUP — Isolated test table for clear observation
-- ============================================================
IF OBJECT_ID('dbo.PhantomTest', 'U') IS NOT NULL DROP TABLE dbo.PhantomTest
GO

CREATE TABLE dbo.PhantomTest (
    DeclaracionID   INT           NOT NULL PRIMARY KEY,
    ContribuyenteID INT           NOT NULL,
    Periodo         CHAR(7)       NOT NULL,
    MontoDeclarado  DECIMAL(18,2) NOT NULL
)
GO

-- Seed with 5 declarations for period 2024-01
INSERT INTO dbo.PhantomTest VALUES
(1, 1001, '2024-01', 15000.00),
(2, 1002, '2024-01', 22000.00),
(3, 1003, '2024-01', 8500.00),
(4, 1004, '2024-01', 31000.00),
(5, 1005, '2024-01', 17000.00)
GO

-- ============================================================
-- PART 1 — PHANTOM READ under REPEATABLE READ
-- ============================================================

-- ==================================================
-- SESSION A — Open a read transaction and HOLD IT
-- ==================================================
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

BEGIN TRANSACTION;

    -- First read: 5 rows, SUM = 93500.00
    SELECT
        COUNT(*)             AS TotalDeclaraciones,
        SUM(MontoDeclarado)  AS TotalMonto
    FROM dbo.PhantomTest
    WHERE Periodo = '2024-01';
    -- Expected: 5 rows, 93500.00

    -- DO NOT COMMIT — hold the transaction open (30 seconds)
    WAITFOR DELAY '00:00:30';

    -- Second read (run AFTER Session B inserts)
    SELECT
        COUNT(*)             AS TotalDeclaraciones,
        SUM(MontoDeclarado)  AS TotalMonto
    FROM dbo.PhantomTest
    WHERE Periodo = '2024-01';
    -- OBSERVED: 6 rows, 118500.00 — a NEW row appeared = PHANTOM ROW
    -- Repeatable Read protects rows that EXISTED at first read,
    -- but does NOT protect against new rows matching the range.

ROLLBACK;
GO

-- ==================================================
-- SESSION B — Run WHILE Session A is waiting
-- Inserts a new row that Session A's range will capture
-- ==================================================
INSERT INTO dbo.PhantomTest VALUES
(6, 1006, '2024-01', 25000.00);
GO

-- ============================================================
-- PART 2 — SERIALIZABLE prevents phantom reads
-- ============================================================

-- Reset data
DELETE FROM dbo.PhantomTest WHERE DeclaracionID = 6;
GO

-- ==================================================
-- SESSION A (REPEAT) — Now with Serializable
-- ==================================================
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

BEGIN TRANSACTION;

    -- First read: acquires a RANGE LOCK on Periodo = '2024-01'
    -- No new rows can be inserted into this range while the lock is held
    SELECT
        COUNT(*)             AS TotalDeclaraciones,
        SUM(MontoDeclarado)  AS TotalMonto
    FROM dbo.PhantomTest
    WHERE Periodo = '2024-01';
    -- Expected: 5 rows, 93500.00

    WAITFOR DELAY '00:00:30';

    -- Second read
    SELECT
        COUNT(*)             AS TotalDeclaraciones,
        SUM(MontoDeclarado)  AS TotalMonto
    FROM dbo.PhantomTest
    WHERE Periodo = '2024-01';
    -- OBSERVED: Still 5 rows, 93500.00 — no phantom
    -- Session B's INSERT was BLOCKED until this transaction committed

COMMIT;
GO

-- ==================================================
-- SESSION B (REPEAT) — Try to insert while Session A holds
-- ==================================================
-- OBSERVE: This INSERT BLOCKS until Session A commits
INSERT INTO dbo.PhantomTest VALUES
(6, 1006, '2024-01', 25000.00);
GO

-- ============================================================
-- CLEANUP
-- ============================================================
DROP TABLE IF EXISTS dbo.PhantomTest;
GO

/*
==================================================
ARCHITECTURAL OBSERVATION
==================================================
Phantom Read scenario in STN_Lab:
  An auditor runs a totals report for period 2024-01 twice
  in the same transaction (first to validate, second to sign off).
  Under Repeatable Read, a batch job can INSERT new declarations
  between the two reads — the auditor signs off on an amount
  that was different when they first reviewed it.

  Under Serializable, the range is locked — no new rows
  can appear mid-transaction.

COST: Serializable significantly reduces concurrency.
The INSERT in Session B blocks until Session A finishes.

RECOMMENDATION FOR STN_Lab:
  Use Serializable only for critical fiscal totalization processes
  that require absolute consistency over a range.
  For general portal reads: RCSI is sufficient.
==================================================
*/
