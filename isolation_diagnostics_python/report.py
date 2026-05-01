import os
from datetime import datetime
from config import OUTPUT_DIR

def generate(db_isolation, blocking, lock_waits, active_sessions):
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename  = os.path.join(OUTPUT_DIR, f"stn_diagnostics_{timestamp}.txt")
    lines     = []

    def section(title):
        return f"\n{'=' * 60}\n  {title}\n{'=' * 60}\n"

    def format_rows(rows):
        if not rows:
            return "  No results found.\n"
        out = []
        for i, row in enumerate(rows, 1):
            out.append(f"  [{i}]")
            for k, v in row.items():
                out.append(f"      {k:<30}: {v}")
            out.append("")
        return "\n".join(out)

    lines.append("=" * 60)
    lines.append("  STN — Isolation Level Diagnostics Report")
    lines.append(f"  Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append("=" * 60)

    lines.append(section("1. Database Isolation Level Settings"))
    lines.append(format_rows(db_isolation))

    lines.append(section(f"2. Blocked Sessions ({len(blocking)} found)"))
    lines.append(format_rows(blocking))

    lines.append(section(f"3. Lock Wait Activity ({len(lock_waits)} found)"))
    lines.append(format_rows(lock_waits))

    lines.append(section("4. Active Sessions"))
    lines.append(format_rows(active_sessions))

    lines.append(section("5. Summary"))
    lines.append(f"  Blocked sessions : {len(blocking)}")
    lines.append(f"  Lock waits       : {len(lock_waits)}")
    lines.append("")
    if len(blocking) > 0:
        lines.append("  [ACTION REQUIRED] Blocking detected.")
    else:
        lines.append("  [OK] No blocking detected at time of capture.")

    lines.append("\n" + "=" * 60)
    lines.append("  End of Report — C1300S03")
    lines.append("=" * 60)

    content = "\n".join(lines)
    with open(filename, "w", encoding="utf-8") as f:
        f.write(content)

    return filename