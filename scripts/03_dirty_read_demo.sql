-- ============================================================
-- C1300S03 | Script 03 — Dirty Read with Read Uncommitted
-- Demonstrates the risk of reading uncommitted data.
-- Requires two sessions running simultaneously.
-- SQL Server 2019+ | Database: STN_Lab
-- ============================================================

USE STN_Lab;
GO

-- ============================================================
-- 3.1 SETUP — Create an isolated test record to track clearly
-- ============================================================
IF OBJECT_ID('dbo.PagoAuditTest', 'U') IS NOT NULL DROP TABLE dbo.PagoAuditTest;
GO

CREATE TABLE dbo.PagoAuditTest (
    PagoID       INT           NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Referencia   VARCHAR(50)   NOT NULL,
    Monto        DECIMAL(18,2) NOT NULL,
    Estado       VARCHAR(20)   NOT NULL DEFAULT 'PENDIENTE'
);
GO

INSERT INTO dbo.PagoAuditTest (Referencia, Monto, Estado)
VALUES ('REF-DIRTY-001', 50000.00, 'PENDIENTE');
GO

-- Confirm initial state
SELECT * FROM dbo.PagoAuditTest;
-- Expected: Monto = 50000.00, Estado = PENDIENTE

-- ==================================================
-- 3.2 Simulates a payment processing transaction that updates the record but is still processing (not committed)

-- SESSION A — Run this first and LEAVE IT OPEN

-- ==================================================

BEGIN TRANSACTION;

    UPDATE dbo.PagoAuditTest
    SET Monto  = 999999.99,
        Estado = 'PROCESANDO'
    WHERE Referencia = 'REF-DIRTY-001';

    -- DO NOT COMMIT — the transaction is "in flight"
    -- Wait while Session B reads the dirty data
    WAITFOR DELAY '00:00:30';

-- *** Session A will ROLLBACK after 30 seconds ***
ROLLBACK;
-- The update never happened. Monto returns to 50000.00.

-- ==================================================
-- SESSION B — Run WHILE Session A is open
-- ==================================================

-- BAD PRACTICE: Read Uncommitted reads dirty (uncommitted) data
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

SELECT
    PagoID,
    Referencia,
    Monto,
    Estado
FROM dbo.PagoAuditTest
WHERE Referencia = 'REF-DIRTY-001';

-- WHAT IS OBSERVED:
-- Monto = 999999.99  <-- DIRTY DATA, uncommitted
-- Estado = 'PROCESANDO'  <-- also dirty

-- Now reset and wait for Session A to rollback
-- Then re-run the same SELECT:
-- Monto returns to 50000.00 — the 999999.99 never existed

-- ============================================================
-- ILLUSTRATION OF THE REAL RISK IN STN_Lab
-- ============================================================
-- Scenario: A fiscal auditor runs a report using NOLOCK (= READ UNCOMMITTED)
-- to avoid blocking. The batch job is recalculating 200,000 declarations.
-- The auditor's report captures mid-flight values.
-- The batch rolls back due to a constraint violation.
-- The auditor's report shows fiscal totals that NEVER EXISTED in the database.
-- Result: regulatory report based on ghost data.

-- SAFER ALTERNATIVE: Use default Read Committed (or RCSI if enabled)
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

SELECT
    PagoID,
    Referencia,
    Monto,
    Estado
FROM dbo.PagoAuditTest
WHERE Referencia = 'REF-DIRTY-001';
-- OBSERVED: Query waits (blocks) until Session A commits or rolls back.
-- Once Session A rolls back: Monto = 50000.00 — correct committed value.

-- ============================================================
-- CLEANUP
-- ============================================================
DROP TABLE IF EXISTS dbo.PagoAuditTest;
GO

/*
==================================================
KEY TAKEAWAY
==================================================
NOLOCK / READ UNCOMMITTED is NOT a performance optimization.
It is a consistency trade-off that accepts the risk of reading
data that may never have been committed.

In STN_Lab, this could mean:
  - Tax totals calculated on rolled-back transactions
  - Compliance reports with phantom values
  - Audit trails that don't match the actual database state

Architectural rule: NOLOCK is acceptable ONLY for truly
non-critical reads where approximate counts are sufficient
(e.g., dashboard row-count estimates). Never for financial totals.
==================================================
*/
