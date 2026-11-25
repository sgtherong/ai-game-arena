# Skyline Courier 1.0 — commercial candidate

## Registration metadata
Title: Skyline Courier
Version: 1.0
Genre: Action
Description: A three-lane neon delivery game with three districts, parcel quotas, timed survival, armor, boost and magnet upgrades. Desktop keyboard and mobile touch controls.
Release notes: Expanded from the practice prototype into an independent campaign with earned-credit upgrades, three unlockable districts and localized menus.
Controls: Left/right arrows or lane buttons/touch. Space or Boost activates temporary protection. Collect green parcels, gold credits and blue repair capsules; avoid red barriers. Reach the parcel quota and survive the full route.
Concept: Short delivery runs with unlockable districts and session-based equipment progression; three themed environments and a reusable boost system.
AI use: AI-assisted original game code, UI, procedural graphics and synthesized sound design. No third-party paid assets.
State: first-party development candidate, not approved. No persistent progression, account or payment. The package includes the existing Arena SDK; its client telemetry remains provisional.

## CI package
Run Skyline Courier candidate package workflow. Download skyline-courier-review-bundle artifact. Unzip the outer artifact; submit the inner skyline-courier-v1.0.zip, thumbnail.jpg and 3–5 JPEG gameplay evidence files. The test advances the actual game simulation with a fixed random source for deterministic route-clear testing. Screenshots are rendered by the actual browser; not AI concept art. This is a controlled functional test, not observed human gameplay or production RQS. Actual SQS and CQS remain required.

## Review checklist
1. Submit in Creator Studio, consent to AI review and pass SQS.
2. Add the screenshots, controls, concept and AI-use details. Request CQS.
3. Inspect the scores, review evidence and manually play the trusted candidate. Keep the runtime pilot unrequested unless a dedicated worker is available.
4. Approve only when the existing gates and actual administrator review pass. A CQS 60–69 prototype is Test Lab, >=70 is service; below 60 revise.
5. Test with separate consenting player accounts; do not fabricate GPS data. No third-party upload execution in CI.
