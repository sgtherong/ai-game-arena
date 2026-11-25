# v1.0 closed-beta readiness — first-party practice collection

## Included
- Existing three portal demos remain in the database with their original unassessed status. Seven new playable first-party prototypes live at /practice/: Meteor Tap, Skyline Courier, Prism Breaker, Signal Sequence, Circuit Flip, Grid Runner and Pulse Timing.
- Desktop and mobile controls, 45-second rounds, pause/resume, replay, local best records, Korean/English interface.
- Practice Lab is intentionally not registered as SQS/CQS-passed or commercial quality. No accounts, portal session telemetry, GPS, payment, or publishing eligibility are produced by it. Local storage is limited to practice high scores; no analytics request is added by the lab.
- Main portal has a first-party collection entry and onboarding guide; existing authentication, SQS/CQS, QA queue and API budget stay in place.

## Pre-launch acceptance
1. Run the portal and practice smoke workflow. Check all seven games on desktop and mobile, screen layout, input dispatch, pause/resume and language toggle. Smoke is not full functional, accessibility, game-balance or commercial-quality validation.
2. Recruit a small trusted internal tester group; do not label the publicly accessible Pages site a private or invitation-only beta. If access restriction is needed, implement it before sharing beyond internal testers.
3. Manually test actual SQS -> CQS using consented screenshots and a trusted pending game version. Confirm API accounting and admin decision before publication. Existing rejected versions must remain rejected.
4. Validate PC/mobile play, ratings, GPS sample gates with real consenting test accounts, without synthetic scores or fabricated reviews.
5. Confirm operator identity, support contact, data retention/deletion, processing notices and applicable legal terms before commercial public launch.
6. Keep third-party untrusted game execution disabled in shared CI. Dedicated reviewed isolation is still required for automatic public-submission QA. CI fixture results are not live game RQS reports.
7. Maintain the existing daily/monthly AI call caps and default disabled AI planner; check OpenAI billing independently. No new paid server was created.

## Content maturity
This collection is a playable prototype portfolio, not ten commercial-ready games. The existing three portal demos plus the seven lab games provide ten playable concepts. A subsequent content pass needs visual/audio production, difficulty tuning, playtesting, runtime QA and independent SQS/CQS approval for promotion to service catalog.
