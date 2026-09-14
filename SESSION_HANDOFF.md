# Exakter Fortsetzungspunkt — 14.09.2026

Nicht Produkt-, Queue-, Save-, Event- oder Dialogsystem erneut bauen. Aktueller Überblick: `VERTICAL_SLICE.md`.

## Erreicht

Default Night 1 (6 Kunden) und Night 2 (8 Kunden) wurden vollständig grafisch durchgespielt, einschließlich dreier Produkte, mehrteiliger Warenkörbe, Scans/Zahlungen, Nachfüllen, gemischter Lieferung, Serviceauftrag, Dialogantwort, Main Events, Radio und Speichern/Nachtübergang. Ergebnis: 14 Kunden, 24 Artikel, CHF 66.10; Night 3 als Folgevorlage geladen. 431 Prüfungen in den ausgewerteten erfolgreichen Läufen, keine Engine-Warnings/-Errors darin.

## Nächster sinnvoller Schritt

1. Manuellen Night-1-Bedienungstest durchführen, besonders Tastaturfokus, Scannen, Antworten und TAB-Nachfüllwahl. `tests/manual_interaction_test.gd` ist eine vorbereitete Ein-Kunden-Testszene am Kassenplatz (Schichtstart und Position sind Fixture, danach keine automatischen Gameplay-Eingaben). Der Windows-Computer-Use-Helper konnte das Fenster zeigen/fokussieren, aber E/F bewirkten keine registrierte Aktion. Nicht als erfolgreichen manuellen Test darstellen. Bei Bedarf zunächst einen InputEventKey-Audit ergänzen, um Helper-/Fokusproblem von Spielinput zu unterscheiden. Keine aktuelle bekannte Godot-Fehlermeldung dazu.
2. Danach Inhalte/Balancing der Folgenacht-Vorlage in `scripts/night_catalog.gd` und Testdialoge in `scripts/dialogue_catalog.gd` verfeinern. Ressourcen-Schnittstellen sind vorhanden. Keine endgültige Story-Erklärung festlegen.
3. Optional Radio-Musikordner und Streamer Mode ergänzen; derzeit absichtlich nur zwei eigene synthetisierte Tracks. Kein Design-Pass.

## Letzte behobene Probleme

- Resource-Signal-Lambda hielt Bestands-Resources zyklisch fest: benannte Methode verwendet.
- Kunden konnten beim gegenseitigen Ausweichen einen weiterhin blockierten ersten Wegschritt bekommen: dynamische Sperrzellen korrigiert.
- Queue-Leader lief zum alten Rastermittelpunkt zurück und gegen den folgenden Kunden: ersten nahen Startpunkt überspringen.
- Navigationsprobe prüft auch niedrige Sockel auf Fußhöhe.
- Save-Validierung akzeptiert StringName-Flags vor der JSON-Serialisierung; beschädigte JSON-Dateien werden ohne Engine-Fehler geparst und auf Backup zurückgeführt.
- Scans und Reservierungen werden bei unerwartetem NPC-Abgang zurückgesetzt; Radio-Unterbrechungen überschreiben keinen Mute-/Lautstärkewunsch.

## Nachweise im Arbeitsverzeichnis

`C:/Users/e558926/Documents/Codex/2026-09-10/du-arbeitest-direkt-an-meinem-lokalen/outputs/`

Erfolgreiche Logs: `nights-campaign-final.log`, `nights-moved-layout.log`, `nights-queue-final.log`, `nights-save-final.log`, `nights-save-write.log`, `nights-save-read.log`, `nights-lifecycle.log`, `nights-narrative_test.log`, `nights-checkout_test.log` und die acht `nights-regression-*.log`.

Screenshots: `Slice-night1-complete.png`, `Slice-night2-complete.png`, `Slice-night1-dialogue-and-queue.png`, `Slice-night2-dialogue-and-queue.png`. `nights-native-input.log` dokumentiert den nicht bestandenen nativen Eingabeversuch.

Frühere Logs ohne `final` können behobene Fehler enthalten. Nicht erneut als offene Fehler zählen, ohne den erfolgreichen Nachtest zu berücksichtigen. Der letzte gezielte Checkout-Test umfasst außerdem den ausgelagerten Dialogkatalog und die alternative Antwort.

Testprozesse sind beendet. Keine Commits, Pushes oder Git-Resets durch den Agenten. Änderungen direkt im bestehenden Projekt; bestehende zwischenzeitliche Benutzer-Commits nicht zurücksetzen.
