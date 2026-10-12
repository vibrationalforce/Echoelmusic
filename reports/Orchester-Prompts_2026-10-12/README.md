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

Quelle und Herleitung: `reports/Orchester – ein Kopf, fünf Aufträge (2026-10-11).md` (§2 Kopf, §3 Aufträge, §6 Astra + ChatGPT-Nachtrag, §7 Meta AI).
Ändert sich ein Auftrag dort, werden diese Dateien NEU erzeugt, nie von Hand nachgeführt (sonst zwei Wahrheiten, #416).
Für Codex/Astra und Meta AI gilt Stand `05047ad34` (öffentlicher `main` nach SH-2b); die anderen pinnen `0205769fc`, weil sich ihr Code dort nicht geändert hat.
Nie in einen dieser Chats: Logs, Diagnose-Dateien, Puls- oder Atemwerte, Tester-Daten, Schlüssel. Alles in diesen Dateien ist öffentlich.
