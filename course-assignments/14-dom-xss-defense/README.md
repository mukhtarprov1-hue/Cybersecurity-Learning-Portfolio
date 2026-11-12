# Assignment 14 — DOM Interaction & DOM-XSS Defense

**Course:** Cybersecurity Programming — Web & JavaScript  
**Implementation:** HTML5 · CSS · Vanilla JavaScript · Playwright  
**Branch:** feat/assignment-14-dom-xss-defense  
**Hosted CI:** verified — 4/4 jobs passed on Windows and Ubuntu with Node.js 20 and 22. [Run 43151669403](https://github.com/mukhtarprov1-hue/Cybersecurity-Learning-Portfolio/actions/runs/43151669403).  
**Learner workstation evidence:** deferred until the GitHub-first submission phase is complete.

## Objective

Demonstrate how inserting untrusted input into an HTML parsing sink such as innerHTML can create DOM-based XSS, and how textContent safely treats the same value as literal text.

## Key design decision: demonstrate safely

The intentionally vulnerable innerHTML sink is demonstrated inside a sandboxed iframe with a unique opaque origin. The frame grants scripts only (no allow-same-origin, forms, popups, downloads, or top navigation). Its Content Security Policy permits only inline scripts and data: images for the controlled proof payload while blocking network connections and external resources.

The supplied proof payload triggers a harmless image error handler and sends a fixed DOM_XSS_PROOF message to the parent. It does not display an alert, read cookies, inspect the parent DOM, exfiltrate data, or contact an external server. The parent accepts the proof message only from its own sandbox frame with an opaque origin. This shows that the unsafe sink can execute an event handler without exposing the learner's main page to the test payload.

The safe branch creates a PRE element, assigns the untrusted value through textContent, then inserts the element using appendChild(). The payload is shown literally and is not parsed as markup.

## Features

- Arabic/RTL responsive lab interface.
- Editable HTML/JavaScript payload field with a built-in sample.
- Separate controls for unsafe innerHTML and safe textContent rendering.
- Sandboxed unsafe demonstration with a constrained CSP.
- Live status messages for the safe and unsafe results.
- createElement(), textContent, appendChild(), and clear/reset behavior.
- No external runtime dependency in the application itself.

## Project layout

    14-dom-xss-defense/
    ├── public/
    │   ├── index.html
    │   └── assets/
    │       ├── app.js
    │       └── style.css
    ├── tests/
    │   ├── server.js
    │   └── dom-xss.spec.js
    ├── package.json
    ├── playwright.config.js
    ├── tools/
    │   ├── verify-and-capture.ps1
    │   └── capture-evidence.js
    ├── TASK_SPEC_AR.md
    ├── docs/
    │   ├── REPORT_AR.md
    │   ├── SECURITY_ANALYSIS_AR.md
    │   ├── TRACEABILITY.md
    │   └── REVIEWER_GUIDE_AR.md
    └── screenshots/
        └── README.md

## Automated browser tests

The test suite uses Playwright and Chromium. It covers page startup, safe literal rendering, the isolated innerHTML event proof, separation of the two sinks, clear/reset behavior, and normal text input.

    npm install --no-audit --no-fund
    npx playwright install chromium
    npm test

**Hosted verification — GitHub Actions run 43151669403:**
- Windows + Node.js 20 — PASS (6/6 browser tests).
- Windows + Node.js 22 — PASS (6/6 browser tests).
- Ubuntu 24.04 + Node.js 20 — PASS (6/6 browser tests).
- Ubuntu 24.04 + Node.js 22 — PASS (6/6 browser tests).

Total: 4/4 CI jobs and 24/24 browser-test executions passed. The test suite runs Chromium in headless mode and checks the isolated event proof and safe rendering.

## Local workstation verification runner

After checking out the assignment branch, run the PowerShell 5.1-compatible verification script from the project directory:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\verify-and-capture.ps1

The runner checks Node.js and the Git branch, installs the pinned Playwright dependency and Chromium, executes all six browser tests, captures five local Chromium screenshots, and generates an Arabic verification report, JSON summary, and SHA-256 manifest. It stages only files under Assignment 14, then commits and pushes them to the same feature branch. Use the NoPush switch to leave the evidence commit local.

The standalone preview remains available with node tests/server.js at http://127.0.0.1:4173. Do not expose this training server to a network.

## Security notes

- Do not use innerHTML with untrusted input in normal application code. Use textContent for text. If rich HTML is a business requirement, use a well-maintained sanitizer and a strict allow-list.
- The deliberately vulnerable sink exists only to teach the distinction and is confined to a unique-origin iframe with a restrictive CSP.
- The event proof is intentionally harmless and does not use alert() or access cookies.
- The sandbox is a defence-in-depth control for this demonstration, not a substitute for safe DOM APIs.
- A CSP does not repair an unsafe sink; the primary fix is not to parse untrusted strings as HTML.
- Browser evidence captured from the learner's workstation will be added in the later local phase. CI browser tests are not presented as personal desktop screenshots.

## Acceptance mapping

| Trainer requirement | Implementation | Verification |
|---|---|---|
| HTML input and two buttons | public/index.html | Browser test |
| Read input value with JavaScript | public/assets/app.js | Browser tests |
| Demonstrate innerHTML risk | Sandbox-only innerHTML sink | Browser proof message test |
| Safe textContent rendering | createElement + textContent + appendChild | Literal text/no element test |
| HTML/event payload | Controlled img onerror proof payload | Isolated frame event execution test |
| Stable browser console | Vanilla JS with initialization checks | Playwright pageerror assertion |
| No exposure of parent document | iframe sandbox without allow-same-origin | Browser sandbox assertion |

## Submission

- Pull Request #5: https://github.com/mukhtarprov1-hue/Cybersecurity-Learning-Portfolio/pull/5
- Project page: https://github.com/mukhtarprov1-hue/Cybersecurity-Learning-Portfolio/tree/feat/assignment-14-dom-xss-defense/course-assignments/14-dom-xss-defense
- Discord: submit in the trainer's Assignment 14 thread.