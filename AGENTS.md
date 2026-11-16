# AGENTS.md — 03:17 / NightShift

Permanent operating rules for AI agents working on this project. Read this before changing anything.

## 1. Documentation and source of truth

- `PROJECT_DIRECTION.md` — authoritative product/story baseline and creative boundaries.
- `VERTICAL_SLICE.md` — current playable state, controls, systems and test guidance. Keep it current.
- `README.md` — short entry point for starting the project and running checks.
- `SESSION_HANDOFF.md` and `docs/*` — historical records. Do not treat them as current status.
- The code is the source of truth for implemented behaviour. Documentation can lag behind it.
- Reuse and update existing documentation. Do not create competing status documents or duplicate feature lists.
- When code and documentation disagree, trust the code for current behaviour and ask the user about intended behaviour.

## 2. Creative and gameplay rules

- The user is the creative director. Do not change story, tone, mechanics, balance or scope without explicit approval.
- Preserve the six-night campaign and the established story boundaries unless the user approves a redesign.
- Gameplay redesigns are allowed only when approved by the user.
- Existing gameplay mechanics are functional prototypes. Their existence does not mean they are enjoyable, balanced or finished.
- Player-facing text is English-first.
- Do not invent lore, explanations for the phenomenon, Josh backstory or new canon.
- Respect the intended horror restraint: no monster chase, repetitive jump scares or visible anomaly checklist.
- Do not infer quality from passing tests. Feel, readability, pacing and atmosphere require human review.

## 3. Security and safety restrictions

- Work only inside the NightShift project. Do not access unrelated files, accounts, services or external data.
- Shell commands are allowed for project-local inspection, builds and tests. Do not run destructive broad operations.
- Do not use Computer Use, desktop automation, native input simulation or window-focus changes unless the user explicitly authorizes them.
- Do not install dependencies, download tools or call external services without approval.
- Do not commit, push, rewrite history or change remotes unless the user explicitly asks.
- Inspect existing files before overwriting. Treat unfamiliar changes as potential user work.
- Do not delete or move unrelated files, saves or settings.
- Use isolated `user://` paths for tests. Never clobber the user's normal checkpoint, backup or settings.
- Do not place secrets, credentials or personal data in the repository or logs.
- If a task requires exceeding these limits, stop and explain the limitation instead of proceeding.

## 4. Technical architecture

Godot 4.7.2 project (configuration declares 4.7), GDScript, 1280×720. The configured main scene is `res://scenes/main/menu.tscn`; the gameplay world is `res://scenes/main/main.tscn`. The game combines a 3D station with a 2D `AnimatedSprite3D` player.

### Authority boundaries

| Area | Authority | Rules |
|---|---|---|
| Integration and input routing | `scenes/main/shift.gd` | Wires systems, routes interactions, arbitrates focus. Do not put sale, stock or story rules here. |
| Gameplay rules | `scripts/night_shift_loop.gd` | Owns customers, queue, stock, checkout, tasks and shift completion. |
| Map binding | `scripts/gameplay_layout.gd` | The adapter between physical nodes and gameplay. Prefer adding bindings here over hardcoding paths elsewhere. |
| Story | `scripts/story_world.gd` | Owns story props, flags, dialogue triggers, depot travel and ending presentation. No inventory or sale authority. |
| Night content | `scripts/night_catalog.gd` and night resources | Data definitions only. Runtime state belongs in the loop. |
| Persistence and menu flow | `scripts/shift_save.gd`, `scripts/game_menu.gd` | Validate checkpoints; save only at the between-night boundary. |
| Service systems | `scripts/*_service.gd`, `cctv_system.gd`, etc. | Own their workflow and presentation while active. Do not mutate stock or revenue directly. |
| UI | `scripts/ui/*` | Presentation only. Do not move gameplay rules into UI scripts. |
| Player | `scenes/player/player.gd` | Movement and interaction selection. Do not put game rules here. |

The station is largely assembled at runtime, and gameplay binds to nodes by `NodePath` and named markers. Renaming or moving scene nodes can break interactions without a compile error. Keep bindings explicit and test affected routes.

### Input, focus and player-lock contract

- A modal system owns input only while its `active` state is true.
- Before starting, call the shift's `can_start_interrupt(source)` gate.
- Before handling input or mutating shared state, call `has_interaction_focus(source)` where appropriate.
- Manage `player.controls_locked` and release held movement actions when a panel opens or closes.
- Dialogue outranks work interactions. Only one modal owner may exist at a time.
- Pending interruptions (requests, faults, ringing, drift, spills, returns) must block unrelated interruptions until resolved.
- When adding a modal system, update the focus and pending-state lists in `shift.gd` and add overlap/reachability tests.
- Prefer event-driven input over global polling.

### Save contract

- Checkpoints are versioned and validated. Keep the backup path valid.
- Save only between completed nights. Never serialize live NPCs, reservations or scene paths.
- Any product-ID, field or schema change requires a version bump or explicit migration path.
- Product IDs are shared by data, layout bindings, menu validation and tests; coordinate changes across all of them.
- Test save changes with isolated checkpoint files.

### Content and story conventions

- Use stable `StringName` flags. Optional clue flags follow `clue_<id>`.
- Required story must be physically presented, not merely recorded in event history.
- Interrupted dialogue stays replayable. Completed consequences are recorded once.
- Keep story text in catalog/dialogue data, not in checkout, stock or service logic.
- Treat placeholder geometry, characters and audio as prototypes, not final assets.

## 5. Testing and verification

Run tests through Godot's headless CLI from the project root, for example:

```text
godot --headless --path . --script res://tests/<test>.gd
godot --headless --path . --script res://tests/campaign_test.gd -- --six-nights --shift-layout
```

- Run focused tests first, then the broader campaign, story and save suites.
- Use unique `user://` checkpoint paths where the test supports them.
- Use in-engine `InputEvent`s only. Do not simulate OS-level input.
- Inspect logs for script errors and warnings; require zero failures.
- Do not weaken, skip or delete tests merely to make a change pass. Update a test only when intended behaviour changed with user approval.
- Add regression coverage for changed rules, focus conflicts, save compatibility and physical reachability.
- Headless runs cannot validate camera occlusion, prompt readability, audio balance or the feel of renderer-dependent interactions such as scanning and CCTV feeds.
- No central runner or CI is configured. Run the relevant tests explicitly and record the commands and results in the handoff.
- Distinguish pre-existing failures from regressions. Never claim a test passed unless it was actually run.

## 6. Gameplay quality expectations

- Functional prototype behaviour is not automatically good gameplay. Review whether actions are readable, responsive and consistent with the intended atmosphere.
- Check for input conflicts, stale prompts, unreachable interactions, camera occlusion and unclear feedback.
- Do not tune balance or redesign mechanics based only on automated tests.
- Keep changes scoped and reversible. Avoid opportunistic refactors of unrelated systems.
- Report visual, audio, pacing and readability concerns for human review instead of declaring them verified.

## 7. Multi-LLM handoffs

Write for a developer with no conversation history.

- Before work: read the core documents, inspect the relevant code and identify stale documentation.
- After work: update the current documentation, list changed files, tests run, known gaps and items requiring human review.
- Keep `VERTICAL_SLICE.md` current. Do not create a second status document.
- Update `README.md` when startup, controls or canonical test commands change.
- Leave historical documents labelled as historical; do not rewrite them into current status.
- Report defects found outside the current scope instead of silently fixing unrelated systems.
- Never claim runtime verification or test success that did not happen.
- Leave changes uncommitted for user review unless the user explicitly asks for a commit.

## 8. Workflow

1. Analyze dependencies and relevant existing systems.
2. Plan the implementation sequence.
3. Implement in small, coherent changes.
4. Run focused and broader tests.
5. Update documentation and handoff notes.
6. Stop for user review.

Ask when design intent, scope or verification is ambiguous. Do not invent requirements, lore or acceptance criteria.
