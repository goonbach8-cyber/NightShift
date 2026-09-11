# NightShift – Umgebung, 11.09.2026

Die bestehende Hauptszene wurde direkt im lokalen Projekt aufgewertet. Raumgröße, Player, Kamera und vorhandene Interaktionspunkte bleiben erhalten.

## Änderungen

- Zwei niedrige Wareninseln strukturieren die bisher leere Ladenfläche. Zentraler Eingang und seitliche Zugänge bleiben frei.
- Fliesenboden mit schmalen Fugen, leichten Farbvariationen und dunkler Randzone; Wandsockel und durchgehendes grünes Wandband.
- Kühler mit Flaschen, Fachböden, Rahmen und Lichtleisten; Regalabschluss und Produktetiketten.
- Kassentheke mit Arbeitsplatte, Frontleisten, Terminalanzeige und Kartengerät; kleiner Kaffeebereich und detaillierter Mitarbeitertisch.
- Eingangsmatte, Türrahmen und Beschriftung am beweglichen Türflügel; Abfallbehälter und gerahmtes Kaffeeangebot.
- Zapfsäule mit Sockel, Anzeige, Schlauch und Schutzpfosten; Stellplatzmarkierung und dekorativer dunkler Boden außerhalb der unveränderten Spielfeldgrenze.
- Reduziertes Mond- und Umgebungslicht, warme Verkaufsbeleuchtung, kühlere Kühlerbeleuchtung und zwei zusätzliche lokale Schattenquellen. Sichtbare Leuchten, ohne eine spielbehindernde geschlossene Decke.
- Geteilte Materialien und einfache Geometrie, keine zusätzlichen Rasterassets oder schweren Renderverfahren.

## Projektdateien

- `scenes/levels/station.gd`: bindet die Ausstattungsschicht ein (3 zusätzliche Zeilen).
- `scenes/levels/station_dressing.gd`: neue, getrennte Ausstattungsschicht einschließlich neuer Möbelkollisionen.
- `scenes/levels/shop_floor.gdshader`: prozedurales Fliesenmaterial.
- `scenes/main/main.tscn`: Mond- und Umgebungslicht angepasst.
- `tests/environment_test.gd`: zwölf echte Bewegungsetappen durch die Ladenwege.
- Godot erzeugt zu neuen Ressourcen zusätzlich UID-Dateien.

`extract.gd`, Player-Code, Kamera und vorhandene Interaktionsskripte wurden nicht geändert. Bereits vorhandene unversionierte UID-Dateien wurden erhalten. Kein Commit oder Push.

## Tatsächlich getestet

- Hauptszene im Godot-4.7.2-Compatibility-Renderer auf Intel Iris Xe gestartet; vier Ansichten vor und nach der Änderung aufgenommen und visuell geprüft.
- Bestehender Gameplay-Test: 50 erfolgreiche Prüfungen, sowohl headless als auch mit aktivem Renderer. Enthält Movement, Idle/Walk, Richtungswechsel, Wandkollision, Schichtaufgaben, Auffüllen, Türdurchgang, Einklemmschutz, Soundsteuerung und Neustart.
- Animationsprüfung: 65 erfolgreiche Prüfungen, headless.
- Neuer Laufwegetest: 12 erfolgreiche Etappen mit Bewegungseingaben im gerenderten Spiel, einschließlich Wegen zu Kühler, Regal, Kasse und Mitarbeitertisch.
- Finale Spiel- und Testlogs enthalten keine Godot-Errors oder Warnings.

## Einordnung und nächster Schritt

Materialtrennung, eingerichtete Verkaufsbereiche und Lichtinseln ersetzen den bisherigen Eindruck einer leeren Blockout-Fläche. Der Player ist in den geprüften Spielansichten weiterhin klar sichtbar.

Die Umgebung bleibt bewusst einfach und stilisiert. Einige Möbel sind noch kantig; Scheiben besitzen keine echte Transparenz, die Lampen verwenden die offene Schnittdarstellung des Raums. Kein belastbarer FPS-Benchmark oder Test auf anderer Hardware durchgeführt.

Als nächster Schritt empfiehlt sich gezieltes Polishing der vorhandenen Möbel und räumlicher Sound (Kühler, Leuchten, Tür und Außenatmosphäre), bevor zusätzliche Map-Bereiche entstehen.
