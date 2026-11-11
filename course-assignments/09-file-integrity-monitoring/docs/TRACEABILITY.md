# Requirements-to-Code Traceability — Assignment 09

| Assignment requirement | Implementation | Verification |
|---|---|---|
| Read target file in binary mode | calculate_sha256() opens with rb | SHA-256 known-content test |
| Calculate SHA-256 | hashlib.sha256() and hexdigest() | Known digest comparison |
| Read large files in chunks | Configurable chunk_size, default 65,536 bytes | Small-chunk test |
| Create initial baseline | create_baseline() writes JSON | Baseline create/load test |
| Persist baseline | Atomic temporary write and os.replace() | Baseline load test |
| Recalculate periodically | while True plus time.sleep() | Manual continuous-mode demonstration |
| Compare current and stored hashes | check_integrity() | Unchanged and modified tests |
| Alert on a one-character change | Critical alert on digest mismatch | Single-character edit test |
| Handle a missing file | MISSING result and critical alert | Deleted-file test |
| Keep baseline after detected change | No automatic rewrite of the baseline | Baseline preservation test |
| Stop without corrupting state | Graceful KeyboardInterrupt handling | Manual Ctrl+C check |

## Review notes

- The automated tests validate the core hashing and comparison behavior.
- A manual two-terminal demonstration is still required to capture the continuous polling loop and observed critical alert.
- Local Windows test results and screenshots remain pending until the learner runs and captures them.
