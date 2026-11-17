# NightShift / 03:17

Godot 4.7.2 psychological-horror/mystery prototype: a 2D pixel character working in a 3D gas station. **03:17** is the planned public title; NightShift remains the internal project name.

The user-designated business/story baseline is summarized in [PROJECT_DIRECTION.md](PROJECT_DIRECTION.md). Current controls, menus, products, six prototype nights, story systems, save boundaries and test commands are documented in [VERTICAL_SLICE.md](VERTICAL_SLICE.md).

## Start

Run `project.godot` with Godot 4.7.2. Startup opens the main menu. New Game begins Night 1; Continue restores a safe between-night checkpoint. Start the shift at the staff notes behind checkout.

WASD moves; E interacts. Checkout stays in cashier mode between customers: click a product or press E to scan, then click the card/E or hand over exact change. Cash: click coins or use 1–6; right-click/Backspace undoes; click the tray/Enter hands over. ESC leaves cashier mode; F leaves it to talk. At warehouse Supply, E opens stock selection or returns a crate; Up/Down + E/Enter or 1–9 takes stock. E at the matching shelf restocks. Click delivery cartons to compare with the manifest, E marks a match, R records a mismatch, Enter accepts. Pump keys 1–4 select a dispenser, Up/Down sets prepay, E authorizes. M mutes.

Customers visit Water, Energy and Chips locations, reserve products, queue, pay and leave. Refill matching product displays from warehouse stock, receive deliveries and complete the configured service tasks. Finish at the staff notes to save and advance. These are short functional prototypes, not the six finished story nights.

## Automated checks

Run headlessly without desktop input:

```text
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/menu_test.gd
godot --headless --path . --script res://tests/checkout_pointer_test.gd
godot --headless --path . --script res://tests/cashier_queue_test.gd
godot --headless --path . --script res://tests/cashier_request_handoff_test.gd
godot --headless --path . --script res://tests/stock_handling_test.gd
godot --headless --path . --script res://tests/delivery_physical_test.gd
godot --headless --path . --script res://tests/service_interaction_v2_test.gd
godot --headless --path . --script res://tests/story_continuity_test.gd
godot --headless --path . --script res://tests/campaign_test.gd -- --six-nights --shift-layout
godot --headless --path . --script res://tests/story_campaign_test.gd
godot --headless --path . --script res://tests/ending_save_test.gd
godot --headless --path . --script res://tests/depot_movement_test.gd
```

Require zero failures and inspect logs for script errors/warnings. `-- --dev-debug` enables optional customer and inventory diagnostics. The V2 interactions need a fresh rendered manual playtest; the prior user playtest identified visual and repetition problems. Headless tests do not establish visual polish or enjoyment. No desktop automation is needed or authorized.

## Player-Animation

Seitlich werden acht Einzel-PNGs je Richtung in `assets/sprites/player_side/` mit 8 FPS abgespielt. Die zweite Zyklushälfte enthält einen eigenen Gegen-Schritt mit sichtbar anderer angehobener Fussposition. Kopf und oberer Brustbereich bleiben pixelgleich, alle Frames haben 64×80 Pixel und einen gemeinsamen Bodenkontakt. Links verwendet exakt gespiegelte PNGs ohne zusätzliches Flip-H. Side-Idle besitzt eine eigene Standpose.

Die Ursache lag in den alten Bildposen, nicht in einem ständig neu gestarteten Animationscode. Movement, Kamera und Kollisionskörper wurden für diese Änderung beibehalten. Die Front-/Rückansichten verwenden weiterhin das unveränderte Original-Sheet.

`tools/extract.gd` erzeugt die Frames reproduzierbar aus den im Repository gespeicherten Quellen. Ausführung: `godot --headless --script res://tools/extract.gd`, danach normaler Godot-Import. Details zu Quellen, Erzeugung, Prüfungen und verbleibender Stilisierung stehen in [docs/ANIMATION.md](docs/ANIMATION.md).

## Sichtbare Aufgaben

Water, Energy und Chips besitzen eigene Bestände, Verkaufsorte und sichtbare Produkt-Slots. Verkäufe entfernen passende Visuals, Nachfüllen stellt sie wieder her. Kühlung, Lieferung, Müll und WC sind konfigurierbare Aufgaben an eigenen Orten.

## Grenzen des Prototyps

- Einrichtung, Zapfsäule und Beleuchtung sind einfache Platzhalter, keine fertige Tankstellenkulisse.
- Kunden, Reservierungen, einzelne Scans, Zahlung, Nachfüllen, Lieferung und sichere Spielstände zwischen Nächten funktionieren.
- Audio besitzt getrennte Kategorien, räumliche Atmosphäre und ein Radio mit Mystery-Unterbrechungen. Finale Audioassets und Hörprüfung stehen aus.
- Alle sechs Nächte sind kurze Story-/Gameplay-Prototypen mit einem erreichbaren Ende, keine fünf Stunden fertiger Story. Depot, Josh und Redwater-Geometrie sind bewusst einfache Platzhalter.
- Kein fertiges Release-/Exportpaket. Der optionale Josh-Anruf erweitert das normale Ende und erklärt die Hintergrundgeschichte nicht.

Stand: 16. September 2026. Aktuelle Storytests ausschließlich per Godot CLI, Headless und internen InputEvents; siehe SESSION_HANDOFF.md für genaue Testbelege und Grenzen.
