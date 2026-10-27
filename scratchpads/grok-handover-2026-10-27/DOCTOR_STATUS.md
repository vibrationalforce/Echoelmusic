# Doctor — tatsächlich ausgeführte Prüfung vom 27.10.2026

Basis: `31ce86372ed852626f186f91d2984996bb958b89`.
Befehl: `python3 scripts/doctor.py`. **Exit 1, drei kritische Befundgruppen**.
Unveränderter Basis-Output in [VALIDATION.json](VALIDATION.json).

| Gruppe | Meldung | Einordnung |
|---|---|---|
| A / Gates | maskierte Buildfehler / fehlender pipefail-Schutz in mehreren Workflows | Einzelbefunde prüfen. Studio-Engine-iOS-Schritt enthält bereits `set -eo pipefail`; diese Teilmeldung ist ein Fehlalarm |
| A / Testfilter | `ComprehensiveTestSuite` in `ci.yml:290–291` ohne gefundene XCTestCase-Klasse | Statische Prüfung; Xcode-Verhalten bei null Treffern bezeichnet der Doctor selbst als unbestätigte Annahme |
| E / Spacing | 712 literale Abstände, Grenze 696, also +16 | Bestehender Legacy-Scannerbefund; Sources hier unverändert. Kein hier ausgeführter XCTest-Beleg |

Keine automatische Reparatur durch Grenzerhöhung, Guard-Löschung oder CI-Änderung.
Abschnitt B meldete schon auf der Basis Erfolg, obwohl G-A-Ressourcen fehlten:
ein grüner Abschnitt beweist nicht alle relativen Links. Die Ressourcen zusätzlich
direkt im Git-Baum/Dateisystem geprüft.

Reachability bleibt namensbasiert. Die Closure-Suche ist kein Beweis gegen jedes
Datenrennen. Der Doctor kompiliert/rendert nichts und misst weder Klang, Latenz,
Audioaussetzer noch VoiceOver-/Sensorverhalten.

Vor Integration erneut laufen lassen und mit der Basis vergleichen. Altbefunde
benennen, neue Fehler nicht darin verstecken. Die Referenzprüfung hat einen eigenen
Exitcode und ersetzt weder Doctor noch Studio-Gates oder Geräteabnahme.
