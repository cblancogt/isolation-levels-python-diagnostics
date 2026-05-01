-- PID 66
-- SESSION B — Run this WHILE Session A is open
-- ==================================================
-- This simulates a read request from a portal user

-- OBSERVE: This query will BLOCK until Session A commits or rolls back

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

SELECT TOP 1000
    d.ContribuyenteID,
    d.PeriodoFiscal,
    d.MontoDeclarado
FROM dbo.Declaracion d
WHERE d.TipoImpuestoId = 1
and periodoFiscal = '2022-07'
ORDER BY d.MontoDeclarado ASC
