# Genuine Windows execution screenshots

Save original screenshots captured from the learner's PowerShell window. Do not fabricate or edit terminal output to resemble a successful execution.

Recommended captures:

1. \`01-help.png\` — \`python banner_grabber.py --help\`.
2. \`02-local-services.png\` — service ports available on the learner's own localhost/lab.
3. \`03-ssh-banner.png\` — SSH immediate-banner test (the automated test creates its own local fixture).
4. \`04-http-head.png\` — HTTP HEAD request and response (the automated test creates its own local fixture).
5. \`05-unit-tests.png\` — complete \`unittest\` output.
6. \`06-cli-results.png\` — final banner-grabbing output on an authorized target.

If no SSH/HTTP service is running locally, do not invent a screenshot. The automated unit tests already simulate these services with local TCP listeners; capture the test output instead.
