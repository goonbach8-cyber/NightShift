# Side-Walk – Stand 11. September 2026

## Ursache und Umsetzung

Das alte Sheet enthielt seitlich fast nur eine breite Beinstellung. Eine andere Bildreihenfolge oder wiederholte Änderungen am Animationscode konnten daraus keinen vollständigen Schrittzyklus machen. Der erste PNG-Entwurf enthielt zwar Übergangsposen, wiederholte aber in der zweiten Hälfte zu ähnlich die erste Bewegung.

Die Frames 05–08 wurden deshalb gezielt aus der bereits vorbereiteten verbesserten Vorlage übernommen: Das nähere Bein nimmt die Gegenstellung ein, die Ferse hebt hinten ab und das Bein schwingt sichtbar nach vorne. Die unterschiedliche Helligkeit der Beine unterstützt ihre Trennung. Frames 01–04 bleiben erhalten.

Der bestehende AnimatedSprite3D spielt acht direkte PNG-Texturen pro Seite mit 8 FPS ab. Es gibt eine neutrale Side-Idle-Pose pro Seite. Die linken Dateien sind exakt horizontal gespiegelte Gegenstücke; zusätzliches Flip-H bleibt aus. Kopf und oberer Brustbereich sind pixelgleich, alle Bilder sind 64×80 Pixel gross, der unterste sichtbare Walk-Pixel liegt immer auf Zeile 79. PNG-Import: verlustfrei, keine Mipmaps; Darstellung: Nearest-Filtering.

Das ursprüngliche Sheet für vorne/hinten, Player-Bewegung, Kamera, Kollisionen und die vorhandene Animations-Zustandslogik bleiben erhalten. Die Seitengrafik ist eine stilisierte, zum vorhandenen Mitarbeiter passende Neuzeichnung aus der vorausgegangenen Imagegen-Session.

## Reproduzierbare Erzeugung

```text
godot --headless --script res://tools/extract.gd
godot --headless --editor --import --quit
godot --headless --script res://tests/sidewalk_test.gd
godot --headless --script res://tests/smoke_test.gd
```

`tools/extract.gd` verwendet ausschliesslich im Repository vorhandene Quellen unter `tools/animation_sources/`. Die Quelldateien sind durch `.gdignore` vom normalen Godot-Import ausgeschlossen und werden nur für die Offline-Erzeugung gelesen. Das Spiel verwendet die einzelnen PNGs unter `assets/sprites/player_side/`, keinen Atlas für Side-Walk. Es besteht keine Laufzeitabhängigkeit von Codex-Verzeichnissen oder Bildgenerierungsdiensten.

Die ersten vier Frames werden aus unveränderlichen Quelldateien gelesen, nicht aus vorherigen Ausgaben. Der Export kann deshalb wiederholt werden, ohne das Bild schrittweise zu verändern. Die Kopf-/Brustvorlage stammt aus Frame 01. Danach werden die spiegelbildlichen linken Frames exportiert.

## Prüfung und Grenzen

Die Sequenz wurde in der echten Hauptszene mit dem vorhandenen Player abgespielt und per Godot-Renderer aufgezeichnet: links, rechts, Idle/Walk, wiederholte Richtungswechsel sowie vorne/hinten. Ein animiertes GIF zeigt den Zyklus mit 125 ms je Frame; eine weitere Aufnahme zeigt die Bewegung im Spiel. Die technischen Prüfungen kontrollieren Bildgrössen, Alpha, Kopfstabilität, Spiegelung, Bodenkontakt, unterschiedliche Schrittweiten, Framefortschritt, Richtungswechsel und Kameraoffset.

Der Gegen-Schritt ist nun sichtbar, ohne dass der gesamte Körper auf- und abspringt. Die Animation bleibt bewusst grobe Pixel-Art; Beinüberlappungen und Armschwung sind stilisiert und können später noch von Hand verfeinert werden. Die Front-/Rückanimationen stammen weiterhin aus dem alten Sheet und sind dezenter. Die Spieltests verwenden automatisch eingespeiste Input-Ereignisse im vorhandenen Player.

## Kleine Gameplay-Ergänzung

Das Getränkeregal hat zu Schichtbeginn sichtbare Lücken. Die vorhandene E-Interaktion füllt die oberen beiden Reihen mit acht zusätzlichen Packungen. Der Hinweis wechselt zu „Regal ansehen“. Wiederholte Interaktion dupliziert keine Gegenstände; ein Neustart stellt die Lücken wieder her. Tastatur-Autowiederholungen schalten den Ton nicht mehr mehrfach um.
