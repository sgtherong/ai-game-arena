# AI review operations — technical preview

## Activation and acceptance
1. In Supabase Edge Function Secrets set OPENAI_API_KEY from an API project with billing enabled. Never commit or paste the secret into chat or client code. Default model: gpt-4.1-mini; optional ARENA_REVIEW_MODEL must support image input and strict JSON schema.
2. Use a trusted developer/admin to upload the Star Sprint QA ZIP, with separate PNG thumbnail. Give explicit consent for source, images, thumbnail and metadata transfer. A positive fixture is not guaranteed to pass a probabilistic model.
3. Inspect AI status and reason. If Passed (score >=75 and all concern flags false), check the administrator review queue and manually run only the trusted fixture. If blocked/error, verify preview/approve remain unavailable. Retry allowed only within server limits.
4. Verify stored score, checked image count and package SHA, and confirm that the previous published version stays available until new approval. No third-party URL fetching.
5. Do not run submitted untrusted packages in this repository's Actions runners or on the portal origin. Current scanner is static heuristic triage, not malware certification. No real public launch until runtime isolation and independent malicious-file validation are in place.

## Proposed runtime QA service (not deployed)
Use a separate disposable worker pool with no platform credentials inside the execution container. A trusted orchestrator retrieves the immutable ZIP from private storage, verifies SHA-256, performs bounded unpacking without following links, and passes files read-only into an ephemeral browser sandbox on a separate origin. No outbound network, private-network access, host mounts, persistent profiles or clipboard. Enforce CPU, memory, file size, request and time ceilings, kill timed-out processes, destroy container after each job. Use a dedicated vetted browser image and patch regularly. The browser's report is untrusted input; only the orchestrator writes final results.
- Check DOM/canvas readiness, visible nonblank output, broken assets, console/page errors, blocked requests, excessive CPU/timeouts, touch/keyboard input, viewport overflow at desktop/mobile.
- Capture minimal diagnostic screenshots and logs (strip secrets); no external upload without recorded permission.
- Run scripted inputs for a bounded period. A smoke result is not proof of fun, game completion, ownership, malware freedom or accessibility.
- Bind all results to version ID and package hash. Future DB gate should require static and AI and runtime pass before human approval. Do not enable the additional mandatory runtime gate until the isolated worker is available and tested. Preserve the existing mandatory AI gate.
- Agent-assisted gameplay is a later, separate stage: genre-specific goals, controlled input budget, reproducible trajectories and evidence, not automatic publishing decisions.

## Known limitations
AI input limits: ZIP 2 MB compressed and expanded, source 60 KB, at most 8 PNG/JPEG/WebP images including thumbnail and 1 MB combined image payload. Animated GIF is unsupported by this implementation; audio/video content is not semantically reviewed. Heuristic detection is incomplete; false positives/negatives possible. AI calls fail closed without a valid API key, accessible model and billing. Static reports must not claim actual playtesting. Existing demo games are legacy-approved; new versions are gated.
