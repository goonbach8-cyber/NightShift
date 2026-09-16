# 03:17 — continuation, 16 September 2026

## Current direction (latest user instruction)

**Stop expanding breadth. Improve depth.** The six-night campaign is technically connected. Prioritize existing player-facing interactions/prompts, shopping/queue behavior, checkout, shelf stock, restocking/delivery, tasks, dialogue/event presentation and night differentiation. Do not implement old backlog items merely because they are absent. Preserve the full campaign after major changes.

No Computer Use, native keyboard/mouse, window focus or GUI automation. The user works on this PC and has manually verified controls. Use files/CLI/headless/internal InputEvents. Human evaluation of new visual/audio presentation remains pending; an old Windows helper failure is not a gameplay bug.

## Implemented story foundation

- Night 1 physical Josh greeting, exact phone warning, departure and early guaranteed checkout mystery.
- Night 2 physical Josh contradiction; saved answer changes later conversation.
- Night 3 small loaded rack tips near Mike and stays tipped. Shift completion requires its presented flag. Later crack/new-road geometry; Night 3 route is closed. Required story is not dependent on successful sales, so lost customers cannot make it unreachable.
- Night 4 work-related depot route, short travel transition, actual bounded collection yard/counter/clerk/ledger, and return interaction. No vehicle simulation.
- Night 5 construction map/name contradiction, radio announcement, wrong address/company/product signage, routine Redwater mention.
- Night 6 different surrounding road/building geometry and branding, familiar/other customer profiles, Redwater-Josh without phenomenon knowledge. Ending returns to familiar station with one Redwater sign.
- Five optional physical documents introduced across nights. Completed readings count uniquely; interrupted readings do not. Four of five enable a short optional Josh call after the normal ending. No visible clue counter or explanation of the phenomenon.
- Interrupted handovers, depot dialogue and story follow-ups remain available. Follow-ups become seen only after finishing the conversation.

These are compact functional story/world prototypes, not final cinematic presentation, final art, five hours of content or a finished commercial game.

## Interaction depth pass

- Contextual E prompts distinguish checking stock, matching restock, next scan and accepting payment. Wrong carried goods do not promise restocking.
- Supply failure feedback names the actual reason instead of listing three possible causes. Delivery prompt includes manifest.
- Dialogue hides background E prompt. Small 0.12 m selection hysteresis avoids flicker, but never extends range or bypasses walls.
- Hidden objects cannot remain selected. Open doors have a 0.25 m selection penalty when competing with a work surface; closed doors unchanged. This fixes an actual delivery interaction selecting StoreDoor instead of Supply.
- Josh now meets Mike near the arrival position, away from water/supply/checkout/shift-note interaction zones.

## Tests / evidence

Logs are in `C:/Users/e558926/Documents/Codex/2026-09-10/du-arbeitest-direkt-an-meinem-lokalen/outputs/`, not inside the repository.

- `six-final-campaign.log`: complete New Game → Nights 1–6 → saved ending, translated map, physical depot E interactions, all main presentations, exact CHF 189.10 / 39 customers / 69 items, no NPC/reservation leftovers. Later depth changes have a separate campaign run.
- `six-process-1.log` through `six-process-7.log`: isolated boundary fixtures across seven processes; nights, stock, revenue, decisions, event history, clues, world states and ending eligibility preserved. Not a substitute for full gameplay.
- `story-recovery-verified.log`: authored sequence, interrupted-reading guards, Night 3 required presentation/no-sale recovery, geometry and optional-call threshold.
- `story-final-ending_save.log`: actual ending UI with 0/3/4 clues, safe save/load; ordinary ending works without clues.
- `final-customer_profile.log`: data-driven known/alternate customers, greetings and story priority; interrupted consequence stays available.
- `depot-movement.log`: all four directions blocked at yard bounds; clerk/counter and return remain reachable.
- `interaction-quality-verified.log`: contextual prompts, flicker resistance, range/visibility, reproduced open-door/supply competition.
- Final depth campaign and regression status must be taken from the latest manifest/logs, not assumed from this handoff or the older 607-check baseline.

Old failing logs are retained. Fixed causes: optional reading points stole product/radio prompts; Josh stole board/water selection; open StoreDoor stole supply interaction; an old dialogue test used abort as completion. Only count the corresponding successful reruns.

## Exact next work

1. Check completion/status of `depth-six-campaign.log` and `depth-regression-*.log`; do not repeat a whole-project analysis.
2. Finish validating interaction depth changes before altering shopping/queue behavior. Reproduce any remaining action-selection error rather than masking it with broader distance tolerances.
3. Next quality target: shopping/queue transitions from a player's perspective (abrupt product pickup, readable waiting/serving state, avoiding hesitation/blocking), using the existing customer state machine. No new gameplay system required.
4. Human review later: normal-camera legibility, rack/depot/Redwater geometry, dialogue pacing, radio/scare intensity. Do not attempt native input or focus-taking graphics tests.

Do not run old `work/world/prepare.ps1`; it contains stale files. No Git reset, commit or push was done. Player art, movement dimensions and collision sizes remain intact.
