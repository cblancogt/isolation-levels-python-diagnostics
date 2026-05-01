# ADR-001 — Isolation Level Strategy for STN_Lab

**Status:** Accepted
**Date:** 2026-05-01
**Author:** C13 - Data Architecture Track

---

## Context

STN_Lab processes 200K taxpayers, 1.5M declarations, and 1.2M payments on SQL Server 2022. Concurrent access from portal reads, auditor sessions, and batch recalculation jobs creates reader-writer contention under default Read Committed.

Observed in lab: full-table UPDATE on Declaracion blocked concurrent reads for 8,583ms (LCK_M_IS, object-level Exclusive lock). Captured by Python diagnostics and Activity Monitor.

---

## Decision

Enable RCSI as the database default for STN_Lab.

- Portal and reporting queries: Read Committed (RCSI-backed, no code changes)
- Multi-statement auditor sessions: Snapshot Isolation
- Fiscal period closing: Serializable
- Monetary and regulatory data: Read Uncommitted prohibited

---

## Consequences

**Positive**
- Portal reads no longer block on batch writes
- Dirty reads eliminated at the default level
- Transparent to the application layer

**Negative**
- TempDB version store must be monitored under heavy write load
- Snapshot Isolation requires application-level retry on update conflicts
- Serializable blocks insertions into the locked range — confirmed in Script 04

---

## Alternatives Rejected

**Read Committed without RCSI** - blocking observed and measured. Does not scale.

**Read Uncommitted as default** - Script 03 confirmed dirty reads of rolled-back monetary values. Unacceptable for fiscal data.

**Serializable as default** - Script 04 confirmed that range locks block all insertions during totalization. Operationally unacceptable at scale.

---

## Lab Evidence

| Script | Finding                                                          |
| ------ | ---------------------------------------------------------------- |
| 02     | Blocking confirmed under Read Committed. RCSI verified active.   |
| 03     | Dirty read captured: 999,999.99 from rolled-back transaction.    |
| 04     | Phantom read under Repeatable Read. Serializable prevented it.   |
| 05     | Physical reads only under SNAPSHOT (123) and SERIALIZABLE (112). |
| 06     | Blocking captured: Session 68 blocked by 62, wait 8,583ms.       |

---

## References

- https://learn.microsoft.com/en-us/sql/t-sql/statements/set-transaction-isolation-level-transact-sql
- https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide
- https://use-the-index-luke.com/sql/transaction-isolation