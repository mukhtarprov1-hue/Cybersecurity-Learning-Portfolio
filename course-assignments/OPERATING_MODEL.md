# Assignment Operating Model & Quality Gate

This standard governs how each Cybersecurity Camp assignment is prepared for public instructor review. It is based on established practices from repository documentation, reproducible software testing, performance-based cybersecurity assessment, and LMS assignment workflows.

## 1. Lifecycle

| Stage | Required action | Evidence / output | State recorded |
|---|---|---|---|
| 1. Intake | Capture the trainer's original brief, task number, due date if known, allowed tools, and submission route. | TASK_SPEC_AR.md or source brief link | BRIEF-RECORDED |
| 2. Decomposition | Translate every requested behavior into acceptance criteria. Do not invent scoring weights. | Requirements/traceability matrix | SPEC-MAPPED |
| 3. Implementation | Build the requested artifact with a readable project structure and documented dependencies. | Source code and project README | IMPLEMENTED |
| 4. Verification | Compile/run with warnings, functional tests, negative tests, boundary cases, and reproducible test data. | Test plan, test runner, logs | LOCALLY-VERIFIED |
| 5. Hosted validation | Inspect the actual GitHub Actions run, commit, job, and step results. | Link to a successful workflow run, if successful | CI-VERIFIED or CI-PENDING |
| 6. Evidence | Capture real output or label generated renderings honestly. Keep raw logs where useful. | Screenshots, terminal captures, logs, sample artifacts | EVIDENCE-READY |
| 7. Reporting | Explain objective, design, implementation, tests, results, limitations, and reproducibility. | Arabic/English report | DOCUMENTED |
| 8. Publication | Confirm public visibility and verify every linked file opens without login. | Public URLs and checked file inventory | PUBLIC-READY |
| 9. Submission | Post the exact assignment link/files in the trainer's specified channel or LMS. | Submission link/time/message reference | SUBMITTED |
| 10. Review | Record trainer feedback, requested changes, grade, and explicit acceptance only when received. | Feedback and revision record | REVIEWED / ACCEPTED |

## 2. Required assignment folder

Every assignment should follow this baseline, omitting only sections that truly do not apply:

    NN-assignment-name/
    ├── README.md                   # Instructor-facing landing page
    ├── TASK_SPEC_AR.md             # Original brief or faithful transcription
    ├── src/                        # Source code (or files at root for small tasks)
    ├── tests/                      # Test code and test cases
    ├── samples/                    # Synthetic/non-sensitive fixtures only
    ├── docs/
    │   ├── REPORT_AR.md             # Technical report
    │   ├── REVIEWER_GUIDE_AR.md     # Five-minute reviewer walkthrough
    │   └── TRACEABILITY.md          # Requirement -> code -> test -> evidence
    ├── evidence/
    │   ├── build.log
    │   ├── test.log
    │   └── output.log
    ├── screenshots/                 # Genuine screenshots / clearly labelled renders
    └── .gitignore

For a small C exercise, src/ may be omitted and the single .c file kept at the root to reduce needless nesting.

## 3. What the trainer should see on first click

The assignment-level README.md is the landing page. Its opening section must answer, without scrolling through source code:

1. **What is this?** Assignment ID, exact title, course, language/tool, learner, and current delivery status.
2. **What was requested?** A short summary and a direct link to the full task specification.
3. **What was built?** A concise outcome statement and direct source-code link.
4. **How do I verify it?** Exact build and run commands plus one-command tests.
5. **Where is the proof?** Screenshots/terminal outputs, raw logs, report, and hosted CI link/status.
6. **What remains?** Honest pending items, limitations, and the required submission route.

Use relative links within the repository so they remain valid when the repository is forked or downloaded.

## 4. Evidence rules

- Separate **expected** results from **observed** results.
- Record compiler/runtime versions and operating system for local verification.
- Save the exact command and exit status for important runs.
- A screenshot is an image of a displayed result; an SVG/PDF generated from logs must be labelled as a rendered terminal transcript, not as a direct screen capture.
- Do not say "CI passed" unless a successful hosted workflow run has been inspected.
- Do not claim "submitted", "graded", or "accepted" based only on a commit.
- Use only synthetic fixtures. Never expose passwords, keys, private invitations, private class records, or sensitive network captures.

## 5. Traceability and assessment

Each task requirement should be traceable through four elements:

**Trainer requirement -> implementation location -> test case -> evidence artifact**

The trainer's rubric and weighting are authoritative. If the trainer did not provide a rubric, use a review checklist without inventing marks or percentages.

Suggested technical review dimensions (not an official camp grading scheme):
- Correctness against the task brief.
- Code readability and use of required language/library calls.
- Error handling and boundary behavior.
- Reproducibility of build and test steps.
- Quality and honesty of evidence.
- Explanation of limitations and safe handling of sample data.

## 6. Submission and feedback

The Git repository is the canonical public artifact archive. The trainer's requested LMS, Discord thread, or other channel is the submission/notification route. Send the assignment-specific link rather than asking the trainer to browse the whole profile. Keep the commit history intact so changes are auditable. Add a release or version tag only when a stable submission snapshot is useful.

## 7. Future assignment template

Use the assignment template at TEMPLATE/README.md when a new task is received. Do not create a completed assignment page until the official task brief and required deliverables are known.

## 8. External standards and platform references

These references inform the documentation and evidence process; they are not presented as the camp's own grading policy.

- **NIST NICE Framework:** use task, knowledge, and skill language to describe the capability being demonstrated. Map only the capabilities that genuinely apply to the assignment: [NIST SP 800-181 Rev. 1](https://www.nist.gov/publications/workforce-framework-cybersecurity-nice-framework).
- **GitHub README guidance:** a README is often the first information a visitor sees and should explain purpose, usefulness, getting started, help, and maintainership: [GitHub — About READMEs](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes).
- **Moodle assignment workflow:** the learner-facing assignment page can show submission status, grading status, due date, time remaining, last modified, and submission details; instructors can use rubrics and feedback: [Moodle 5.3 — Using Assignment](https://docs.moodle.org/503/en/Viewing_an_assignment) and [Moodle 5.3 — Assignment permissions and grading workflow](https://docs.moodle.org/503/en/Assignment_permissions).
- **GitHub Classroom is not a current option:** GitHub officially retired the Classroom service on August 28, 2026. Do not rely on Classroom workflows for a new camp process; existing repositories remain unaffected: [GitHub Changelog — Classroom deprecated](https://github.blog/changelog/2026-08-27-github-classroom-deprecated/).

For this learner's current camp handoff, GitHub is the public code/evidence archive, while the trainer's specified Discord thread remains the submission notification route. If the camp later provides an LMS, use that LMS for formal submission and grading status rather than treating GitHub commits as a grade.
