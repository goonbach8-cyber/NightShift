# NightShift

Kleiner Godot-4.7-Prototyp: ein Pixel-Character in einer dreidimensionalen Tankstellenumgebung bei Nacht.

## Starten

`project.godot` mit Godot 4.7.2 öffnen und F5 drücken. Der Player und die angeschrägte orthografische Folgekamera verwenden weiterhin die ursprüngliche Szene und Grafik.

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
- `scenes/player/player.tscn` / `player.gd`: CharacterBody3D, Original-SpriteFrames, Kamera, Bewegung und Auswahl naher Interaktionen.
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
```

Erwartet: `NIGHTSHIFT TESTS: 0 failure(s)` und Exit-Code 0. Die Tests decken Bewegungsrichtungen, Diagonaltempo, Animationsfortschritt, schnelle Richtungswechsel, Wandkollisionen, Sichtlinien, Aufgabenreihenfolge, Türsicherheit, Vorplatz, Audio-Umschaltung und Neustart ab.

## Player-Animation: Befund und Grenze

Das Original-Sheet bleibt unverändert: 512×320 Pixel, vier Richtungsreihen, jeweils acht Bilder à 64×80 Pixel. Die Ausschnitte und die Reihenfolge 0–7 sind passend, die Walk-Schleifen laufen mit 8 FPS. Der alte Code startete sie bereits nicht bei jedem Frame neu.

Ein vorhandener lokaler Importzustand war ungültig (`valid=false`); Godot konnte die Player-Textur nicht laden. Die korrigierte `.png.import` wird nun versioniert, verwendet verlustfreie Kompression ohne Mipmaps und behält Nearest-Filtering in der Player-Szene bei.

Die Bewegung verwendet jetzt eine richtungsunabhängige Beschleunigung. Die Animation folgt der tatsächlichen horizontalen Bewegung nach der Kollision, läuft beim Abbremsen langsamer und steht vor einer blockierenden Wand still. Richtungswechsel innerhalb von Walk erhalten Frame und Fortschritt des Schrittzyklus.

**Die seitliche Laufbewegung ist grafisch noch nicht vollständig gelöst.** In den acht seitlichen Ausgangsbildern bleibt eine breite Beinstellung bestehen; klare Passing-Posen fehlen. Dadurch kann der Lauf trotz korrekter Wiedergabe weiter wackelnd wirken. Umordnen oder andere FPS erzeugen diese fehlenden Posen nicht. Der nächste gezielte Grafikschritt ist, Bein-Zwischenposen unter Beibehaltung der vorhandenen Figur zu ergänzen. Es wurde kein Ersatz-Character eingeführt.

## Grenzen des Prototyps

- Einrichtung, Zapfsäule und Beleuchtung sind einfache Platzhalter, keine fertige Tankstellenkulisse.
- Aufgaben werden durch eine Interaktion bestätigt; es gibt noch keine Trage-, Kunden- oder Kassiersimulation.
- Audio besteht aus einem leisen Gerätebrummen und einem kurzen Bestätigungston. Ein Hörtest und ausgearbeitetes Sounddesign stehen aus.
- Kein Speichern/Laden, keine NPCs, kein fertiges Spiel oder Exportpaket.

Stand: 10. September 2026. Technisch in Godot 4.7.2 getestet; gerenderte Spiel- und Sprite-Ansichten visuell geprüft. Ein menschlicher Spieltest für das subjektive Bewegungsgefühl bleibt sinnvoll.
