# 03:17 — exact continuation, 17 September 2026

## Direction and constraints

Depth over breadth. Preserve the existing six-night campaign. No Computer Use, native inputs, desktop automation, window focus changes or GUI editor operation. The user works on this PC. CLI/headless/internal Godot InputEvents only. Do not treat the old Windows helper as a gameplay defect.

## Current block: applied and verified

- Previous quota rejection prevented the staged files from reaching the project. This session compared the files, then copied the existing prepared changes; nothing was rebuilt.
- Energy: two columns across three cooler shelves, behind glass. Water: bottles inset onto boards, upper header and posts raised for clearance. Chips unchanged. Actual mesh-bound tests pass all 43 checks, including ordinary camera projection. Projection does not prove occlusion or artistic quality.
- HUD progress counts served plus unserved customers, explicitly labels unserved departures. Night 3 no longer sends the player to the stockroom after its required physical event is presented.
- `night3_departure_test.gd` runs one actual Night-3 shopper through patience expiry, reservation release, real exit, physical rack presentation, remaining real tasks and successful completion. This is a focused edge-case fixture, not a replacement for the seven-customer authored night.
- Existing checkout readiness, contextual panels, restock quantities, separate cooler inspection and padded dialogue background were retained.

## Evidence

Logs live in `C:/Users/e558926/Documents/Codex/2026-09-10/du-arbeitest-direkt-an-meinem-lokalen/outputs/`.

- `resume-depth-{product_placement,checkout_presentation,world_binding,product_route,smoke}.log`: five completed suites, zero failures/errors/warnings.
- `dialogue-guard-night3_departure.log`: strengthened test completed through staff-note finish with all customers unserved, checking actual `world.objective.text`, zero failures/errors/warnings.
- `resume-regression-*.log`: 28-suite batch completed with 497 checks, zero failures/errors/warnings. Additional aisle/queue-passage/depot batch was then started; inspect its final logs.
- `resume-six-campaign.log`: full translated-map six-night regression completed successfully: 341 checks, 39 customers, 69 items, CHF 189.10, saved ending and event/decision history.

## Exact pending work

1. `final-input-six-campaign.log` is **complete**, exit code zero, 341 passed checks and no errors/warnings. It covers all six nights on translated map after the final dialog/selection fixes, 39 customers, 69 items, CHF 189.10 and the saved ending. No test process remains pending from this block. Do not repeat this verification unless a new change warrants it.
2. Dialog input guard is now **applied** in `scenes/main/shift.gd`. `dialogue_input_test.gd` passes all 11 checks: work/door/radio actions blocked while dialogue hides prompts; pause, answers, mute and subsequent work still function. `dialogue-input-before.log` is the retained failing reproduction, not a current regression.
3. Additional depot regression exposed 130 `SCRIPT ERROR: Trying to assign invalid previously freed instance` lines despite exit code zero. Fixed in `shift.gd` and `scenes/player/player.gd`: validate old selected target before assigning it to a typed Node3D. The selected point can disappear as Josh leaves. Use `selection-lifetime-depot_movement.log` as the corrected rerun; do not count the older erroring depot log as successful.
4. `selection-lifetime-*.log` and `dialogue-guard-*.log` are completed, exit zero and no Godot errors/warnings. The former includes 35 checkout/HUD checks, eight translated-map depot checks, 16 prompt checks and 11 dialog input checks. The latter includes the strengthened Night-3 test reading actual HUD text through successful completion.
5. `outputs/resume-verification.json` records **1,101 passed checks in 39 deduplicated completed test runs**, including the final campaign. Workspace `work/world/audit_resume_logs.py` rebuilds the report. It rejects log errors/warnings independently of exit code and replaces the erroring older depot log with its verified rerun. `git diff --check` is clean. `VERTICAL_SLICE.md` is updated.
6. Exact next quality focus: checkout/restocking feedback and normal-camera readability of the corrected product placements. Start from these implemented mechanics, not the old feature backlog. Only change a concrete player-facing weakness, then run its targeted test and appropriate campaign regression. Fresh normal-camera visual occlusion/audio judgment remains manual pending: this Godot build only supports the dummy renderer under its headless display driver. Do not launch a focus-taking graphical process to force that review.

Do not run `work/world/prepare.ps1` or older preparation scripts. No commits, resets or pushes were made. No player/NPC collision shapes or navigation tolerances were reduced.
