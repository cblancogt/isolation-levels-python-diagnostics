-- PID 52
-- SESSION A — Run this first and LEAVE IT OPEN
-- ==================================================
-- This simulates a long-running write transaction
-- (e.g., batch recalculation of declarations)

BEGIN TRANSACTION

    UPDATE TOP (1000) dbo.Declaracion
    SET MontoDeclarado = MontoDeclarado * 1.05
    WHERE TipoImpuestoId = 1
    and periodoFiscal = '2022-07'
    -- DO NOT COMMIT YET — simulate a slow process
    -- Wait here while you run Session B
    WAITFOR DELAY '00:00:50' -- 50 seconds window to run Session B

ROLLBACK
-- (Session A will rollback after 50s — observe Session B blocking)