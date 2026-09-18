# NightShift / 03:17 — playable prototype

Updated 17 September 2026. Product/story baseline: [PROJECT_DIRECTION.md](PROJECT_DIRECTION.md), derived from the user-designated September business plan. Six connected prototype nights reach the ending; these short test shifts are not five hours of finished story.

## Playing

- Startup opens **New Game / Continue / Settings / Quit**. Existing progress requires confirmation before New Game. Continue accepts a valid checkpoint or backup.
- **WASD** moves. **E** uses the nearest visible interaction. Start and finish at the staff shift notes behind the counter.
- E prompts describe the current action: check stock with empty hands, restock with matching goods, scan the next item, then accept payment. Supply reports a specific blocked-action reason. Delivery prompts list their contents. Small selection hysteresis prevents flicker; already-open doors yield to nearby work surfaces. Hidden objects cannot retain selection. Dialogue hides the background E prompt.
- At the operator side of checkout, **E** scans one item, then accepts payment. The contextual panel names the scanned item, shows scanned/remaining quantities and the scanned subtotal, then switches to the final total. Its background appears only for an actual customer at the service position. Payment confirms the full amount; the next basket starts from zero. Stock and revenue change only on payment.
- **F** talks to the customer at the service position. **Space** advances; **1/2** select offered answers. Special conversations receive a contextual hint. A temporary dialogue background protects text contrast; competing checkout prompts disappear during conversation. Earlier answers alter later dialogue after loading.
- While dialogue is open, hidden E work/door actions and warehouse/radio shortcuts are blocked. Space, answer keys, ESC pause and global mute remain available. Ordinary interactions resume after the last line.
- Water: rear-right bottle shelf. Energy: rear-left cooler. Chips: snack island. Customers visit each matching product location. Stock controls separate visual slots; empty displays are actually empty.
- Water bottles sit within their boards with clearance below the header. Energy occupies two cooler bays over three shelves, behind the glass. Chips retain their existing placement. These placements have mesh-bound and camera-framing checks; final visual occlusion still requires human review.
- At the warehouse supply point, **TAB** selects a product and **E** collects it. Carry one product type; refill only its matching display. Feedback reports transferred quantity and resulting display stock. Collect mixed delivery in the yard and deposit it at supply; full hands are explained before pickup.
- At the cooler, **E** with empty hands checks refrigeration. Restocking Energy and temperature inspection are separate actions; carrying the wrong goods cannot complete the inspection. Night 2 adds waste-bin service. Night 3 instead adds a WC check/cleaning point with a visible floor mark. Task text names the actual action.
- Radio controls work only at the physical radio: **E/T** power, **Y** next track, **+/-** local volume. **M** mutes audio globally.
- **ESC** pauses; Resume, Settings and Main Menu are available. Pause freezes gameplay, customer patience and dialogue input. Resume clears held movement actions.
- At completion, the transition shows customers, items, revenue, lost customers and tasks. Continue writes the safe boundary checkpoint and loads the next night. Returning mid-shift does not save active customers.

## Nights and story prototypes

- Night 1: physical Josh handover before the first shift; the exact 03:17 warning. Six customers, routine tasks, checkout mystery and a two-answer conversation.
- Night 2: Josh sincerely denies the warning. Eight customers, waste task, radio event and a follow-up responding to the saved answer.
- Night 3: seven customers, WC task, a small loaded rack tips beside Mike in the stockroom and stays tipped. Required presentation blocks premature shift completion. A crack and inaccessible road appear later; lost sales cannot block the physical story prerequisites.
- Night 4: six customers and a required depot collection. The physical navigation point starts a compact fade/travel transition; walk to the clerk and ledger, then use the return point. The small depot has floor, bounded yard, counter, clerk and lighting, not a driving simulation.
- Night 5: construction notice with an alternate map and Redwater name, radio announcement, address/company intrusions and routine customer references.
- Night 6: changed station branding, additional road/building geometry, familiar and different customer profiles, and Redwater-Josh's ordinary recognition of Mike without special knowledge. The 03:17 main event changes the sign; completion restores familiar surroundings with a remaining Redwater sign.
- Five physical optional readings are introduced across the nights. Only completed reading counts. Four of five unlock a brief extra Josh call after the normal ending. No visible clue counter and no explanatory lore.
- Interrupted handovers, document readings, depot conversation and consequence dialogue remain available. Completed dialogue consequences are recorded once.
- Events support time, sales, prior event, story flag, task and player-area prerequisites. Configurable spacing prevents simultaneous unrelated events. Text waits for a relevant location; active dialogue postpones presentation and preserves reading time.
- World geometry, Josh/clerk models and ending presentation remain prototypes. Final cinematic timing, layered reality overlap, art and a standalone demo are unfinished. No cause of the phenomenon or Josh backstory has been invented.

## Audio and diagnostics

Settings independently control Master, Radio, SFX and Ambience. The saved `Music` key remains compatible and controls the Radio bus via its parent bus. Cooler, warehouse and wind emitters use Ambience; door and interaction sounds use SFX. Built-in audio is synthesized placeholder material. Custom music and streamer mode remain optional backlog.

Normal HUD omits raw stock/reservation and NPC path diagnostics. Launch with `-- --dev-debug` to expose stock totals and customer state/target/path/wait labels. No native input audit is attached in normal play.

## Tests

Run with Godot 4.7.2 CLI, e.g. `godot --headless --path . --script res://tests/checkout_test.gd`.

- `campaign_test.gd -- --six-nights --shift-layout`: New Game through all six nights to ending on translated map, physical depot interactions, presented main events, boundary saves and customer/reservation cleanup.
- `story_continuity_test.gd`: both answer branches through Save/Load, F conversation, real Area3D, persistent prop displacement and WC interaction.
- `campaign_process_test.gd`: stages 1, 2, 3 in separate processes, sharing a unique `--checkpoint=user://campaign_process_<id>.json` and `--stage=N`.
- `six_process_test.gd`: stages 1 through 7 in separate processes, sharing `--checkpoint=user://six_process_<unique>.json`; boundary fixtures verify stocks, flags, clues, event history and world reconstruction, separately from the full gameplay test.
- `story_campaign_test.gd`, `ending_save_test.gd`: authored sequence, interrupted-reading guards, required Night 3 presentation, low/high clue ending branches and save/load.
- `depot_movement_test.gd`: internal directional inputs verify yard boundaries, solid counter and physical return interaction.
- `customer_profile_test.gd`: familiar/alternate visitors, configured greetings and story priority.
- `checkout_presentation_test.gd`: actual internal E scans/payment, next-basket reset, service-position readiness, contextual panel visibility, dialogue padding and all six task lists.
- `cooler_action_test.gd`: wrong-load rejection, exact restock feedback and explicit refrigeration inspection.
- `product_placement_test.gd`: actual mesh bounds against shelf boards/header/glass, plus projection inside the normal camera frame.
- `night3_departure_test.gd`: patience expiry, actual unserved exit, released reservations, physically presented Night 3 event, remaining tasks and successful staff-note completion.
- `dialogue_readability_test.gd`: authored handovers and customer branches across six nights fit the dialogue area and expose the correct answer controls.
- `dialogue_input_test.gd`: no hidden pickup/restock/door/radio actions during dialogue; normal controls return after closing it.
- `menu_test.gd`, `pause_gameplay_test.gd`: new/continue/backup/settings and frozen gameplay/input while paused.
- `world_binding_test.gd`, `product_route_test.gd`: independent physical product displays, correct routes and wrong-product rejection.
- `event_spacing_test.gd`, `presentation_test.gd`, `narrative_test.gd`: trigger prerequisites, cooldowns, reading time, dialogue and radio restoration.
- `audio_routing_test.gd`, plus existing smoke, inventory, stock, save, service, environment, sidewalk, customer lifecycle/door and queue tests.

Tests use isolated checkpoint files. Controls were manually verified by the user. New story geometry, text readability, scare intensity and audio balance need human review. This session uses only headless CLI and in-engine InputEvents, with no Computer Use or desktop focus changes.
