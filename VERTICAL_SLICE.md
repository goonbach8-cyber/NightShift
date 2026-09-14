# NightShift — aktueller spielbarer Stand

Stand 14.09.2026. Funktionalität vor Design. Bestehende Map, Pixel-Player, Kamera, Lager, WC und Lieferhof bleiben erhalten. Dies sind kurze System-Prototypen, nicht die fertigen 5–7 Story-Nächte oder fünf Stunden Spielinhalt.

## Spielen

1. Am Schichtzettel hinter der Kasse mit **E** starten.
2. Kunden besuchen Wasserregal, Energy-Kühler und Snack-Insel entsprechend ihrem Warenkorb. Vom Mitarbeiterplatz an der Kasse **E** pro Artikel zum Scannen, danach **E** zur Zahlung. Erst die Zahlung verändert Bestand und Umsatz.
3. **TAB** wählt Nachfüllware. Im Lager am Nachfüllpunkt **E** zum Aufnehmen, dann am passenden Regal **E** zum Auffüllen. Nur eine Ladung gleichzeitig. Die Bestandsanzeigen markieren knappe oder vollständig reservierte Produkte mit `!`.
4. Kühlung mit **E** kontrollieren. Gemischte Lieferung erscheint nach 18 Sekunden im Lieferhof; aufnehmen und am Lager-Nachfüllpunkt abgeben. Ab Night 2 zusätzlich den Abfalleimer links neben dem Eingang kontrollieren/leeren.
5. **F** eröffnet ein kurzes Gespräch mit dem vordersten wartenden Kunden. **Space** blättert weiter; **1/2** wählen angebotene Antworten. Während des Gesprächs wird nicht versehentlich kassiert und die Geduld dieses Kunden pausiert.
6. Nach Kunden und Aufgaben Schichtende an der Kasse bestätigen. **N** speichert und wechselt zur nächsten Nacht. **F5** speichert nur den Abschluss. **R** startet eine frische Demo; anschließend lädt **F9** den letzten Abschluss, bevor die nächste Schicht gestartet wird.

**WASD:** Bewegung. **T:** Radio an/aus. **Y:** nächster Track. **+/-:** Radiolautstärke. **M:** global stumm. Die Radiotracks sind zwei eigene synthetisierte Platzhalter. Custom Music Folder und ein eigener Streamer-Schalter sind noch nicht enthalten.

## Funktionsumfang

- Drei Produkte mit separaten Lager-, Regal-, Reservierungs- und Verkaufsbeständen. Reservierungen gehören einem konkreten Kunden. Warenkörbe werden vollständig abgerechnet oder bei Abbruch freigegeben.
- Unterschiedliche Warenkörbe, Mengen, Geschwindigkeit und Geduld. Maximal vier aktive Kunden/Queue-Plätze; weitere Kunden erscheinen, wenn wieder Platz frei ist. Unbediente Kunden können gehen, ohne Reservierungen zu hinterlassen.
- Night 1: sechs Kunden, drei Aufgaben. Folgenacht-Vorlage: acht Kunden, kürzerer Spawnabstand und zusätzlicher Serviceauftrag. Night 3 und weitere Indizes nutzen derzeit dieselbe Folgenacht-Vorlage, keine ausgearbeiteten Story-Nächte.
- Main Events passieren unter ihren konfigurierten Bedingungen garantiert einmal; variable Events würfeln einmal bei erfüllten Bedingungen. Erlebte Events und Entscheidungsflags werden zwischen Nächten erhalten.
- Mystery-Prototypen: widersprüchlicher Wartungshinweis/Kundendialog, kurzer langsamer Lichtabfall mit Wiederherstellung, kurze Radio-Unterbrechung. Die Texte sind austauschbare Testinhalte, keine endgültige Erklärung der Geschichte.

## Daten und Komponenten

| Datei | Verantwortung |
|---|---|
| `scripts/shop_product.gd`, `data/products/*.tres` | Name, Kategorie, Rappenpreis, Kapazität und Startmengen |
| `scripts/shop_stock.gd`, `scripts/shop_inventory.gd` | Bestände, kundenbezogene Reservierungen, atomare Warenkörbe, eindeutige Lieferungen |
| `scripts/customer.gd`, `scripts/shop_navigation.gd` | NPC-Bewegung, physische Kollisionen, Ausweichwege auf flacher Ebene |
| `scripts/gameplay_layout.gd` | Map-Referenzen, lokale Marker, Produkt-/Servicepunkte und Light-Gruppe |
| `scripts/night_shift_loop.gd` | Koordination von Einkauf, Queue, Scannen/Zahlung, Aufgaben und Abschluss |
| `scripts/night_definition.gd`, `scripts/night_catalog.gd` | Konfigurierbare Nächte: Kunden, Spawnrate, Bestellungen, Lieferung, Aufgaben und Events |
| `scripts/night_event.gd`, `scripts/event_director.gd` | Eventdaten, Bedingungen, Wahrscheinlichkeit, Historie und Trigger-Signal |
| `scripts/event_effects.gd` | Temporäre Beleuchtungswirkung über Gruppe `night_event_light` |
| `scripts/dialogue_catalog.gd`, `scripts/dialogue_session.gd` | Getrennte Testtexte/Antworten und Dialogzustand mit Entscheidungsflags |
| `scripts/shop_radio.gd` | Unabhängiger Radiozustand, Tracks, Lautstärke, Unterbrechung und Mute |
| `scripts/shift_save.gd` | Validierter zwischen-Schichten-Checkpoint mit Sicherungskopie |
| `scenes/main/shift.gd` | Eingaben, HUD, Komponentenverbindung und Nachtübergang |

Das Layout darf später verändert werden. Kernsysteme verwenden Objekt-Referenzen und Marker. Die konkrete aktuelle Zuordnung liegt im Layout-Adapter. Nach Änderungen an statischen Hindernissen Navigation neu aufbauen (beim Schichtstart automatisch). Die Navigation berücksichtigt auch niedrige Sockel; NPCs laufen beim Nachrücken nicht zum Mittelpunkt ihrer bisherigen Rasterzelle zurück. Keine Treppen-/Mehrstockwerk-Navigation.

## Save/Load

Datei: `user://nightshift_checkpoint.json`, unter Windows im Godot-Benutzerdatenordner des Projekts. `.bak` enthält die vorherige gültige Version. Die neue Datei wird zunächst als `.tmp` vollständig geschrieben und anschließend ersetzt. Ungültige Primärdaten fallen auf die Sicherung zurück; sind beide ungültig, bleiben aktuelle Daten unverändert.

Gespeichert werden abgeschlossene Nächte, Gesamtumsatz, Lager- und Regalbestände, Entscheidungen und Eventhistorie. Ein noch getragener Restbestand wird am Nachtübergang ins Lager zurückgeführt. Aktive Kunden, Reservierungen und laufende Dialoge werden nicht gespeichert. Wiederholtes Speichern derselben Schicht verdoppelt die Statistik nicht. Laden ist vor dem Schichtstart möglich. Produktdefinitionen bleiben Projekt-Resources; künftige Änderungen des Produktschemas benötigen gegebenenfalls eine Save-Migration.

## Verifikation

Godot 4.7.2, Compatibility/OpenGL. **431 bestandene Prüfungen** in 17 ausgewerteten erfolgreichen Läufen; deren Logs enthalten keine Godot-Errors oder -Warnings. Frühere Fehlerlogs bleiben im Arbeitsverzeichnis als Diagnosehistorie erhalten.

- Grafischer vollständiger Zwei-Nächte-Test: 14 Kunden, 24 Artikel, CHF 66.10. Tatsächliche Laufwege, E-Scans/Zahlungen, TAB-Auswahl, Nachfüllen, Lieferung, Serviceauftrag, F/Space/Antworten, Radio, Main Events und N-Übergänge. Danach Night 3 vorbereitet, beide Historien und Entscheidung erhalten.
- Verschobene Map: vollständiger Mehrprodukt-Loop inklusive Reservierungen, Nachfüllen und Zahlung.
- Vier gleichzeitige Queue-Plätze, acht aufeinanderfolgende Kunden, keine verbleibenden NPCs oder Reservierungen.
- Save → echter Prozessabschluss → frischer Prozess → Load; fehlende/beschädigte Datei, Backup, Wiederholung und Lade-/Speichersperre während aktiver Schicht.
- Event-/Dialog-/Radio-Systemtests sowie alle bestehenden Player-, Animations-, Tür-, Service-, Laufweg- und Bestandsregressionen.

Die langen Durchläufe liefen grafisch mit automatisierten Godot-Eingaben und Sichtprüfung der Spielkamera. Der zusätzliche Windows-Nativeingabeversuch konnte keinen erfolgreichen Tastendruck im Spiel nachweisen; er zählt **nicht** als bestandener manueller Playtest. Ein unabhängiger manueller Test bleibt erforderlich.

Wichtige Aufrufe (Godot-Executable entsprechend ersetzen):

```
godot --path . --script res://tests/campaign_test.gd
godot --headless --path . --script res://tests/multi_product_test.gd -- --shift-layout
godot --headless --path . --script res://tests/queue_stress_test.gd
godot --headless --path . --script res://tests/save_test.gd
godot --headless --path . --script res://tests/save_process_test.gd -- --write
godot --headless --path . --script res://tests/save_process_test.gd
godot --headless --path . --script res://tests/narrative_test.gd
godot --headless --path . --script res://tests/checkout_test.gd
```

Die alten Einprodukt-/Queue-Fixtures verwenden ausdrücklich `quick_checkout = true`, um ihre ursprünglichen Prüfungen zu behalten. Standardspiel und Campaign-Test verwenden das mehrstufige Kassieren.

## Noch offen

Unabhängiger manueller Bedienungs-/Verständlichkeitstest; endgültige englische Texte (momentan gemischte Prototyp-UI); echte Night-2/3-Inhalte und Balancing; finales Audio statt Synthese-Platzhaltern; optionaler Musikordner/Streamer Mode. Die fertigen 5–7 Nächte, Storydauer, finale Grafik und finales Layout sind nicht umgesetzt. Sie sollen auf diesen Systemen aufbauen.
