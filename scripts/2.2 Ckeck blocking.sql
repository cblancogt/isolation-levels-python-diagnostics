-- Check blocking in a THIRD session while both above are running:
SELECT
    r.session_id AS Sesiones_bloqueadas,
    r.blocking_session_id AS BloqueadaPor,
    r.wait_type AS TipoBloqueo,
    r.wait_time/1000 AS Espera_Seg,
    (r.wait_time/1000)/60 AS Espera_Min,
    r.wait_resource
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.blocking_session_id <> 0;;