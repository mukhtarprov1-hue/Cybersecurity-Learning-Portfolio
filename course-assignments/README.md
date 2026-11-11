# Cybersecurity Camp 2026 — Public Assignment & Evidence Index

<div align="center">

**Instructor-facing submission portal**  
**Learner:** Mukhtar Alawady · **Track:** Cybersecurity Camp 2026

[![Repository](https://img.shields.io/badge/GitHub-Public%20Repository-181717?logo=github)](https://github.com/mukhtarprov1-hue/Cybersecurity-Learning-Portfolio)
[![Language](https://img.shields.io/badge/Primary%20Language-C17-00599C)](https://en.cppreference.com/w/c/17)

</div>

This is the public, instructor-accessible index for the assignments documented in this repository. Each assignment has a dedicated landing page. Opening an assignment should provide the task brief, requirements-to-code traceability, source files, build/run instructions, test plan, observed evidence, report, limitations, and the submission route where known.

> **Review principle:** The trainer should be able to understand the task, locate the implementation, reproduce the result, and distinguish verified evidence from items that are still pending—without searching through unrelated portfolio projects.

## Assignment register

| ID | Assignment | Public status | Open |
|---|---|---|---|
| 01 | Password Checker in C | Source, tests, Arabic report, instructor notes, local logs, rendered execution evidence, traceability, and a successful hosted CI run are publicly available. Strict GCC build and 8/8 functional/boundary checks passed; GitHub Actions succeeded. | [Review Assignment 01](01-password-checker/README.md) |
| 02 | Not recorded in the currently available task briefs | **Awaiting the original task description.** No assignment has been invented or marked complete. | Not published |
| 03 | Hexadecimal Viewer in C | Source, test runner, sample generator, Arabic report, execution logs, terminal-output captures, and CI workflow are public. Local reference validation: 5/5 tests passed. GitHub Actions run 42075036584: SUCCESS (Ubuntu 24.04.5; 5/5 tests passed). | [Review Assignment 03](03-hexadecimal-viewer/README.md) |
| 04 | Log File Parser in C | C source, Arabic task specification/report, traceability matrix, reviewer guide, synthetic log generator, local execution logs, five labelled SVG terminal renders, and GitHub Actions evidence are public. Strict C17 build passed locally and in hosted CI; 10/10 integration tests passed. Hosted run 42397397647: SUCCESS. | [Review Assignment 04](04-log-file-parser/README.md) |
| 05 | Multithreaded Port Scanner in Python | Python source, 11 unit tests, Arabic task transcription/report, requirements traceability, Windows Winsock handling, and a Windows/Ubuntu CI workflow are public. The observed Windows loopback timeout is documented; the updated test suite still needs to be rerun on the learner's Windows machine. | [Review Assignment 05](05-multithreaded-port-scanner/README.md) |

## Submit to the trainer

Read the [Arabic submission handoff guide](SUBMISSION_GUIDE_AR.md) before sending a link. It distinguishes the public GitHub package from the trainer's required Discord/LMS submission step and records which assignment thread is actually known.

## How to review a submission

1. Open the assignment landing page from the register above.
2. Read its **task brief** and **acceptance-criteria matrix** first.
3. Open the linked source code and build it using the documented command.
4. Run the test suite and compare the observed output with the evidence and expected behavior.
5. Read the report and limitations. Do not treat a configured CI workflow as a successful run until its run page shows success.
6. Use the assignment's Discord/thread route when the camp requires a separate submission post.

## What each assignment package should contain

- **Task definition:** original brief or a clearly marked faithful transcription, objectives, constraints, and acceptance criteria.
- **Implementation:** source files, directory structure, dependencies, and reproducible build/run instructions.
- **Verification:** test plan, test runner, expected versus observed results, and reproducible logs.
- **Evidence:** readable screenshots or terminal captures with honest labels and no secrets or personal data.
- **Report:** Arabic/English technical explanation, decisions, results, limitations, and conclusion.
- **Submission record:** repository path, commit/reference, delivery thread when known, and review status.

## Submission status vocabulary

| Status | Meaning |
|---|---|
| BRIEF-RECORDED | Task requirements have been documented. |
| IMPLEMENTED | Source code is present. |
| LOCALLY-VERIFIED | Build/tests were run in a named environment and evidence is retained. |
| CI-PENDING | Workflow exists, but no successful hosted run has been verified. |
| CI-VERIFIED | A named hosted workflow run completed successfully; the run URL and tested commit are recorded. |
| SUBMITTED | The required course submission channel has received the link/files. |
| REVIEWED | Trainer feedback or grading is recorded. |
| ACCEPTED | Trainer has explicitly confirmed acceptance. |

A public GitHub link alone does **not** prove that the assignment has been submitted to the camp, graded, or accepted.

## Public/private boundary

This public repository contains learner-created code, task-specific documentation, synthetic test data, and non-sensitive evidence intended for instructor review. It does not contain private course rosters, personal documents, credentials, private lab targets, access tokens, or restricted trainer materials. The private course workspace remains separate.

## Reusable preparation standard

See [Operating Model & Quality Gate](OPERATING_MODEL.md) for the lifecycle and required structure used to prepare future assignments. The goal is consistent, auditable submissions—not simply a folder containing source code.
