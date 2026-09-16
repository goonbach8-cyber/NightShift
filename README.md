# NightShift / 03:17

Godot 4.7.2 psychological-horror/mystery prototype: a 2D pixel character working in a 3D gas station. **03:17** is the planned public title; NightShift remains the internal project name.

The user-designated business/story baseline is summarized in [PROJECT_DIRECTION.md](PROJECT_DIRECTION.md). Current controls, menus, products, six prototype nights, story systems, save boundaries and test commands are documented in [VERTICAL_SLICE.md](VERTICAL_SLICE.md).

## Start

Run `project.godot` with Godot 4.7.2. Startup opens the main menu. New Game begins Night 1; Continue restores a safe between-night checkpoint. Start the shift at the staff notes behind checkout.

WASD moves, E interacts/scans/accepts payment, F talks, Space advances dialogue, 1/2 select replies, ESC pauses. TAB selects stock only at warehouse supply. T/Y/+/- control the nearby physical radio; M mutes.

Customers visit Water, Energy and Chips locations, reserve products, queue, pay and leave. Refill matching product displays from warehouse stock, receive deliveries and complete the configured service tasks. Finish at the staff notes to save and advance. These are short functional prototypes, not the six finished story nights.

## Automated checks

Run headlessly without desktop input:

```text
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/menu_test.gd
godot --headless --path . --script res://tests/story_continuity_test.gd
godot --headless --path . --script res://tests/campaign_test.gd -- --six-nights --shift-layout
godot --headless --path . --script res://tests/story_campaign_test.gd
godot --headless --path . --script res://tests/ending_save_test.gd
godot --headless --path . --script res://tests/depot_movement_test.gd
```

Require zero failures and inspect logs for script errors/warnings. `-- --dev-debug` enables optional customer and inventory diagnostics. Controls have been manually verified by the user. The new story geometry, reading comfort and audio impact still require human evaluation; no desktop automation is needed or authorized.

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
