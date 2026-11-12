# Local screenshots — Assignment 14

The verification runner captures these five images from the local Playwright Chromium browser after it has run the real DOM-XSS scenarios. They are added only after local workstation verification succeeds.

| Filename | Capture |
|---|---|
| 01-dom-xss-lab-interface.png | Arabic RTL application at initial load with the sample payload |
| 02-safe-textcontent-result.png | Literal textContent result; no IMG element is created |
| 03-isolated-innerhtml-proof.png | DOM-XSS proof received from the sandboxed iframe |
| 04-safe-unsafe-comparison.png | Safe and deliberately unsafe paths shown together |
| 05-reset-state.png | Cleared outputs and reset proof state |

Runtime assertions also inspect the iframe sandbox attribute, verify that allow-same-origin is absent, and check that no injected IMG element appears in the main document. The report and SHA-256 manifest are stored under evidence/local-verification/.

Do not include cookies, authentication tokens, or unrelated personal browser information in evidence.
