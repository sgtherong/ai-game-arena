# v0.98 RQS and AI-planned runtime QA

Status: trusted pilot only. Requires the dedicated disposable VM and worker token described in docs/runtime-qa-v097.md. Do not run arbitrary public uploads, and do not interpret Docker alone as a hostile-code sandbox.

The worker API optionally asks the configured OpenAI model to choose 3–8 allowed inputs from genre and consented CQS controls/concept. No game source, screenshots, secrets, signed URLs or code execution instructions are sent by this planner. On API failure it returns a fixed scripted plan. The runner independently validates the plan, includes start/center probes, dispatches only allowlisted actions, and never executes model-generated code. This is preplanned, not adaptive AI gameplay.

The runner captures before/after screenshot bytes in memory and stores SHA-256 hashes only. No actual image files are uploaded or retained, and no visual AI analysis is performed. Changed hashes can reflect animation or timers, not necessarily input causality. Browser requestAnimationFrame cadence is not engine FPS. No completion, fun, difficulty, or long-session stability claim.

RQS uses desktop/mobile averages, calculated by a DB trigger only on complete rqs-observation-v1 reports. Each viewport: load 20, visible DOM/canvas 15, viewport width 15, no page/blocked-request errors 20, input dispatch 10, screenshot change 5, browser rAF cadence 10 (>=50:10, >=30:7, >=15:3), load latency 5 (<=2s:5, <=5s:3). RQS is independent of SQS/CQS/GPS and does not change existing approval rules or upgrade CQS automatically. Old reports and errors remain unscored.

Build updated image: `docker build -t arena-runtime-pilot:0.98 runtime-qa`. Run local trusted fixture as in v0.97. For live pilot set worker token/project URL only in the dedicated VM environment. The GitHub Actions workflow uses a first-party fixture and no live credentials. Public submission isolation, adaptive screenshot-based agent, screenshot consent/storage, measured game performance and actual end-to-end worker connection remain separate acceptance items.
