# NightShift / 03:17 — playable prototype

Updated 16 November 2026. Product/story baseline: [PROJECT_DIRECTION.md](PROJECT_DIRECTION.md), derived from the user-designated September business plan. The six playable chapters now incorporate the Mike, Josh and Lea story foundation. The shifts are still short.

## Playing

- Startup opens **New Game / Continue / Settings / Quit**. Existing progress requires confirmation before New Game. Continue accepts a valid checkpoint or backup.
- **WASD** moves. **E** uses the nearest visible interaction. Start and finish at the staff shift notes behind the counter.
- E prompts describe the current action: check stock with empty hands, restock with matching goods, scan the next item, then accept payment. Supply reports a specific blocked-action reason. Delivery prompts list their contents. Small selection hysteresis prevents flicker; already-open doors yield to nearby work surfaces. Hidden objects cannot retain selection. Dialogue hides the background E prompt.
- At the operator side of checkout, **E** opens a close counter view. Grab the visible product with the left mouse button and sweep it across the scanner, or hold **A/D**. Routine items arrive barcode-ready; **wheel / W/S** rotates if needed. Vertical dragging no longer unexpectedly rotates the product. Click the physical card or press **E** to tap it. For cash, click coin compartments or press **1–6**, right-click/Backspace to undo, then click the handover tray or press **Enter**. Arrow selection + E remains available. ESC cancels unpaid checkout; paid receipt/printer recovery cannot be cancelled. The camera restores afterward. Stock and revenue still change only on payment.
- **F** talks to the customer at the service position. **Space** advances; **1/2** select offered answers. Special conversations receive a contextual hint. A temporary dialogue background protects text contrast; competing checkout prompts disappear during conversation. Earlier answers alter later dialogue after loading.
- While dialogue is open, hidden E work/door actions and warehouse/radio shortcuts are blocked. Space, answer keys, ESC pause and global mute remain available. Ordinary interactions resume after the last line.
- Water: rear-right bottle shelf. Energy: rear-left cooler. Chips: snack island. Customers visit each matching product location. Stock controls separate visual slots; empty displays are actually empty.
- Water bottles sit within their boards with clearance below the header. Energy occupies two cooler bays over three shelves, behind the glass. Chips retain their existing placement. These placements have mesh-bound and camera-framing checks; final visual occlusion still requires human review.
- At the warehouse supply point, **E** opens the product list. It shows warehouse units, the current shelf count and free shelf slots. Select a row with the mouse or **↑/↓**, then click **Take** or press **Enter**. **Esc** closes it. An open carried crate shows its real product/count (up to eight). **E** at its matching shelf places the load in one brief visible burst; movement is not locked. **E** back at Supply returns unused stock, freeing your hands without forcing a refill. With a delivery in hand, **E** stores it directly instead.
- The sales floor extends west and north (16.4 × 12 m gross floor). Three gondolas are spaced with about 1.8 m of clearance between them, with a rear cross-aisle in front of the cooler and coffee wall. The original entry and service doorway keep their positions. The established checkout and queue positions remain in place, with a clear approach from the front cross-aisle.
- At the cooler, **E** with empty hands checks refrigeration. Restocking Energy and temperature inspection are separate actions; carrying the wrong goods cannot complete the inspection. Night 2 adds waste-bin service. Night 3 instead adds a WC check/cleaning point with a visible floor mark. Task text names the actual action.
- Radio controls work only at the physical radio: **E/T** power, **Y** next track, **+/-** local volume. **M** mutes audio globally. A failed retune closes the tuner but reports that the signal was not restored.
- **ESC** pauses; Resume, Settings and Main Menu are available. Pause freezes gameplay, customer patience and dialogue input. An open service, delivery, maintenance or checkout panel consumes ESC to close itself first, and closing any panel releases held movement keys. Resume also clears held movement actions.
- At completion, the transition shows customers, items, revenue, lost customers and tasks. Continue writes the safe boundary checkpoint and loads the next night. Returning mid-shift does not save active customers.

## Campaign chapters

Each night uses the same work loop and has a separate personal objective. The shift board advances the next available story interaction or closes the night once work and all required story interactions are complete. Closing a story dialogue early leaves it available. The HUD lists remaining work separately from Mike's goal.

- Night 1: Josh warns Mike, the counter phone rings at the staffed till, and Mike records what happened at the shift board. Answering, declining or missing the call all allow the follow-up.
- Night 2: Josh denies the warning. Hear the local broadcast, then record the discrepancy at the shift board.
- Night 3: Witness the checkout and stockroom changes, then hear Josh's confession about Lea. Required events depend on presentation, and no successful sale is needed to reach the confession.
- Night 4: Take the existing road to the depot, collect the replacement stock and use the clerk's desk again for Lea's call. Then return to the station.
- Night 5: Read the construction notice through to the end, hear the broadcast and complete the work before following the route into Redwater.
- Night 6: Meet Lea at the staff notes. After the overlap and the remaining work, use the access road to confirm the return. The original shift board leads to the ending and its optional Josh call.

Chapter milestones use the existing story flags in between-night checkpoints. These scenes are short foundations for the psychological-horror campaign. They do not represent its eventual length or final presentation.

## Existing story-world systems

- Existing customer counts, orders and work schedules remain in use. Night 2 adds waste-bin service and Night 3 adds a physical WC check. The depot retains its compact fade/travel transition and bounded, walkable yard.
- The construction notice, branding, road geometry and Redwater customer profiles remain. The route uses the existing road in both directions. Josh and Lea's added chapter conversations reuse the existing dialogue and placeholder character models.
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
- `chapter_progress_test.gd`: required story gates, a missed 03:17 call, interrupted dialogue and a stock check when every shelf is already full.
- `warehouse_picker_test.gd`: real keyboard and mouse events, live stock counts, disabled pickup states, inventory conservation and focus release.
- `shop_aisles_test.gd`: direct capsule movement through the three longitudinal aisles, plus routes to displays, staff space, stockroom and entrance.
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
- `modal_input_test.gd`: real ESC events across phone, pump, CCTV, breaker, radio and checkout panels; visible ESC hints, repeated open/close, Pause arbitration and held-movement release.
- `checkout_pointer_test.gd`: actual camera-projected pointer grabs/sweeps, wrong-facing rejection, empty-space protection, card tap, physical coins, denomination keys, exact-change handover and restored camera.
- `stock_handling_test.gd`: physical crate quantities for all products, conservative/idempotent stock return, placement of actual shelf merchandise and settled transforms.
- `world_binding_test.gd`, `product_route_test.gd`: independent physical product displays, correct routes and wrong-product rejection.
- `event_spacing_test.gd`, `presentation_test.gd`, `narrative_test.gd`: trigger prerequisites, cooldowns, reading time, dialogue and radio restoration.
- `audio_routing_test.gd`, plus existing smoke, inventory, stock, save, service, environment, sidewalk, customer lifecycle/door and queue tests.

Tests use isolated checkpoint files. Earlier controls were manually verified by the user; redesigned interactions below have not yet received a human playtest. New story geometry, text readability, scare intensity and audio balance need human review. This session uses only headless CLI and in-engine InputEvents, with no Computer Use or desktop focus changes.

## Gameplay redesign research and priorities (16 November 2026)

Source scope: public descriptions/review text fetched directly; no gameplay video was watched. The observations below are source-backed, but the proposed benefits are design hypotheses, not evidence of enjoyment in NightShift.

| Reference / verified source | Observed mechanic | Principle and original NightShift adaptation |
|---|---|---|
| [Supermarket Simulator — developer description](https://store.steampowered.com/app/2670630/Supermarket_Simulator/) | Unpack/organize/place stock; scan items; cash and credit payments; layout supports shopping flow. | Make input correspond to merchandise/equipment. Grab the actual counter product, sweep across scanner, click card/coins. Keep the small fixed product catalog, not pricing/expansion simulation. Exact mouse controls were not established by this source. |
| [Gas Station Simulator — developer description](https://store.steampowered.com/app/1149620/Gas_Station_Simulator/) | Fuel/shop/repair services, deliveries with lead time, competing customer demands, optional management depth. | Variety should change attention/location, not just overlay labels. Preserve quiet intervals rather than import peak-hour pressure or business expansion. |
| [Gas Station Simulator — Destructoid review](https://www.destructoid.com/reviews/review-gas-station-simulator/) | Short simple minigames can avoid drudgery; repeated scanning eventually tires; objectives introduce warehouse/staff in stages. | Shorten rote manipulation, reserve exceptions for later shifts. Do not add tasks merely to reach five hours. This is a critic's assessment, not our own playtest. |
| [The Convenience Store — developer description](https://store.steampowered.com/app/1228520/Chillas_Art_The_Convenience_Store/) | Night-shift psychological horror; primarily walking/puzzle interaction; approximately 40 minutes; atmosphere emphasized. | Protect observation time and readable surroundings. Retain our hybrid camera/art and six-night structure, not its VHS presentation. Specific chore controls/pacing are not verified by the description. |
| [Papers, Please — developer description](https://store.steampowered.com/app/239030/Papers_Please/) | Documents plus inspection/search/fingerprint tools inform consequential entry decisions. | Checking should require comparing evidence, not approving identical prompts. Retain delivery mismatches; later improve spatial document/carton comparison. No copied rules, dialogue, or interfaces. Gradual rule escalation is established design knowledge, not verified here. |

### System audit and ordered plan

Code audit, not a subjective playtest. P1/P2/P3 indicate implementation priority, not current completion. Each row covers purpose/readability, agency/responsiveness/feedback, repetition/steps/depth, atmosphere/story fit, and maintenance value.

| System / current flow | Weakness and proposed flow / benefit | Cost, risk and verification |
|---|---|---|
| **P1 checkout**: E focus → move/rotate each item → payment → occasional decline/jam → receipt. | Purpose clear but indirect relative dragging and mandatory barcode search dominate routine; cash cycles denominations. Use object-grab/sweep, ready-facing stock, optional correction, direct card/coin input. Physical response and the existing beep should make cause/effect legible. Keep exact change, undo and later exceptions for depth. Good routine/story anchor; worth maintaining. | Medium. Ray mapping, focus, fast motion, cancellation races, camera restoration and payment duplication. Real pointer/key tests, exact revenue, interrupted animation and campaign/save suites. Human review of occlusion, speed and sound essential. |
| **P1 stocking/object handling**: supply Tree → take capped crate → walk → E transfers all. | Clear stock counts, weak physical placement; all-or-nothing refill and sealed colored box conceal quantities. Next: a short visible placement burst with interruptible progress, real remaining goods and no per-bottle click tax. Retain route/product matching as meaningful choice. Environmental story potential is high; do not build general physics inventory. | Medium. Reservations, partial loads, interruption/reach, duplicate transfers. Conservation, wrong shelves/full shelves, simultaneous customer pickup, save boundary tests. |
| **P1 customers**: profile → route/browse/reserve → queue → sale or patience expiry; later requests divert checkout. | Browsing and baskets exist, but responses mostly live in hidden status strings; assistance is deterministic. Next: readable orientation/reach/acknowledgment at actual work points; communicate waiting needs without floating dashboards. Avoid new AI hierarchy or invented dialogue/lore. Strong story value. | Medium. Paths/queue order, repeated cues, story dialogue priority. Queue stress, browse/reserve lifecycle, request/reach and campaign checks. |
| **P2 delivery**: timed parcel → modal label/manifest comparison → accept mixed load → supply. | Checking quantities has agency, but selecting text rows replaces handling and all cartons become one box. Next: select visible cartons beside manifest, mark discrepancies in place, one manageable trip rather than haul every item. Keep comparison, remove navigation tax. Strong grounded source of narrative variation. | Medium/high. Actual vs ordered stock, zero quantities, cancellation, physical access. Discrepancy/conservation/reach tests and rendered label checks. |
| **P2 pumps**: waiting vehicle → preselected correct pump/limit → E → brief wait → vehicle vanishes or reset outside. | Too little player judgment; acknowledgment masquerades as fueling. Next: show request beside actual pump selector, authorize, visibly dispense/complete before departure; avoid reflex stop-meter copied from another game. Outside resets should be occasional meaningful relocation. | Medium/high. Pending interrupt ownership, vehicle lifetime, revenue authority (pumps currently do not sell inventory). Focus/reach, wrong pump/limit, fault/cancel and pacing tests. |
| **P2 cleaning / WC / waste**: fetch mop, alternate edges, return; WC/bin are one press. | Mop movement/stain reduction has feedback but fixed pass count becomes busywork; WC/bin have little agency. Next: short spatial coverage with visible dirt disappearing under mop; retain tools/return only where location creates atmosphere. No extra daily chore quotas. | Medium. Completion/cancel and reachable surfaces; mop focus/return and campaign tests. Low complexity is appropriate; vary locations rather than repetitions. |
| **P2 equipment**: fetch toolkit → select 3 screws, twice each → R → return. | Physical screws exist but input is a rote six-click checklist. Next: directly manipulate visible panel latch and reset identifiable fault; reuse counter ray mapping only if it serves the tool, not a universal minigame. | Medium. Partial repair state, escape during reset, return lock. Service/focus, replay and physical-reach tests. |
| **P3 power**: symptom → select breaker → reset. | Purpose/feedback reasonably clear, shallow but appropriately rare. Better physical tripped-switch state is more valuable than extra puzzle rules. Preserve atmospheric light loss and recovery. | Low/medium. Shared light state; wrong switch, restore/teardown tests. |
| **P3 CCTV**: choose feed → watch 0.7s → acknowledge. | Feeds connect to space; acknowledgment itself is thin and overlays tell the answer. Future alerts should motivate observing the world, not a visible anomaly checklist. Keep optional surveillance; no invented scares. | Medium. Rendered feeds, visibility and story conflicts; CCTV/focus tests plus human observation. |
| **P3 radio / phone**: tuner steps/confirm; keypad/call/choices/log. | Audio tuning and handset are useful grounded narrative tools; repeated explicit confirm and keypad work can slow routine. Preserve authored calls and station discovery; prioritize tactile dial/handset feedback over more menus. | Low/medium. Story flags, canceled/replaced calls, hidden-station discovery. Existing phone/radio/story suites; audio requires listening. |
| **P3 targeting/UI**: proximity/hysteresis → contextual E prompt; modal keys vary. | Nearby service points compete; many panels teach a different arrow-key workflow. Use E to enter/act, ESC to leave, direct object input where valuable, retain keyboard routes. No generic full-screen interaction framework. | Medium. Modal precedence, held-key leakage, camera transforms, viewport scaling. Modal, UI, reach and actual input tests. |

Sequence: finish checkout and its regressions before changing another major system; then physical stocking/customer response, then delivery/pumps, then maintenance. Shared candidates: camera-projected object picking and bounded feedback tweens, not shared sale/task rules. No checkpoint schema or story changes planned.

### Implemented packages and review

1. **Direct counter handling.** Replaced arbitrary relative dragging/vertical rotation with camera-ray counter-plane dragging that starts only on the visible product. Fast sweeps cannot skip the scan zone. Products start correctly oriented, eliminating the repeated hidden-barcode hunt; manual rotation and wrong-facing rejection remain. Camera moves to a readable equipment view and restores on exit. Physical card taps animate; cash supports clickable denominations, hover selection, direct number keys, undo and a labeled handover tray. Arrow-key controls remain, using the same transaction authority. Cancel/reopen sessions invalidate old scan/card continuations. No new products, sale rules, story text or save fields.
   - Files: `scripts/checkout_minigame.gd`, `tests/checkout_pointer_test.gd`, and the deliberately changed ready-facing expectation in `tests/checkout_minigame_test.gd`.
   - Benefit hypothesis: less control translation and rote manipulation while retaining a physical sweep and meaningful change correction. Weaknesses: no conveyor/basket choice, original receipt wait and deterministic decline/jam schedule remain. Keyboard scan can sweep multiple staged products when held.
2. **Readable and reversible stock handling.** Replaced the sealed stock box with an open crate displaying actual merchandise/count; mixed deliveries retain a lid rather than appear empty. Placed products settle onto the real authored shelf slots. Added return-to-storage at Supply with exact conservation, allowing a change of plans without finishing the load. Restock remains one action, not eight clicks or a hold-time chore. The stock picker remains a menu: this is an incremental stock-handling improvement, not the planned full spatial warehouse redesign.
   - Files: `scripts/shop_inventory.gd`, `scripts/night_shift_loop.gd`, `scripts/gameplay_layout.gd`, `scenes/main/shift.gd`, `tests/stock_handling_test.gd`; warehouse/interaction tests updated for the approved return action instead of the old blocked action.
   - Benefit hypothesis: visible load and placement, recoverable task choice, no additional modal/input owner. No checkpoint schema change; return/placement cannot serialize live animation state. Physical placement does not postpone the authoritative inventory transaction.

Technical results: all of the following ran through `godot --headless --path . --script res://tests/<name>.gd`, exit 0, with no reported script errors/warnings:
- Checkout/input: `checkout_pointer_test`, `checkout_minigame_test`, `checkout_lifecycle_test`, `modal_input_test`, `checkout_presentation_test`, `ui_quality_test`, `pause_gameplay_test`, `dialogue_input_test`.
- Stock/customer integration: `stock_handling_test`, `warehouse_picker_test`, `interaction_quality_test`, `cooler_action_test`, `inventory_test`, `stock_test`, `product_placement_test`, `customer_browsing_test`, `customer_lifecycle_test`, `service_reach_test`, `interruption_pacing_test`.
- Broader checks: `smoke_test`, `scene_lifecycle_test`, `phone_system_test`, `radio_tuner_test`, `story_continuity_test`, `story_campaign_test`, `ending_save_test`, `save_test`.
- `godot --headless --path . --script res://tests/campaign_test.gd -- --six-nights --shift-layout` passed twice, including after final code changes. No ObjectDB warning reproduced.

New-test failures encountered and corrected: an assertion before the camera restore tween completed, a hardcoded product name rather than catalog text, and a cancellation fixture creating another customer after exhausting its real shelf stock. The fixture now replenishes through actual inventory APIs; no production checks were disabled. No remaining failure in the executed suites. `git diff --check` passed. Changes remain uncommitted; the pre-existing untracked `tests/modal_input_test.gd.uid` was preserved.

Rendered verification unavailable under current restrictions: this Windows Godot build lists only the dummy renderer for its headless display driver. No native window/focus changes were used. Camera projection/input and final transforms are tested, but object occlusion, perceived speed, readable coin labels, sound balance and enjoyment are **not verified**.

Manual playtest: serve several mixed baskets using only mouse; try a fast sweep and an intentional wrong rotation; retry a declined card; build wrong change then undo and hand it over; ESC during a scan/tap then reopen; pick each stock type, return one untouched, refill another, and inspect the cooler/shelf placement from the existing camera. Evaluate whether the counter view is comfortable and whether the simplified scan remains satisfying after ten baskets. Do not extend this routine to five hours without authored story/pacing work.
