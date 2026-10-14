# Secrets hacksicher + Vibecoding-Masterclass — Recherche und Messung (2026-10-14)

Founder-Auftrag: „Secrets hacksicher machen durch fake secrets und api keys. Deep research zu dem
Thema masterclass vibecoding."

## 1. Gemessen im Repo (heute)

| Befund | Messung |
|---|---|
| Die App selbst trägt **keinen** API-Schlüssel | `Package.swift` `dependencies: []`; Stream-Key liegt in der Keychain (`Stream/StreamKeyStore.swift`) |
| Lokaler GitHub-Token ist ignoriert | `git check-ignore -v .claude/settings.local.json` → `.gitignore:132` |
| `detect-secrets` existiert lokal | `.secrets.baseline` + `.pre-commit-config.yaml`; **in keinem Workflow** |
| **Höchstes Risiko:** `testflight.yml` hält den App-Store-Connect-Privatschlüssel (20 `secrets.`-Stellen) und lädt `maxim-lobanov/setup-xcode@v1` **per Tag** | `grep -n maxim-lobanov .github/workflows/testflight.yml` → Z. 139, 310 |
| Keine Action ist per Commit-SHA gepinnt; 9 von 14 Workflows ohne `permissions:` | `grep -hoE "uses: [^ ]+" .github/workflows/*.yml` · `grep -c "^permissions:"` |

## 2. Köder-Schlüssel (Honeytokens) — was sie können, was nicht

- Ein Köder ist ein Schlüssel, den kein echter Prozess je benutzt — wird er benutzt, ist das ein
  starker Einbruchs-Hinweis. Er **erkennt** Missbrauch, er **verhindert** ihn nicht.
- Kostenlos: Thinkst Canarytokens (kein Konto, Alarm per Mail). Grenze: ihre Token haben bekannte
  Fingerabdrücke, ein geübter Angreifer kann sie erkennen.
- **Ins öffentliche Repo gehört kein Köder**: Bots scannen GitHub in Minuten, der Alarm sagt dann nur
  „jemand hat das Repo gelesen" — das ist bei einem öffentlichen Repo immer wahr.
- **Sinnvoller Ort:** dort, wo echte Geheimnisse liegen — als GitHub-Secret im TestFlight-Job und in
  `~/.aws/credentials` auf dem Mac. Ein kompromittierter Action-Schritt, der den Runner-Speicher
  ausliest (tj-actions, März 2025), nimmt den Köder mit; benutzt er ihn, kommt die Mail.
- Umsetzung: `docs/dev/FOUNDER_INBOX.md` §3 **F16** (das Anlegen braucht deine Mail-Adresse beim
  Anbieter — das macht keine Sitzung für dich).

## 3. Was mehr schützt als jeder Köder (Reihenfolge)

1. **Actions per Commit-SHA pinnen** — Tags können umgebogen werden (tj-actions). Steht seit dem
   Audit 2026-10-08 in der Inbox §3.
2. **`permissions: contents: read`** in jedem Workflow ohne Block.
3. **GitHub Secret Scanning + Push Protection** einschalten (Repo-Einstellung, kostenlos für
   öffentliche Repos).
4. Den App-Store-Connect-Schlüssel nur im Upload-Schritt lesen, nicht im ganzen Job.
5. Nach jedem Verdacht: Schlüssel **rotieren** — laut GitGuardian 2026 waren 64 % der 2022
   gefundenen echten Schlüssel im Januar 2026 noch nicht zurückgezogen.

## 4. Vibecoding-Masterclass — was die Forschung 2025/26 sagt

- **Geheimnis-Lecks:** GitGuardian 2026 zählt ~28,65 Mio. neue hart codierte Secrets in öffentlichen
  GitHub-Commits 2025 (+34 %); KI-gestützte Commits leaken mit 3,2 % gegenüber 1,5 % Grundrate.
- **Unsicherer Code:** Veracode 2025: 45 % der Aufgaben mit kritischen Fehlern; Escape.tech fand in
  5 600 vibe-gecodeten Apps >2 000 Schwachstellen und 400 offene Secrets; Georgia Tech zählt
  steigende CVEs aus KI-Code (Lovable/Supabase ohne Row-Level-Security, CVE-2025-48757).
  (Mehrere Zahlen stammen aus Sekundärquellen — vor dem Zitieren die Primärquelle prüfen.)
- **Der Profi-Ablauf, in dem sich die Leitfäden einig sind:** erst planen · eine Aufgabe pro Prompt,
  ein Thema pro Diff · keine Verhaltensänderung ohne Test · den **Diff** lesen, nicht den Chat
  (unerwartete Dateien, gelöschte Prüfungen, erweiterte Rechte, Secrets, gelöschte statt
  reparierte Tests) · Agenten nur dort lange laufen lassen, wo Erfolg objektiv prüfbar ist, und von
  Bezahlung, Login, Migrationen und Löschungen fernhalten · geringste Rechte, Sandbox, Freigaben.
- **Abgleich mit Echoelmusic:** das Repo macht das meiste davon schon (Scheiben ≤ 3 Dateien,
  Wächter pro Scheibe, zwei CI-Gates, founder-gated Workflows, Lernmodus für fremde Modelle,
  Unter-Agenten nur lesend). **Die Lücke ist die Lieferkette der Workflows** (Abschnitt 1 und 3) —
  genau dort liegt das einzige echte Geheimnis des Projekts.

## Quellen

- Honeytokens: https://zeltser.com/plant-honeytokens · https://blog.gitguardian.com/gitguardian-honeytoken/ · https://www.decryptiondigest.com/blog/how-to-deploy-canary-tokens-honeytokens-breach-detection
- Vibecoding-Risiken: https://labs.cloudsecurityalliance.org/research/csa-research-note-ai-generated-code-security-vibe-coding-202/ · https://news.research.gatech.edu/2026/04/13/bad-vibes-ai-generated-code-vulnerable-researchers-warn · https://www.securityweek.com/vibe-coded-apps-riddled-with-exploitable-security-flaws/ · https://www.ibm.com/think/insights/vibe-coding-security-risks
- Vibecoding-Ablauf: https://developer.vonage.com/en/blog/beyond-vibe-coding-best-practices-2026 · https://roadmap.sh/vibe-coding/best-practices · https://www.developersdigest.tech/blog/vibe-coding-guide · https://www.kunalganglani.com/blog/vibe-coding-best-practices-2026
- tj-actions: https://semgrep.dev/blog/2025/popular-GitHub-action-tj-actionschanged-files-is-compromised · https://www.wiz.io/it-it/blog/github-action-tj-actions-changed-files-supply-chain-attack-cve-2025-30066 · https://cycode.com/blog/github-action-tj-actions-changed-files-supply-chain-attack-the-complete-guide/
