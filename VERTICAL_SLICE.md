# NightShift: funktionaler Vertical Slice

Stand: 14.09.2026. Der bestehende Shop, Pixel-Player, Lager, WC, Lieferhof und Sound bleiben erhalten. Kunden sind bewusst einfache Platzhalter. Kein Design-/Layout-Umbau.

## Spielen

WASD bewegt, E interagiert, M schaltet Ton um. Am Schichtzettel hinter der Kasse beginnen. Vier Kunden kommen automatisch, gehen zum Wasserregal und anschließend zur Kasse. Vom Mitarbeiterplatz hinter der Kasse mit E verkaufen. Der Startbestand von zwei Flaschen reicht absichtlich nicht für alle Kunden.

Im Lager am Nachfüllpunkt eine Kiste aufnehmen, zum Wasserregal bringen und mit E auffüllen. Den Getränkekühler einmal kontrollieren. Nach 18 Sekunden erscheint eine Lieferung im Hof hinter dem Lager: abholen und am Lager-Nachfüllpunkt einlagern. Es kann nur eine Ladung gleichzeitig getragen werden. Nach vier Verkäufen, vier abgereisten Kunden und den drei erledigten Aufgaben die Schicht an der Kasse abschließen. R startet anschließend eine neue Schicht. Zusammenfassung: Kunden, Umsatz, Aufgaben.

## Dateien und Verantwortlichkeiten

- `scripts/shop_stock.gd`: separate Resource je Schicht; Regalbestand, Reservierungen, Lagerbestand, Trageladung, Kapazität. Reservieren verhindert Überverkauf; erst Kassieren reduziert den Bestand.
- `scripts/night_shift_loop.gd`: Kundenfortschritt, FIFO-Kassenschlange, Verkäufe in ganzen Rappen, drei Aufgaben, zeitgesteuerte Lieferung und Abschlussbedingungen.
- `scripts/customer.gd`: Wegfolge, Warenwahl, Warten, Kasse, Ausgang; physische Kollisionen und erneute Wegsuche bei Blockierung.
- `scripts/shop_navigation.gd`: flaches AStar-Raster aus den tatsächlichen Boden-/Hinderniskollisionen; Türdurchgänge werden eingeplant und Türen beim Annähern geöffnet.
- `scripts/gameplay_layout.gd`: Adapter zur bestehenden Map, lokale Marker, Bestandsanzeige und Lieferpaket.
- `scenes/main/shift.gd`: Start/Ende, vorhandene Interaktionen, HUD, Feedback, Neustart.
- `scenes/levels/service_annex.gd`: nutzt dieselbe Bestands-Resource; bisherige Bestandsfelder bleiben als Aliase erhalten.
- `scenes/interactions/door.gd`: erkennt zusätzlich Kunden im Türbereich.

Produktdefinitionen in `data/products/` bleiben unveränderliche Resources mit ID, Namen, Kategorie und Rappenpreis. Die Demo verkauft zunächst nur Wasser; Kaffee und Snack sind bereits Daten, aber noch keine eigenen Kundenbestellungen.

## Späteres Layout ändern

Kernlogik verwendet Referenzen und globale Positionen der Marker statt fester Weltkoordinaten. `GameplayLayout` bindet Regal, Kasse, Lager und Eingang über NodePaths. Die bestehenden Objekte können lokale Marker `CustomerApproach`, `Operator`, `Queue0` bis `Queue2` sowie `CustomerSpawn` erhalten. Vorhandene Marker werden übernommen, ansonsten erzeugt der Adapter Standardpositionen relativ zum jeweiligen Objekt. Neue Map-Namen oder Lagerstrukturen benötigen Anpassungen in diesem Adapter, nicht im Verkaufsablauf.

Nach Änderungen an statischen Kollisionen die Navigation neu aufbauen; dies geschieht beim Schichtstart. Im laufenden Spiel bewegte Zielmarker lösen neue Wege aus, bewegte Hindernisse benötigen zusätzlich `navigation.rebuild(...)`. Marker müssen auf erreichbaren freien Bodenflächen liegen. Die Navigation ist für eine flache Ebene ausgelegt, nicht für Treppen oder mehrere Stockwerke. Bestehende statische Grafik-Batches müssen bei Editor-/Map-Umbauten ebenfalls neu erzeugt werden. Ganze Räume während einer laufenden Schicht dynamisch umzubauen ist kein unterstützter Spielmodus.

## Tests

Mit Godot 4.7.2 im Projekt ausführen:

```
godot --path . --script res://tests/vertical_slice_test.gd
godot --headless --path . --script res://tests/vertical_slice_test.gd -- --shift-layout
godot --headless --path . --script res://tests/stock_test.gd
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/service_test.gd
godot --headless --path . --script res://tests/environment_test.gd
godot --headless --path . --script res://tests/sidewalk_test.gd
godot --headless --path . --script res://tests/customer_door_test.gd
```

Der vollständige Test steuert den Player über Bewegungseingaben und E, lässt echte NPC-Physik und Navigation laufen, prüft leeren Bestand, Nachfüllen, zwei getrennte Queue-Plätze, Lieferung, vier Verkäufe, Abreise, Abschluss und Neustart. Er positioniert den Player nur anfangs am Schichtzettel. Türen werden während der automatisierten Wege über ihre Interaktion geöffnet; der separate Service-Test prüft die Türen mit E. Die alten Smoke-/Service-Tests verwenden gezielte Null-Kunden-Fixtures; Kunden und Verkauf werden im vollständigen Test geprüft.

## Bewusste Grenzen

Verifikation dieser Session: vollständiger grafischer Durchlauf sowie derselbe Durchlauf mit um `(20, 0, -15)` verschobener Szene jeweils 25 bestandene Prüfungen. Bestands-, Smoke-, Service-, Laufweg-, Animations- und Kunden-Türtests ebenfalls bestanden (insgesamt 232 Prüfungen in diesen acht abschließenden Testläufen). Keine Godot-Errors oder -Warnings in deren Logs. Die grafischen Screenshots wurden aus der normalen Player-Kamera geprüft. Die Eingaben wurden automatisiert; kein manueller Nutzertest und keine abschließende Hörbewertung.

Dabei korrigiert: Konflikt mit dem nativen Resource-Signal `changed`, gerundete Navigations-Endpunkte, zu geringe Hindernisreserve, blockierende Ausweichzellen unmittelbar um den Akteur und die fehlende Kunden-Kollisionsmaske des Türsensors. Bestands-/Kassenprüfungen decken Überverkauf, doppelte Eingaben, leere/vollständige Bestände und Neustart ab.

Vier Kunden, ein verkäuflicher Produkttyp, einfache Platzhalterfiguren, kurze fortschrittsbasierte Schicht. Kein Speicherstand, Kunden-Warenkorb, Bezahlen-Minispiel oder Wirtschaftsmodell. Die Kühlkontrolle ist eine einfache Interaktion. Sound ist die bestehende synthetisierte Grundlage. Der nächste funktionale Ausbau ist eine zweite Produktkategorie mit eigenem Regalbestand und variierenden Bestellungen; danach unabhängige Playtests auf längere Blockaden und Verständlichkeit.
