# Runtime QA pilot v0.97

The deployed platform provides an admin-requested version-specific queue, private result rows, a lease-based worker API, a fail-closed requested-job approval gate and owner/admin report UI. This does not yet run automatically: a dedicated worker must be configured. Existing games and unrequested manual review remain unchanged. Do not queue before the worker is ready. Never queue arbitrary public developer code; this is a trusted pilot only.

## Deployment and secret setup

1. Provision a separate disposable Linux test VM with Docker. Do not run this on a production host, on an employee workstation with sensitive files, or on a shared CI runner with untrusted uploads. The Docker prototype uses Chromium without its inner sandbox and is NOT a sufficient hostile-code boundary. A production public-submission worker needs an independently reviewed VM/microVM isolation layer, patched browser, resource enforcement, egress denial, lifecycle cleanup and monitoring.
2. Create a random worker token of at least 32 characters (e.g. use a password manager's generator). Set it as ARENA_RUNTIME_WORKER_TOKEN in Supabase Edge Function Secrets and in the dedicated worker environment. Do not commit the token or give it to the game/browser process. The endpoint checks the token server-side; service-role credentials remain in Supabase.
3. Clone the repository to the dedicated VM and build: `docker build -t arena-runtime-pilot:0.97 runtime-qa`.
4. Generate and run the local trusted fixture first: `python3 runtime-qa/make_fixture.py /tmp/arena-fixture.zip`; `python3 runtime-qa/worker.py --trusted-pilot --fixture /tmp/arena-fixture.zip`. No credentials or live DB needed.
5. Set ARENA_SUPABASE_URL to the project URL and the worker token in the VM environment. Only after verifying the fixture, use Admin Console → Review queue → Queue trusted runtime QA on a known trusted version with SQS passed and CQS >=60. Run one job: `python3 runtime-qa/worker.py --trusted-pilot`.
6. Verify the owner/admin report. The worker downloads a short-lived signed package URL, verifies SHA-256 against the SQS-reviewed version and runs the package in a disposable container with no external network, read-only root, no capabilities, no credentials, memory/CPU/PID/time limits. The only host file mounted is the read-only ZIP. The orchestrator submits the report via the scoped endpoint. No service key in the runner.
7. A queued job blocks approval until passed. Failure or expired leases can be retried up to three attempts; otherwise reject and submit a new version. Manual preview/approval remains available for not-requested jobs during the pilot. Do not interpret a pass as approval to launch an untrusted game.

## Scope
PC 1280×720 and mobile 390×844, DOM/canvas presence (not pixel-level blank screen analysis), page error and HTTP resource error counts, outbound-request attempts, input dispatch (not observed gameplay response), viewport width and load time. No measured CPU/FPS/long-session stability, AI gameplay, screenshots or market score changes. The worker reports raw booleans and the database decides pass/fail. The report is bound to the package hash and lease. Static CQS remains provisional; runtime results do not silently increase it. Public launch is not approved by this prototype.

The separate GitHub Actions workflow tests only a first-party generated fixture, never a submitted ZIP. Browser portal smoke tests use mock API responses. The actual worker on a dedicated VM and the live endpoint are still acceptance-test items.
