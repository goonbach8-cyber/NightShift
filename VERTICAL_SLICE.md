# NightShift / 03:17 — playable prototype

Updated 15 September 2026. Product/story baseline: [PROJECT_DIRECTION.md](PROJECT_DIRECTION.md), derived from the user-designated September business plan. Six authored nights remain the target; current short test shifts are not five hours of finished story.

## Playing

- Startup opens **New Game / Continue / Settings / Quit**. Existing progress requires confirmation before New Game. Continue accepts a valid checkpoint or backup.
- **WASD** moves. **E** uses the nearest visible interaction. Start and finish at the staff shift notes behind the counter.
- At the operator side of checkout, **E** scans one item, then accepts payment. The contextual panel names the scanned item, shows scanned/remaining quantities and the scanned subtotal. Stock and revenue change only on payment.
- **F** talks to the waiting customer. **Space** advances; **1/2** select offered answers. Special conversations receive a contextual hint. Earlier answers alter later dialogue after loading.
- Water: rear-right bottle shelf. Energy: rear-left cooler. Chips: snack island. Customers visit each matching product location. Stock controls separate visual slots; empty displays are actually empty.
- At the warehouse supply point, **TAB** selects a product and **E** collects it. Carry one product type; refill only its matching display. Collect mixed delivery in the yard and deposit it at supply.
- **E** checks refrigeration. Night 2 adds waste-bin service. Night 3 instead adds a WC check/cleaning point with a visible floor mark.
- Radio controls work only at the physical radio: **E/T** power, **Y** next track, **+/-** local volume. **M** mutes audio globally.
- **ESC** pauses; Resume, Settings and Main Menu are available. Pause freezes gameplay, customer patience and dialogue input. Resume clears held movement actions.
- At completion, the transition shows customers, items, revenue, lost customers and tasks. Continue writes the safe boundary checkpoint and loads the next night. Returning mid-shift does not save active customers.

## Nights and story prototypes

- Night 1: 6 customers, 8-second spawn spacing, refrigeration/restock/delivery. Guaranteed checkout mystery and a two-answer conversation.
- Night 2: 8 customers, 6-second spacing, waste task, radio event and a follow-up responding to the earlier answer.
- Night 3: 7 customers, 9-second spacing, WC task, its own main-event text and a later stockroom-triggered carton movement. The carton remains displaced during the night.
- Events support time, sales, prior event, story flag, task and player-area prerequisites. Configurable spacing prevents simultaneous unrelated events. Text waits for a relevant location; active dialogue postpones presentation and preserves reading time.
- This is prototype content. Josh's full handover/denial, new road, depot, Redwood/Redwater transitions, authored Nights 4–6 and standalone demo are not implemented.

## Audio and diagnostics

Settings independently control Master, Radio, SFX and Ambience. The saved `Music` key remains compatible and controls the Radio bus via its parent bus. Cooler, warehouse and wind emitters use Ambience; door and interaction sounds use SFX. Built-in audio is synthesized placeholder material. Custom music and streamer mode remain optional backlog.

Normal HUD omits raw stock/reservation and NPC path diagnostics. Launch with `-- --dev-debug` to expose stock totals and customer state/target/path/wait labels. No native input audit is attached in normal play.

## Tests

Run with Godot 4.7.2 CLI, e.g. `godot --headless --path . --script res://tests/checkout_test.gd`.

- `campaign_test.gd -- --three-nights --shift-layout`: complete 3-night loop on translated map, checkout, stock, tasks, story, boundary saves and customer/reservation cleanup.
- `story_continuity_test.gd`: both answer branches through Save/Load, F conversation, real Area3D, persistent prop displacement and WC interaction.
- `campaign_process_test.gd`: stages 1, 2, 3 in separate processes, sharing a unique `--checkpoint=user://campaign_process_<id>.json` and `--stage=N`.
- `menu_test.gd`, `pause_gameplay_test.gd`: new/continue/backup/settings and frozen gameplay/input while paused.
- `world_binding_test.gd`, `product_route_test.gd`: independent physical product displays, correct routes and wrong-product rejection.
- `event_spacing_test.gd`, `presentation_test.gd`, `narrative_test.gd`: trigger prerequisites, cooldowns, reading time, dialogue and radio restoration.
- `audio_routing_test.gd`, plus existing smoke, inventory, stock, save, service, environment, sidewalk, customer lifecycle/door and queue tests.

Tests use isolated checkpoint files. Native Windows keyboard/focus testing and fresh human visual/audio review are pending. This session uses only headless CLI and in-engine InputEvents, with no Computer Use or desktop focus changes.
