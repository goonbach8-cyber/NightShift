# NightShift – Schweizer Tankstellen-Shop

## Recherche und Ableitung

Verglichen wurden offizielle Schweizer Sortimentsangaben, Standortinformationen und Bildreferenzen aus mehreren Shops:

- [migrolino Sortiment](https://www.migrolino.ch/de/sortiment): Kaffee, Backwaren, Snacks, Getränke, Alltagsbedarf und – standortabhängig – Autozubehör. Daraus wurden klar zugeordnete kleine Warenbereiche abgeleitet.
- [migrolino Capolago](https://www.migrolino.ch/de/standorte/migrolino-capolago): Tankstelle mit Kaffeeangebot; die Bildreferenz zeigt Kleinwaren vor und Tabakwaren hinter der bedienten Kasse.
- [migrolino Bioggio](https://www.migrolino.ch/it/standorte/migrolino-bioggio): ergänzende Bildreferenz für zusammengehörige Kaffee- und Gebäckmöbel.
- [Coop Pronto Münchenstein / Regent Lighting](https://www.regent.ch/projekte/projekt-galerie/coop-pronto/): mehrere Bildreferenzen zu Verkaufsbeleuchtung, Kassenmöbeln und Produkten. Die Projektbeschreibung nennt ein flexibles LED-System für Waren und Bildflächen.
- [Migrolino Standortanforderungen](https://www.migrolino.ch/assets/content/files/Standortanforderung_migrolino-TS.pdf): Schiebetür, WC, technische Versorgung, Parkplatz und Anlieferung gehören zum umfassenderen realen Standortkonzept.

Das sind Referenzen, kein allgemeingültiger Grundriss. NightShift übernimmt funktionale Prinzipien für einen fiktiven kleinen Shop, keine Markenlogos, Fotografien oder verbindlichen Preisangaben. Die Ladenöffnungszeiten realer Referenzen werden nicht auf das fiktive Nachtspiel übertragen.

## Im bestehenden Projekt umgesetzt

- Bildschirm und Kassenschublade zur Bedienseite gedreht. Kartenleser und Kleinwaren bleiben auf der Kundenseite.
- Kompakter Tabak-/Serviceschrank hinter der Kasse mit etwa 1,12 m geometrischem Abstand zur Theke; tatsächlicher Weg mit Playerkollision getestet.
- Schichtzettel und Tisch vom Kundenbereich an einen rückwärtigen Arbeitsplatz rechts versetzt. Aufgabenhinweise angepasst.
- Schichtabschluss erfolgt ausdrücklich auf der Mitarbeiterseite. Auf der Kundenseite erklärt ein Hinweis den richtigen Bedienplatz.
- Geschützte Gebäckauslage neben der Kaffeemaschine, mit durchsichtigem Deckel für die angewinkelte Kamera; Becher-/Deckelstapel und Zubehör auf der vorhandenen Arbeitsplatte.
- Frei gewordenen Eingangsbereich mit kleinem Autopflegeregal sinnvoll genutzt.
- Vorhandene Metall-, Glas- und Gehäusematerialien konsistent wiederverwendet. Keine zusätzlichen Lichtquellen oder große Map-Erweiterung.

## Während der Prüfung korrigiert

- Der erste Tischstandort ragte in den Querweg. Der Tisch steht jetzt bei `(5.9, 0, -0.8)` und lässt den Zugang zum Bediengang frei.
- Ein undurchsichtiger Auslagendeckel verdeckte das Gebäck; er wurde durch einen gerahmten Glasdeckel ersetzt.
- Der Wandtest durfte wegen des neuen regulären Interaktionsziels nicht mehr pauschal `null` verlangen. Er prüft weiterhin ausdrücklich, dass das verdeckte Objekt hinter der Wand nicht auswählbar ist.

## Tatsächlich getestet

- Fünf Ansichten der echten Hauptszene mit unveränderter Spielkamera, einschließlich Mitarbeiterplatz; Godot 4.7.2, Compatibility/OpenGL.
- 51 erfolgreiche Gameplay-Prüfungen im gerenderten Spiel: Movement, Animation, Kollisionen, Wandabschirmung, Schichtbeginn am neuen Arbeitsplatz, Auffüllen, Abschluss nur auf der Bedienseite, Türdurchgang und Einklemmschutz, Neustart und Audio.
- 16 erfolgreiche Laufwegetappen im gerenderten Spiel, darunter Arbeitsplatz und Bediengang.
- 65 erfolgreiche separate Animationsprüfungen, headless.
- Finale Laufzeitlogs ohne Godot-Errors oder Warnings. Kein belastbarer FPS-Benchmark.

## Geänderte Projektdateien

- `scenes/levels/station_dressing.gd`
- `scenes/main/shift.gd`
- `tests/smoke_test.gd`
- `tests/environment_test.gd`
- `docs/SHOP_REFERENCES.md`

## Offen und nächste Priorität

Der Außenbereich bildet weiterhin nur einen kleinen begrenzten Vorplatz ab. WC, Lager und Anlieferung fehlen; dafür wurden keine falschen Türen oder Wegweiser vorgetäuscht. Die Eingangstür bleibt per Interaktion bedient, statt automatisch wie in der Standortreferenz. Gebäck, Tabak und Autopflege sind Ausstattung; ein Verkaufssystem ist noch nicht implementiert.

Als nächster Schritt ist ein kleiner funktionaler Nebenraum für Lager/Service sinnvoll, anschließend Außenbezug und Sound. Die bestehende Kundenzirkulation und der Mitarbeitergang sollten dabei erhalten bleiben.
