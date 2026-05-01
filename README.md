# C1300S03 — Isolation Levels as an Architectural Decision

![SQL Server](https://img.shields.io/badge/SQL_Server-2022-CC2927?logo=microsoftsqlserver&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.11%2B-3776AB?logo=python&logoColor=white)

Isolation levels demonstrated as architectural decisions on STN_Lab — a simulated fiscal system with 200K taxpayers, 1.5M declarations, and 1.2M payments.

---

## The Problem

Default Read Committed blocks readers when writers are active. Under concurrent portal reads and batch recalculation jobs, this creates blocking chains during peak filing periods.

---

## Scripts

| File | What it does |
|---|---|
| `01_stn_setup.sql` | Creates STN_Lab and loads all data |
| `02_read_committed_vs_rcsi.sql` | Blocking demonstrated, RCSI enabled |
| `03_dirty_read_demo.sql` | Dirty read captured and rollback confirmed |
| `04_phantom_read_demo.sql` | Phantom read vs Serializable prevention |
| `05_performance_by_isolation_level.sql` | Logical reads and elapsed time across all levels |
| `config.py / connection.py / diagnostics.py / report.py / main.py` | Python DMV diagnostics → .txt report |

---

## Validated Results

| Isolation Level | Elapsed (ms) | CPU (ms) | Logical Reads | Physical Reads |
|---|---|---|---|---|
| READ UNCOMMITTED | 304 | 358 | 23,509 | 0 |
| READ COMMITTED | 88 | 608 | 23,887 | 0 |
| REPEATABLE READ | 137 | 438 | 23,887 | 0 |
| SNAPSHOT | 137 | 687 | 23,887 | 123 |
| SERIALIZABLE | 232 | 688 | 23,887 | 112 |

---

## Decision

Enable RCSI as default. Serializable only for fiscal period closing. Read Uncommitted prohibited for monetary data. Full rationale in `ADR-001`.

---

## How to Run

```bash