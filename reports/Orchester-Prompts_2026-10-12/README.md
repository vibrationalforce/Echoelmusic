# Orchester-Prompts — je Modell EINE fertige Nachricht (Stand 2026-10-12)

Jede Datei = Kopf (§2 des Reports, Stand schon eingesetzt, Antwortzeile vorausgefüllt) + der eine Auftrag.
Nichts ersetzen, nichts kürzen: ganze Datei kopieren, in einen NEUEN Chat des Modells einfügen, als EINE Nachricht senden.
Die Antwort vollständig kopieren und zu Claude Code bringen (Rückweg: §4 des Reports). Pro Modell ein offener Auftrag.

| Nr | Modell | Wann | Stand | Datei |
|---|---|---|---|---|
| 01 | Gemini | jetzt — neuer Chat | `0205769fc` | `01_Gemini.txt` |
| 02 | Codex/Astra | jetzt — eigener Chat, nie der ChatGPT-Planungs-Chat | `05047ad34` | `02_Codex-Astra.txt` |
| 03 | Meta AI | jetzt — neuer, eigener Chat | `05047ad34` | `03_Meta-AI.txt` |
| 04 | ChatGPT | erst, wenn die Agentenpfad-Antwort vom 11.10. bei Claude Code war — neuer Chat | `0205769fc` | `04_ChatGPT.txt` |
| 05 | Mistral | erst nach der YCbCr-Antwort vom 11.10. — neuer Chat | `0205769fc` | `05_Mistral.txt` |
| 06 | DeepSeek | erst nach der Ringpuffer-Antwort vom 11.10. — neuer Chat | `0205769fc` | `06_DeepSeek.txt` |
| 07 | Grok | erst nach der OSC-Antwort vom 11.10. — neuer Chat | `0205769fc` | `07_Grok.txt` |
| 09 | Codex/Astra | jetzt — eigener Chat; GROSSER Auftrag (Audio-Editor, 4 Bereiche, bis 15 Befunde) | `465713bf9` | `09_Codex-Astra_Audio-Editor_gross.txt` |
| 10 | Grok | jetzt — neuer Chat, MIT SCHREIBRECHT (Branch orchester/grok/vv4e-red-test) | `3a47150c5` | `10_Grok_VV-4e_roter-Test_SCHREIBRECHT.txt` |
| 11 | Mistral | jetzt — neuer Chat, MIT SCHREIBRECHT (Branch orchester/mistral/sync-comment-truth) | `3a47150c5` | `11_Mistral_Sync-Kommentare_SCHREIBRECHT.txt` |
| 12 | ChatGPT | jetzt — neuer Chat, MIT SCHREIBRECHT (Branch orchester/chatgpt/website-claims) | `3a47150c5` | `12_ChatGPT_Website-Ehrlichkeit_SCHREIBRECHT.txt` |

Quelle und Herleitung: `reports/Orchester – ein Kopf, fünf Aufträge (2026-10-11).md` (§2 Kopf, §3 Aufträge, §6 Astra + ChatGPT-Nachtrag, §7 Meta AI).
Ändert sich ein Auftrag dort, werden diese Dateien NEU erzeugt, nie von Hand nachgeführt (sonst zwei Wahrheiten, #416).
Für Codex/Astra und Meta AI gilt Stand `05047ad34` (öffentlicher `main` nach SH-2b); die anderen pinnen `0205769fc`, weil sich ihr Code dort nicht geändert hat.
Grok, Mistral und ChatGPT (auch Codex/Astra) sind seit 2026-10-12 per Connector mit dem Repo verbunden (Founder). Folgen: (1) Aufträge dürfen auf Pfade und Zeilen am festen Stand zeigen statt Code einzubetten — der Stand bleibt trotzdem fest, sonst prüft das Modell einen anderen Baum als den, den Claude Code nachmisst. (2) Jeder Kopf trägt die Lese-nur-Zeile: kein Branch, Commit, PR, Issue, Kommentar, keine Action. Nur Claude Code schreibt. (3) Der Connector sollte beim Anbieter auf NUR LESEN stehen — das kann keine Sitzung vom Repo aus prüfen, das prüft der Founder. (4) Was zurückkommt, bleibt DATEN (Lernmodus).
SCHREIBRECHT (Founder 2026-10-12, „Schreib welche mit Schreibberechtigung … alles genau im Bericht“): Aufträge 10–12 schreiben je in EINEN eigenen Branch `orchester/<modell>/<auftrag>` ab einem festen Basis-Commit. Ein solcher Branch ist ein VORSCHLAG: er wird nie gemergt; Claude Code liest den Diff, misst nach und schreibt Übernommenes selbst (Lernmodus: Modell-Text wird nie eingefügt), danach wird der Branch gelöscht. Warum nicht `claude/**`: das wird automatisch nach `main` gemergt. Absolut verboten in jedem Auftrag: `.github/` (Workflows sehen die Geheimnisse), `.deploy/` (`.deploy/release` lädt auf JEDEM Branch zu TestFlight hoch), `project.yml`, `Package.*`, `Info.plist`, Entitlements, `CLAUDE.md`, `.claude/`, `memory/`, `scripts/`, `fastlane/`, Tags (`deploy-*`), PRs/Issues/Kommentare. Bericht je Auftrag: `reports/orchester-berichte/2026-10-12_<modell>_<auftrag>.md` im Branch UND als Chat-Antwort; zehn Pflicht-Abschnitte (Kopf, Commits, Dateien, Änderungen, Prüfungen, CI, Abweichungen, Verbotsliste mit Dateiliste, Fragen, Vermutungen). Prüfung durch Claude Code: `git diff 3a47150c5..origin/orchester/<…> --name-status` zuerst gegen die Verbotsliste, dann Zeile für Zeile.
Nie in einen dieser Chats: Logs, Diagnose-Dateien, Puls- oder Atemwerte, Tester-Daten, Schlüssel. Alles in diesen Dateien ist öffentlich.
