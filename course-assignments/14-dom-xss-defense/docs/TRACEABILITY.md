# Assignment 14 — Requirement Traceability

| Trainer requirement | Implementation | Browser test |
|---|---|---|
| Input field and safe/unsafe buttons | public/index.html | Lab startup test |
| Read input value through getElementById/value | public/assets/app.js | Safe/unsafe action tests |
| Demonstrate unsafe innerHTML | Dedicated sandbox iframe sink | Unsafe event proof test |
| Safe display with textContent | createElement + textContent + appendChild | Literal payload and no IMG test |
| Event-handler payload | IMG onerror emits fixed DOM_XSS_PROOF | Browser proof message test |
| Compare both execution paths | Independent safe panel and sandbox frame | Sequence-independence test |
| Stable browser console | Initialization guard and Playwright pageerror monitoring | Browser test |
| Reset behavior | Clear-results control | Clear/reset test |

## Hosted verification — GitHub Actions run 43151669403

- Windows + Node.js 20: SUCCESS, 6/6 browser tests.
- Windows + Node.js 22: SUCCESS, 6/6 browser tests.
- Ubuntu 24.04 + Node.js 20: SUCCESS, 6/6 browser tests.
- Ubuntu 24.04 + Node.js 22: SUCCESS, 6/6 browser tests.

Total: 4/4 jobs and 24/24 browser-test executions passed.

Learner workstation execution and original screenshots are intentionally deferred to the GitHub-first submission phase and must not be inferred from CI.