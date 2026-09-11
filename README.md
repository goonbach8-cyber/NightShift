# NightShift

Kleiner Godot-4.7-Prototyp: ein Pixel-Character in einer dreidimensionalen Tankstellenumgebung bei Nacht.

## Starten

`project.godot` mit Godot 4.7.2 öffnen und F5 drücken. Der Player und die angeschrägte orthografische Folgekamera verwenden weiterhin die bestehende Szene. Side-Walk und Side-Idle verwenden einzelne PNGs; vorne und hinten bleibt das ursprüngliche Sheet erhalten.

| Aktion | Taste |
| --- | --- |
| Bewegen | WASD |
| Nahegelegenes Objekt benutzen | E |
| Ton aus/an | M |
| Nach abgeschlossener Kontrollrunde neu beginnen | R |

## Spielbare Kontrollrunde

1. Zum Schichtzettel links neben dem Eingang gehen und E drücken.
2. Kühlung hinten links prüfen und Getränke hinten rechts auffüllen, in beliebiger Reihenfolge.
3. An der Kasse rechts neben dem Eingang die Runde abschliessen.

Die Schiebetür in der vorderen Wand lässt sich mit E öffnen. Der kleine Vorplatz ist begehbar. Die Tür schliesst nicht, wenn der Player im Durchgang steht, und öffnet wieder, wenn er während des Schliessens hineinläuft.

## Projektstruktur

- `scenes/main/main.tscn`: Hauptszene, Licht, HUD und Audio-Nodes.
- `scenes/main/shift.gd`: Kontrollrunde, Texte, Neustart und einfache synthetisierte Audio-Platzhalter.
- `scenes/player/player.tscn` / `player.gd`: CharacterBody3D, SpriteFrames, Kamera, Bewegung und Auswahl naher Interaktionen.
- `scenes/levels/prototype_room.tscn`: ursprünglicher Raum.
- `scenes/levels/station.gd`: erzeugt Einrichtung und Vorplatz beim Spielstart und ersetzt die geschlossene Vorderwand durch den Eingang. Diese Ergänzungen sieht man deshalb erst beim Ausführen des Spiels.
- `scenes/interactions/interactable.gd`: gemeinsame Basis für benutzbare Objekte.
- `scenes/interactions/door.tscn` / `door.gd`: wiederverwendbare Schiebetür mit Freiraumprüfung.
- `tests/smoke_test.gd`: automatisierte Regressionstests mit echter Godot-Physik und Input-Ereignissen.

World liegt auf Kollisions-Layer 1, der Player auf Layer 2. Interaktionen sind auf 1,8 Meter begrenzt und prüfen die Sichtlinie gegen World. Es gibt keine Autoloads oder Add-ons.

## Tests ausführen

Im Projektordner mit dem Godot-Kommando bzw. dem vollständigen Pfad zur Godot-Console-EXE:

```text
godot --headless --editor --import --quit
godot --headless --script res://tests/smoke_test.gd
godot --headless --script res://tests/sidewalk_test.gd
```

Erwartet: `NIGHTSHIFT TESTS: 0 failure(s)` und Exit-Code 0. Die Tests decken Bewegungsrichtungen, Diagonaltempo, Animationsfortschritt, schnelle Richtungswechsel, Wandkollisionen, Sichtlinien, Aufgabenreihenfolge, Türsicherheit, Vorplatz, Audio-Umschaltung und Neustart ab.

## Player-Animation

Seitlich werden acht Einzel-PNGs je Richtung in `assets/sprites/player_side/` mit 8 FPS abgespielt. Die zweite Zyklushälfte enthält einen eigenen Gegen-Schritt mit sichtbar anderer angehobener Fussposition. Kopf und oberer Brustbereich bleiben pixelgleich, alle Frames haben 64×80 Pixel und einen gemeinsamen Bodenkontakt. Links verwendet exakt gespiegelte PNGs ohne zusätzliches Flip-H. Side-Idle besitzt eine eigene Standpose.

Die Ursache lag in den alten Bildposen, nicht in einem ständig neu gestarteten Animationscode. Movement, Kamera und Kollisionskörper wurden für diese Änderung beibehalten. Die Front-/Rückansichten verwenden weiterhin das unveränderte Original-Sheet.

`tools/extract.gd` erzeugt die Frames reproduzierbar aus den im Repository gespeicherten Quellen. Ausführung: `godot --headless --script res://tools/extract.gd`, danach normaler Godot-Import. Details zu Quellen, Erzeugung, Prüfungen und verbleibender Stilisierung stehen in [docs/ANIMATION.md](docs/ANIMATION.md).

## Sichtbare Aufgaben

Beim Getränke-Auffüllen erscheinen acht zusätzliche Packungen in den oberen Regalreihen. Der Hinweis wechselt zu „Regal ansehen“. Ein Neustart stellt den Anfangszustand wieder her. Die Aufgabenanzeige hat einen dunklen Hintergrund, damit Weltbeschriftungen sie nicht überlagern.

## Grenzen des Prototyps

- Einrichtung, Zapfsäule und Beleuchtung sind einfache Platzhalter, keine fertige Tankstellenkulisse.
- Aufgaben werden durch eine Interaktion bestätigt; es gibt noch keine Trage-, Kunden- oder Kassiersimulation.
- Audio besteht aus einem leisen Gerätebrummen und einem kurzen Bestätigungston. Ein Hörtest und ausgearbeitetes Sounddesign stehen aus.
- Kein Speichern/Laden, keine NPCs, kein fertiges Spiel oder Exportpaket.

Stand: 11. September 2026. Technisch in Godot 4.7.2 getestet; gerenderte Spiel- und Sprite-Ansichten visuell geprüft. Ein menschlicher Spieltest für das subjektive Bewegungsgefühl bleibt sinnvoll.
