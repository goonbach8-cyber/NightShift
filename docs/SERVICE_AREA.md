# NightShift – Lager, Service und Nachfüllablauf

## Gebaut

Ein etwa 5 × 10 m großer Anbau rechts vom bestehenden Shop enthält Lager, Reinigungsecke und ein kleines Mitarbeiter-WC. Ein Durchgang in der bisherigen Ostwand verbindet ihn mit dem Shop, ohne die Wand am bisherigen Kollisions-Testpunkt zu entfernen.

- Lager: Metallregale, Kartons mit Etiketten/Klebeband, Getränkekisten, Nachfüllpunkt, Reinigungsschrank, Eimer und Wischgerät.
- WC: eigene bedienbare Schiebetür, Toilette mit Sitzöffnung und Spülkasten, Waschplatz mit Armatur, Spiegelfläche, Seifen- und Papierdetails, separate Beleuchtung.
- Anlieferung: bedienbare Hintertür zum kleinen begrenzten Lieferhof, Palette, Karton und Container. Der Hof ist begehbar, aber noch keine Fahrzeugzufahrt oder Liefer-Simulation.
- Vorplatz: Tragstruktur und Lichtleisten einer Überdachung in offener Schnittdarstellung für die Kamera, zusätzliche Beleuchtung an der Zapfsäule, Preisschild und dekorativer Straßenstreifen außerhalb der vorhandenen Spielgrenze.

## Spielbarer Ablauf

1. Schichtzettel am bestehenden Arbeitsplatz hinter der Kasse mit E lesen.
2. Durch die Lagertür an der rechten Shopwand gehen (bei z = -2.2).
3. Im Lager vorne links am markierten Nachfüllpunkt E drücken: eine Kiste mit acht Flaschen wird aufgenommen.
4. Zurück zum Getränkeregal gehen und E drücken. Ohne Kiste wird die Aufgabe nicht abgeschlossen.
5. Kühlung prüfen und die Kontrollrunde am Bedienplatz hinter der Kasse abschließen.

Der Vorrat beginnt mit 24 Flaschen. Eine Kiste reserviert acht Flaschen; eine zweite kann nicht gleichzeitig aufgenommen werden. Nach dem Auffüllen stehen acht Flaschen im Shopbestand, der getragene Bestand ist wieder null. Nach erfüllter Regalaufgabe werden keine weiteren Kisten entnommen. Neustart setzt alle Werte zurück. Der getragene Zustand steht im Aufgabenhinweis; ein sichtbares Tragemodell ist noch nicht vorhanden.

## Warenverkaufsgrundlage

`ShopProduct` ist eine kleine Godot-Resource mit stabiler Produkt-ID, Name, Kategorie und Preis in ganzzahligen Schweizer Rappen. Drei `.tres`-Definitionen enthalten Mineralwasser, Kaffee und Nussriegel. Die Mengenberechnung verwendet Integer; negative Mengen ergeben keinen negativen Preis. Bestände gehören zur laufenden Szene und werden nicht in gemeinsam geladenen Produktdefinitionen verändert.

Noch kein Kassieren, Kunden-NPC, Warenkorb oder Zahlungsverkehr. Nur Wasser ist bislang mit dem Nachfüllablauf verbunden. Preise sind fiktive Spielwerte.

## Sound

Original synthetisierte Platzhalter: räumliches Gerätebrummen am Kühler und im Lager, gedämpftes Windrauschen im Lieferhof, kurze Bewegungsgeräusche an der vorhandenen Eingangstür und den drei neuen Türen. Ein Listener folgt dem Player. M schaltet auch die neuen Quellen stumm und stellt ihre jeweiligen Pegel wieder her. Streams werden beim Szenenwechsel freigegeben.

Die Wiedergabe wird im Spiel gestartet; Stummschaltung und Wiederherstellung wurden technisch geprüft. Keine abschließende Hörabnahme mit aufgenommenen Geräuschen. Schritte, Verkehr und Kaffeemaschinenabläufe fehlen weiterhin.

## Performance und Sichtprüfung

Die erste Erweiterung erzeugte rund 2.000 Zeichenaufrufe in den neuen Ansichten bei etwa 25–26 FPS auf der vorhandenen Intel Iris Xe. 732 unbewegliche Meshes werden jetzt nach Material und kleinen räumlichen Zellen in 247 Meshes zusammengefasst. Türen, transparente Flächen und nachfüllbare Ware bleiben separat.

Ein dabei gefundener Fehler beim Mischen indexierter und nicht indexierter Geometrie wurde korrigiert. Danach wurden die Ansichten erneut kontrolliert: Kasse und Zapfsäulengehäuse vollständig, Player erkennbar, WC-Beschriftung verkleinert, Toilette aus Kamerarichtung lesbar.

Die späteren Stichproben lagen nach der Startphase bei etwa 45–53 FPS und 482–823 Zeichenaufrufen. Das ist kein systematischer Benchmark; die Geometrieaufbereitung kostet zusätzliche Startzeit.

## Ausgeführt

- Godot-Editorimport und mehrere Starts der echten Hauptszene, Compatibility/OpenGL.
- Fünf gerenderte Ansichten: Lager, WC, Lieferhof, Vorplatz und ursprünglicher Shop.
- 54 erfolgreiche Gameplay-Prüfungen einschließlich vollständigem Schichtablauf, ursprünglicher Tür, Bewegung, Kollisionsschutz und Bestandsreset.
- 31 erfolgreiche Service-Prüfungen: tatsächliche Wege durch die neuen Räume, E-Türbedienung, Türschutz bei belegtem Durchgang, einmalige Warenentnahme, Rückweg, Auffüllen, Produktpreise und räumliche Stummschaltung. Gerendert ausgeführt; nach der letzten reinen Geometriekorrektur nochmals headless bestätigt.
- 16 erfolgreiche ursprüngliche Shop-Laufwegetappen und 65 Animationsprüfungen, abschließend headless.
- Finale Laufzeitlogs ohne Godot-Errors oder Warnings.

## Projektdateien

- `scenes/levels/station.gd`: bindet Anbau und Geometriezusammenfassung ein.
- `scenes/levels/service_annex.gd`: Räume, Ausstattung, Außenbereich, kleine Bestandslogik und räumliche Sounds.
- `scenes/main/shift.gd`: verbindet Kistenentnahme und Auffüllen mit dem Schichtablauf.
- `scripts/shop_product.gd`, `data/products/{water,coffee,snack}.tres`: Produktgrundlage.
- `scripts/static_prop_batch.gd`: räumlich begrenzte Zusammenfassung statischer Oberflächen.
- `tests/service_test.gd`, `tests/smoke_test.gd`: neue Tests und angepasster bisheriger Ablauf.
- `docs/SERVICE_AREA.md`: dieser Stand.

## Nächster Schritt

Ein einzelner Kunde mit einer festen Bestellung und einer einfachen bestätigten Verkaufstransaktion würde den vorhandenen Waren- und Kassenablauf am stärksten zu einem Vertical Slice ergänzen. Danach sind hörbar bessere Soundassets, Lieferhof-Anbindung und gezieltes visuelles Polishing sinnvoll. Die Nebenräume bleiben bewusst einfach; Spiegel ist keine Echtzeitreflexion, Sanitärmöbel haben noch keine Benutzungsanimationen.
