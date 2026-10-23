# 009 — Hinweis „frühere App“ auf jeder Website-Seite, die sie noch beschreibt

## Goal

Wer auf echoelmusic.com eine Anleitung (Reaper, Resolume, TouchDesigner, Art-Net/sACN), die
Integrations-Seite, „What Echoel Does“ oder Support liest, erfährt im ersten Absatz, dass TestFlight
seit dem 19.10.2026 Echoel Studio trägt, was Studio davon noch NICHT kann und dass die Seite die
eingefrorene frühere App beschreibt — bevor er einer Anleitung folgt, die in der installierbaren App
nichts tut.

## Assumptions

- A1 — Auftrag aus dem Masterplan („Texte nach außen: auf der Website ein Hinweis auf jeder Seite,
  die noch die eingefrorene Alt-App beschreibt“) und `docs/roadmap.html` selbst („Most other pages of
  this site still describe that earlier app“). Keine neue Behauptung über Studio außer zwei
  gemessenen Abwesenheiten.
- A2 — Gemessen am 2026-10-23: `git grep -il 'osc\b\|OSCSender\|Art-Net\|sACN' --
  EchoelStudio/App EchoelStudio/Core/Sources EchoelStudio/Engine/Sources` liefert nichts — Studio
  sendet weder OSC noch Art-Net noch sACN; ebenso liest Studio keinen Körper (kein HealthKit, keine
  Kamera, kein BLE in `EchoelStudio/`). Die Rückkehr-Reihenfolge steht in `docs/roadmap.html`
  (Winter 2027–28 Bühnen-Ausgänge, 2028 Körper als Modulationsquelle).
- A3 — Wortlaut übernommen aus den Seiten, die den Hinweis schon tragen (`brainstorming.html`,
  `press.html`, `index.html`): „Since 19 October 2026, TestFlight carries Echoel Studio, a new music
  workstation for iPhone and iPad“ und „the earlier app (10.79.515), which is frozen“. „iPhone and
  iPad“ ist gemessen: `TARGETED_DEVICE_FAMILY: "1,2"` in `EchoelStudio/project.yml`.
- A4 — Sieben Seiten, gefunden als die App-Seiten ohne „Echoel Studio“ (`grep -c -i "echoel studio"
  docs/*.html`), deren Inhalt die frühere App beschreibt: `integrations`, `reaper-osc`,
  `resolume-osc`, `touchdesigner-osc`, `artnet-sacn-from-a-phone`, `tools`, `support`. NICHT
  angefasst: `health`, `privacy`, `terms`, `impressum`, `security` (Recht und Gesundheit sind
  sensible Dateien, `privacy` trägt den Hinweis schon), `artist` (Künstlerseite, keine App),
  `one-clock` (läuft im Browser, keine App-Behauptung), `404`, `og-image`.
- A5 — Ein Absatz direkt unter der Überschrift, ohne neues CSS: auf den fünf Anleitungs-Seiten ein
  `<p>` unter dem `<h1>`, auf `tools` und `support` ein `<p class="subtitle">` im Kopf, wie auf
  `brainstorming.html`. Keine Überschrift, also keine Änderung der Überschriften-Ordnung.

## Acceptance criteria

1. Jede der sieben Seiten trägt genau einen Absatz mit „Since 19 October 2026, TestFlight carries
   Echoel Studio“, vor ihrem ersten `<h2>`. Prüfung: `for f in …; do grep -c "Since 19 October 2026,
   TestFlight carries Echoel Studio" docs/$f.html; done` → je 1, und die Zeilennummer liegt vor der
   des ersten `<h2>`.
2. Die fünf OSC/DMX-Seiten sagen „It does not send OSC, Art-Net or sACN yet“; `tools` und `support`
   sagen „It does not read the body yet“ — beides gemessen (A2). Prüfung: `grep -c` je Seite.
3. Jeder Absatz verlinkt `roadmap.html` und nennt die frühere App mit „10.79.515“ und „frozen“.
   Prüfung: `grep -c 'href="roadmap.html">Roadmap' ` und `grep -c "10.79.515), which is frozen"` je Seite.
4. Keine andere Zeile der sieben Seiten ändert sich, keine andere Datei unter `docs/`. Prüfung:
   `git diff --stat <base>..<head> -- docs/` = sieben Dateien, je `1 +`.
5. Kein Wächter unter `Tests/CISmoke`, der diese Seiten liest, wird rot. Prüfung:
   `python3 -I scripts/foreign-needles.py`, `dead-needles.py`, `moved-needles.py` enden mit 0 auf dem
   Kopf; kein Lauf (`docs/**` und `scratchpads/**` sind in keinem Gate-Pfadfilter).

## Out of scope

- Die Inhalte der Seiten umschreiben oder für Studio neu fassen: eigene Scheiben, sobald Studio die
  Ausgänge hat.
- `sitemap.xml`-Daten, Meta-Beschreibungen, Open-Graph-Text.
- Rechts-, Datenschutz- und Gesundheitsseiten.
