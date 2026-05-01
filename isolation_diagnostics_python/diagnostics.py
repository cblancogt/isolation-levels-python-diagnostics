from connection import get_connection

def get_isolation_levels():
    query = """
    SELECT
        name                          AS database_name,
        is_read_committed_snapshot_on AS rcsi_enabled,
        snapshot_isolation_state_desc AS snapshot_state
    FROM sys.databases
    WHERE database_id > 4
    ORDER BY name;
    """
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(query)
        columns = [col[0] for col in cursor.description]
        return [dict(zip(columns, row)) for row in cursor.fetchall()]


def get_blocked_sessions():
    query = """
    SELECT
        r.session_id,
        r.blocking_session_id         AS blocked_by,
        r.wait_type,
        r.wait_time                   AS wait_ms,
        DB_NAME(r.database_id)        AS database_name,
        SUBSTRING(qt.text, 1, 150)    AS query_snippet
    FROM sys.dm_exec_requests r
    CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) qt
    WHERE r.blocking_session_id > 0
    ORDER BY r.wait_time DESC;
    """
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(query)
        columns = [col[0] for col in cursor.description]
        return [dict(zip(columns, row)) for row in cursor.fetchall()]


def get_lock_waits():
    query = """
    SELECT TOP 20
        wt.session_id,
        wt.wait_type,
        wt.wait_duration_ms,
        wt.resource_description,
        DB_NAME(r.database_id) AS database_name
    FROM sys.dm_os_waiting_tasks wt
    LEFT JOIN sys.dm_exec_requests r
        ON r.session_id = wt.session_id
    WHERE wt.wait_type LIKE 'LCK%'
    ORDER BY wt.wait_duration_ms DESC;
    """
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(query)
        columns = [col[0] for col in cursor.description]
        return [dict(zip(columns, row)) for row in cursor.fetchall()]


def get_active_sessions():
    query = """
    SELECT TOP 30
        s.session_id,
        DB_NAME(s.database_id) AS database_name,
        s.status,
        s.login_name,
        CASE s.transaction_isolation_level
            WHEN 0 THEN 'UNSPECIFIED'
            WHEN 1 THEN 'READ UNCOMMITTED'
            WHEN 2 THEN 'READ COMMITTED'
            WHEN 3 THEN 'REPEATABLE READ'
            WHEN 4 THEN 'SERIALIZABLE'
            WHEN 5 THEN 'SNAPSHOT'
            ELSE        'UNKNOWN'
        END AS isolation_level,
        s.cpu_time
    FROM sys.dm_exec_sessions s
    WHERE s.is_user_process = 1
      AND s.status != 'sleeping'
    ORDER BY s.cpu_time DESC;
    """
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(query)
        columns = [col[0] for col in cursor.description]
        return [dict(zip(columns, row)) for row in cursor.fetchall()]