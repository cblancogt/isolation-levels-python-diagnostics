import diagnostics
import report

def main():
    print("Running STN diagnostics...")

    db_isolation    = diagnostics.get_isolation_levels()
    blocking        = diagnostics.get_blocked_sessions()
    lock_waits      = diagnostics.get_lock_waits()
    active_sessions = diagnostics.get_active_sessions()

    output = report.generate(db_isolation, blocking, lock_waits, active_sessions)
    print(f"Report saved to: {output}")

if __name__ == "__main__":
    main()