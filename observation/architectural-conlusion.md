# Architectural Conclusion - C1300S03

The isolation level is not a configuration detail - it is a commitment about what the system guarantees and what it trades away.

For STN_Lab the workload is mixed: batch jobs update declaration records while portal users read the same data concurrently. Under default Read Committed, these two workloads collide. This was measured in the lab - 44 seconds of wait time under LCK_M_S, and 8,583ms captured by the Python diagnostics script under a full object-level Exclusive lock on the Declaracion table.

The correct answer for this workload is RCSI. Readers consume committed row versions from TempDB instead of competing for shared locks. No dirty reads. No reader-writer blocking. Transparent to the application - no code changes required. The cost is TempDB version store growth, which must be monitored.

Two exceptions apply. Snapshot Isolation for auditor workflows that need a consistent view across multiple queries in the same session. Serializable for fiscal period closing - Script 04 confirmed that without range locks, a phantom row can appear between two reads of the same totalization range.

The principle: understand the mechanism, match it to the workload, and document the trade-off. That is what separates an architectural decision from a default that nobody questioned.