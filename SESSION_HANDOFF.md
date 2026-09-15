# Exact continuation — 15 September 2026

## Constraints and product baseline

- User is working on the same computer. **No Computer Use, desktop focus, native keyboard/mouse injection, or GUI editor automation.** Use CLI/headless/in-engine InputEvents. Native keyboard verification remains manual pending.
- User designated `C:/Users/e558926/Downloads/03-17_Businessplan_September_2026.pdf` as the game's foundation. Read all 12 pages; concise internal reference: PROJECT_DIRECTION.md. Public title 03:17, internal NightShift, Mike/Josh, six-night Redwood/Redwater arc. Do not invent an explanation or expand into a large simulator.

## Implemented and verified this block

- Checkout now shows last scanned product, scanned/total/remaining items, scanned subtotal and accept-payment readiness; payment reports final total. Existing atomic reservation/payment logic preserved.
- Night 2/3 follow-up conversation differs for asked/denied Night 1 answers, through actual save/load and F input. Follow-up only opens once per night.
- Night 3 distinct configuration: 7 customers, 9-second spawn interval, WC instead of waste task, main message plus later stockroom physical event.
- Event prerequisites: time, sales, flag, task, previous event, occupied Area3D. Stockroom trigger binds relative to existing supply. Falling carton is a deterministic tween, not unstable rigid-body physics; remains displaced for that night, does not block movement.
- WC floor mark/check point in existing room; E completes configured task and removes mark. Only available when required, cannot repeat after completion.
- Master/SFX/Radio/Ambience routing, including three spatial ambient emitters. Legacy Music setting remains parent of Radio for compatibility. Custom music/streamer mode intentionally deferred as optional in business plan.
- Menu title 03:17. Completion adds lost customers/tasks. Night 1/2 pre-shift text briefings introduce Josh's warning/denial; not an animated Josh scene.
- HUD streamlined, touched notices English. `--dev-debug` enables NPC state/target/path/wait and stock diagnostics; default off.
- README and VERTICAL_SLICE corrected; old instructions wrongly finished at checkout and lacked menus/customers.

## Tests and evidence

26 selected successful logs, **607 PASS assertions**, zero FAIL/SCRIPT ERROR/ERROR/WARNING matches. Manifest: `C:/Users/e558926/Documents/Codex/2026-09-10/du-arbeitest-direkt-an-meinem-lokalen/outputs/test-manifest.json`. This is a count across the selected regression runs, not a claim of 607 independent unit cases.

Key logs in that outputs directory:
- `final-three-nights-cli.log`: 165 checks, complete translated-map Night 1→2→3, 21 customers/36 items/CHF 98.50, WC, stockroom event, tasks, saves, no customer/reservation leftovers. All headless. Later changes only English notices and text briefings; menu/story/smoke retested afterward.
- `briefing-story_continuity.log`: 22 checks, both saved choices, F follow-up, true player-area entry, physical prop and WC E interaction.
- `briefing-menu.log`: 29 checks; `regression-pause_gameplay.log`: 8 checks with active customer/dialogue and blocked inputs.
- `process-night-1/2/3.log`: three separate processes verify boundary state/revenue/stock/flags/history and Night 3 dialogue selection (boundary fixtures; full gameplay separately covered by campaign).
- `scene-lifecycle.log`: 14 checks, stable node count and single event signal/area/prop after teardown/reload.
- `resume-cli-world_binding.log` 51, `resume-cli-product_route.log` 13, `hud-checkout.log` 13.
- Audio/story/player/room/save/stock/navigation regressions listed in manifest.

Earlier failing development logs are preserved: story fixture initially omitted ACTIVE phase, then rebuilt navigation before physics synchronization; pause fixture supplied an untyped empty choice array. These test setup errors were fixed and rerun successfully. Do not treat their old logs as current failures.

## Continue here, no whole-project reanalysis

1. Read PROJECT_DIRECTION.md and this handoff. Verify the last manifest/log tails and local diff.
2. Next meaningful player-facing work: improve Josh's preliminary warning/denial from persistent start text into a compact authored handover conversation, preserving the PDF direction and existing dialogue controls. Keep normal gameplay dominant.
3. Strengthen Night 3 physical evidence presentation from normal camera when a non-focus-stealing render workflow is available; human visual/audio and native input test remain pending. Do not use Computer Use without new explicit permission.
4. Separate optional story/debug panels if useful; extend save compatibility for added product definitions only with migration tests.
5. Full six-night content, road/depot, cracks/Redwater world states, demo, polished sound/assets and release-length pacing remain unfinished. Night 4+ currently reuse following-night template; never call this a complete campaign.

Do not run the old `work/world/prepare.ps1`: it contains stale files and can overwrite improvements. Do not reset, commit or push without the appropriate task scope. Original player frames and colliders were preserved.
