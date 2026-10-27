# Grok-Gegenprüfung — 27.10.2026

Messbasis `31ce86372ed852626f186f91d2984996bb958b89`, vollständiger Git-Baum und
isolierter Checkout. Prüfung der Übergabe und ihrer direkten Integrationspunkte;
kein neues Audit des gesamten Swift-Repositories. Produktionsdateien unverändert.

## Was Grok tatsächlich abgelegt hat

`git show --stat 31ce8637`: **drei neue Dateien, 70 hinzugefügte Zeilen**:
`.claude/skills/g-a-body-modulation/SKILL.md`, ursprüngliche `README.md` und
`DOCTOR_STATUS.md` dieses Ordners. Parent war `3f240b3d`.
Das ist Orientierung und Status, keine Implementierung der angekündigten
Contracts/Fixtures/Reference-Skripte. Der vollständige Baum enthielt keine
G-A-Ressourcen und keine analogen G-B/C/D-Skills. Die Branch-Namenssuche nach „grok“
lieferte `orchester/grok/vv4e-red-test`; unveröffentlichte Arbeit/Chats anderer
Modelle sind nicht einsehbar. Das Audit behauptet keine vollständige Branch-Inventur.

## Befunde und Behandlung

| ID | Beleg am gemessenen SHA | Konsequenz / Behandlung |
|---|---|---|
| H1, SICHER | G-A `SKILL.md:10–14` nennt drei fehlende Dateien; ursprüngliches README:41 behauptet ausführbare Skripte | Alle drei Ressourcen ergänzt; Python-Ergebnis von Swift getrennt |
| H2, SICHER | Ursprüngliches README:38 nennt analoge B/C/D-Skills; Baum enthält nur G-A | Falschen Lieferstatus korrigiert; B/C/D als offene Aufträge verlinkt |
| H3, SICHER | `BodyFrameSource.swift:9–12`, Adapter:19–28, View:12–17 | Feste plausible Werte, aktiv als Default; View liest eigene Konstanten. Vertrag fordert fehlende Werte, Gültigkeit und Generationen |
| H4, SICHER | Namenssuche findet BodyFrameSource/Adapter/View nur in ihren drei Dateien inkl. Preview; StudioView ohne Körper-Tür | Kommentar „View liest Source“ ist keine Verdrahtung; A2 braucht echten Besitzer und erreichbare Anzeige |
| H5, SICHER | `Project.swift:8`, `docs/FORMAT.md:1`; ModRoute kein Projektfeld | Format 2 bleibt Ist-Stand. v3 ist Vorschlag; keine automatisch aktiven Routen |
| H6, SICHER | `W2_MODROUTE_CONCRETE_SKETCH_2026-10-26.md:28–30`: Control-Tick/ParameterWriter; Plan 25.10. nennt Renderpfad | Dokumentbefehle von laufender Modulation trennen. Writer-Vorschlag nicht ungeprüft implementieren |
| H7, SICHER | `StudioView.swift:55,444–445`, `App/Agent/AgentSession.swift`, `Core/.../AgentTools.swift` | „W7/W9/W10 geplant“ zu grob: W10 besitzt Assistenten und Tools; vorhandene Besitzer weiterverwenden |
| H8, SICHER | `EchoelStudio/project.yml:77,83,95`, `Support/App/EchoelStudio.entitlements` | Mikrofon/LocalNetwork und App Groups vorhanden; Kamera/Bluetooth/Health-Deklarationen hier nicht vorhanden. Änderungen getrennt vorbereiten |
| H9, SICHER | Eigener Doctor-Lauf, Exit 1; Studio-Workflow enthält `set -eo pipefail` | Doctor ausgeführt und rot; Studio-Pipefail-Teilmeldung ist nachgelesener Fehlalarm |
| H10, SICHER | `PluginStateCapture.swift` fehlt auf main; #430 offen, `PluginHost.swift:596–600` alter Capture-Pfad | Body-first-Liste überspringt G4/G3/G2/AU-Arbeit; ältere konkrete Übergabe zuerst abgleichen |

H3/H4: unter `EchoelStudio/App/Models/` bzw. `App/Views/`; H5:
`EchoelStudio/Core/Sources/EchoelCore/`. Zeilen gelten nur am obigen SHA.
Reproduktion: `rg -n 'BodyFrameSource|BodyFramePublisherAdapter|BodyFrameView' EchoelStudio`.
Rohmessungen und Hashes: [VALIDATION.json](VALIDATION.json).

## Gegenprüfung der neuen Referenz

Ein unabhängiger, rein lesender Prüfer untersuchte die Ressourcen als Integrator.
Zwei konkrete Fehler wurden vor Veröffentlichung korrigiert:

1. Späte Permission-Antwort der alten Quelle konnte die neue Quelle sperren.
   Jetzt prüft auch `permission` Quelle/Generation; S22 verhindert den Rückfall.
2. Ungültige alternative JSON-Fixtures konnten einen Traceback statt Exit 2 erzeugen.
   Root-/Formprüfung, endliche JSON-Zahlen und Grenzen ergänzt; separate CLI-
   Negativläufe belegen das dokumentierte Fehlerverhalten.

Der erste Vektorlauf fand außerdem geteilte veränderliche Eingabedaten im temporären
Fixture-Erzeuger: die obere Clamp-Prüfung erhielt die negative Tiefe des nächsten
Falls. Sollwert unverändert gelassen, Eingaben getrennt. Die abgelegte JSON-Datei
enthält eigenständige literale Eingaben und begründete Sollwerte.

## Council und Umfang

Council- und Skill-Creator-Hinweise angewandt: vorhandene Repo-Ressourcen ergänzen,
Verhalten prüfen, unabhängige Gegenprüfung, Git-Veröffentlichung. Keine Installation
oder Änderung eines persönlichen ChatGPT-Skills.

- Architektur: vorhandene Studio-Besitzer, ParameterAddress und Befehlstür.
- Echtzeit: Python ist mathematische Referenz, keine Render-Implementierung.
- Vision: W0–W10 erhalten, Produktionsworkflow und optionales Bio korrekt einordnen.
- Stärkster Einwand: Referenz-PASS könnte als Produkt-PASS gelesen werden; deshalb
  getrennte Evidenz und NOT_RUN für echte Integration/Gerät.
- Entscheidung: mit dieser Begrenzung fortfahren. Kein neuer Scope-/Releaseentscheid;
  Produktgesetze, CI, Projekt, Entitlements und Store-Daten unverändert.

## Noch nicht erledigt

G4b/G3/G2/AU, Swift-Port, Produktions-Source-Registry, Format-3-Codec, echte Sensoren,
Permissions, kohärente Renderübergabe, Audio-Export, Geräte-A11y und G-B/C/D bleiben
Implementierungs-/Abnahmearbeit. 64 Routen, 2 s Alter, Qualität 0.7 und 10 ms Rampe
sind ausdrücklich Entwurfspolicies, keine Benchmarks. Die begrenzte Workflow-Abfrage
beweist keinen nie erfolgten Upload.
