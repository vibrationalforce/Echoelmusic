# DSGVO-Architektur — ENTWURF (2026-10-04)

> ⛔ **KEIN RECHTSDOKUMENT. KEIN VERTRAGSTEXT.** Das hier ist ein technischer Entwurf, den eine KI geschrieben hat. Datenschutzerklärung, AGB, AVV, VVT, TOMs und DSFA entstehen daraus **erst nach Prüfung und Freigabe durch einen Juristen oder Datenschutzbeauftragten**. Diese Prüfung ist nicht optional; die Vorlage selbst schreibt sie vor (COMPLIANCE_ARCHITECTURE_V3.8, LAYER_05: „DISALLOW: Raw_AI_Generated_Legal_Contracts · FORCE: Human_In_The_Loop_Legal_Audit“). Offene Rechtsfragen stehen am Ende und gehören über `docs/dev/FOUNDER_INBOX.md` an Jurist oder DSB.
>
> **Anlass:** Der Founder hat am 2026-10-04 die Prompt-Vorlage „COMPLIANCE_ARCHITECTURE_V3.8“ eingereicht. Erbeten waren ein Entwicklungsplan, ein Export-Schema (JSON/CSV) und eine AVV-Checkliste für eine DSGVO-konforme KI-SaaS. Abschnitt 1 ordnet zuerst ein, was davon **Echoelmusic heute** betrifft. Die Abschnitte 2–5 sind der generische SaaS-Entwurf, für den Fall, dass je ein Backend dazukommt.

## 0. Stand nach dem 2026-10-04 — zwei neue Datenwege, noch nicht ausgeliefert

Abschnitt 1 beschreibt den Stand vor zwei Änderungen. Beide liegen im Arbeitsbaum, sind **noch nicht ausgeliefert** und warten auf Founder-gesperrte Dateien. Mit ihrer Auslieferung muss Abschnitt 1 nachgezogen werden:

- **B2 Broadcast (RTMP/RTMPS über HaishinKit 2.2.5):**
  - **Was gesendet wird:** Master-Mix und Visual.
  - **Wohin:** an einen Server, den der **Nutzer** einträgt.
  - **Wann:** erst, wenn er „Go Live“ drückt.
  - **Was nicht gesendet wird:** Kamera, Mikrofon und Roh-Biosignale.
  - **Zugangsdaten:** Der Stream-Key liegt im Keychain. Die Bibliotheks-Logs sind stummgeschaltet, weil sie den Key mitschreiben könnten.
  - **DSGVO-Bezug:** Der Plattformbetreiber (z. B. YouTube oder Twitch) ist eigener Verantwortlicher gegenüber dem Nutzer; Echoel betreibt keinen Server. Ob die Musik indirekt Gesundheitsdaten offenbart (bio-reaktive Klangänderung), ist eine Frage an den DSB.
- **E10-1 Mikrofon-Aufnahme in eine Audiospur:**
  - Nur nach ausdrücklicher Erlaubnis.
  - Gespeichert wird nur auf dem Gerät, in `Media/Audio`.
  - Keine Übertragung.
  - Eine Aufnahme kann Stimmen Dritter enthalten. Das gehört in die Datenschutzerklärung, sobald die Funktion ausgeliefert wird.

**Repo-Befund am Rand:** `CLAUDE.md` (REPO STRUCTURE) führt `WeatherProvider` als „REMOVED 2026-06-19“. Die Datei `Sources/Echoelmusic/Core/WeatherProvider.swift` existiert aber und ruft `WeatherService`. Gemeldet, nicht geändert.

---

## 1. Was davon Echoelmusic heute betrifft

**Echoelmusic ist keine SaaS, sondern eine iOS-App, die alles auf dem Gerät verarbeitet.** Das habe ich im Repo nachgesehen:

- `docs/privacy.html` sagt: keine Konten, kein Tracking, keine Cloud-Speicherung von Bio-Daten, keine Server. `docs/security.html` sagt dasselbe: „we do not operate external servers or cloud backends for user data“.
- Netzwerk-Ausgang gibt es im Code nur in vier Fällen. Alle schaltet der Nutzer selbst ein, und alle gehen an ein Ziel, das er selbst wählt:
  - **UDP-Ausgänge:** `NWConnection` steht in `Sync/OSCSender.swift`, `ADMOSCSender.swift`, `ArtNetSender.swift` und `SACNSender.swift`. Diese Verbindungen sind nach dem jeweiligen Standard unverschlüsselt.
  - **Nearby-Sharing:** `MCSession(... encryptionPreference: .required)` in `Sync/MultipeerSession.swift`.
  - **Apple-Dienste:** WeatherKit (`Core/WeatherProvider.swift`, optional und standardmäßig aus) und HealthKit lesen und schreiben.
  - `URLSession` kommt in `Sources/` nicht vor.
- **CloudKit:** `Sync/AnnouncementCenter.swift` ist hart abgeschaltet (`cloudKitConfigured = false`). `Core/CloudSync.swift` ist nur eine Phase-0-Abstraktion ohne CloudKit-Adapter.
- **KI zur Laufzeit:** `EchoelAI/FoundationModelsBrain.swift` und `Sequencer/BioMusicDirector.swift` nutzen Apples On-Device-Modell (`FoundationModels`). Für `FoundationModelsBrain(` und `BioMusicDirector` habe ich keine Produktions-Aufrufer außerhalb der eigenen Dateien gefunden. Der Code existiert, wird aber nicht erreicht. Laut Dateikopf bekommt das Modell nur grobe Adjektive („low/medium/high“), keine Rohwerte.
- **Bio-Daten sind Gesundheitsdaten** (Art. 4 Nr. 15 DSGVO) und damit eine besondere Kategorie nach Art. 9 DSGVO. Herzfrequenz ist in der Regel *nicht* „biometrisch“ im Sinne von Art. 4 Nr. 14, weil sie nicht zur eindeutigen Identifizierung dient. Diese Einordnung sollte trotzdem der DSB bestätigen.
- **Offene Rechtsfrage für den DSB:** Ist der Entwickler überhaupt Verantwortlicher, wenn die Daten sein Gerät nie erreichen und nur auf dem Gerät des Nutzers verarbeitet werden? Die Nutzung selbst fällt eventuell unter die Haushaltsausnahme (Art. 2 Abs. 2 lit. c). Das ist nicht trivial. Ich gebe hier keine Antwort darauf.

| Ebene | Gilt für Echoelmusic heute? | Gilt erst bei einem Cloud-Dienst |
|---|---|---|
| **L00 Daten-Taxonomie** | Teilweise. Eine Taxonomie lohnt sich auch auf dem Gerät: Bio-Snapshot, „Performer-Signatur“ in den App-Preferences, Mikrofon-Aufnahmen in `Media/Audio`, Standort-Stadtwort. ID, IP, E-Mail und Chat-Logs fallen in der App nicht an. | Alle Klassen inkl. Verschlüsselung und Audit-Log serverseitig |
| **L01 Entwickler-Werkzeuge** | Nur indirekt. Kunden-Daten liegen nicht im Repo. Personenbezug entsteht aber bei TestFlight-Tester-Feedback und Crash-Logs, Support-Mails (`echoel@tropicaldrones.com`) und Geräte-Logs, die in KI-Werkzeuge eingefügt werden. Für diese Fälle gilt die L01-Regel: Business-, Team- oder Enterprise-Tarif mit DPA und Trainings-Opt-out, oder keine echten Nutzerdaten einfügen. | Voll |
| **L02 Cloud-Stack** | Für die App nein. **Für die Website und die Kommunikation ja**: GitHub Pages (`docs/CNAME` = echoelmusic.com) sieht Besucher-IPs, und der E-Mail-Provider ist ein Auftragsverarbeiter. **Befund:** `docs/screenshots/demo-audio.html`, `demo-coherence.html` und `demo-visual.html` laden Google Fonts direkt von `fonts.googleapis.com`. Damit geht die IP-Adresse ohne Einwilligung an Google (vgl. LG München I, 3 O 17493/20, 20.01.2022). Ich melde das nur und habe nichts geändert. | Voll: Supabase, Cloudflare, AWS, DPF- und SCC-Prüfung, Subprozessor-Kette | ⭐ **Erledigt 2026-10-08:** die drei Demo-Seiten unter `docs/screenshots/` sind gelöscht — kein Google-Fonts-Abruf mehr auf der ganzen Site (Audit).
| **L03 KI zur Laufzeit** | Heute nicht aktiv, da kein Aufrufer. Bei Aktivierung prüfen: (a) KI-Transparenz nach Art. 50 KI-VO (VO (EU) 2024/1689); (b) ob ein aus Puls abgeleitetes „arousal“ ein „Emotionserkennungssystem“ (Art. 3 Nr. 39 KI-VO) ist, mit Hinweispflicht nach Art. 50 Abs. 3. Das ist eine Rechtsfrage; ich bin mir bei der Einordnung unsicher. (c) Training ist on-device kein Thema; Apples Bedingungen für FoundationModels sollte man trotzdem prüfen. | Voll, inkl. Art.-9-Filter für Freitext und Vendor-Training aus |
| **L04 Art. 15 / Art. 17** | Es gibt keine Serverdaten. Die Erfüllung läuft über die App: Löschen ist vorhanden („Default sound“ löscht die Performer-Signatur), App löschen entfernt alles. Ein lokaler Export (JSON) der App-eigenen Daten wäre gute Praxis, ist aber kein Muss ohne Server. | Self-Service-Export und -Löschung, Fristen nach Art. 12 Abs. 3 |
| **L05 Dokumente** | Datenschutzerklärung, `terms.html` und `impressum.html` existieren. Ein **VVT (Art. 30), eine TOM-Dokumentation und eine DSFA (Art. 35)** habe ich per `git grep` nicht gefunden. Ob für die App eine DSFA nötig ist, entscheidet der DSB. Art.-9-Daten in großem Umfang sind ein Regelbeispiel nach Art. 35 Abs. 3 lit. b. | Zusätzlich AVV mit Kunden (wenn B2B) und AVVs mit allen Dienstleistern |

**Fazit:** Heute greifen L00 (gerätelokal), L02 (nur Website und E-Mail) und L05 (VVT/TOM/DSFA fehlen). L01, L03 und L04 würden voll greifen, sobald ein Backend, Konten, Cloud-Sync oder ein Cloud-LLM dazukommen. Der aktuelle Datenschutz-Vorteil besteht darin, dass keine Daten erhoben werden. Jedes Backend hebt diesen Vorteil auf und zieht den ganzen Rest dieses Dokuments nach sich.

---

## 2. Generische Architektur einer DSGVO-konformen KI-SaaS

```
                        ┌───────────────────────────────────────────────┐
  Nutzer (Browser/App)  │  Edge: CDN/WAF (z.B. Cloudflare, EU-Zone)     │
  ── TLS 1.2+/1.3 ─────►│  - TLS-Terminierung, Rate-Limit, Bot-Schutz   │
                        │  - IP nur gekürzt/kurz geloggt (L00: IP)      │
                        └───────────────┬───────────────────────────────┘
                                        │ mTLS / privates Netz
                        ┌───────────────▼───────────────────────────────┐
                        │  API-Gateway / Backend (EU-Region)            │
                        │  - AuthN/Z (OIDC), RBAC, Row-Level-Security   │
                        │  - Consent-Check vor jeder Zweck-Verarbeitung │
                        │  - Audit-Middleware ──────────────┐           │
                        └──┬──────────────┬─────────────┬───┼───────────┘
                           │              │             │   │
          ┌────────────────▼──┐  ┌────────▼─────────┐   │   ▼
          │ PII-Gateway (L03) │  │ Primär-DB (EU)   │   │ ┌───────────────────────┐
          │ - Art.-9-Erkennung│  │ Postgres         │   │ │ Audit-/Processing-Log │
          │ - Redact/Pseudon. │  │ - Feldverschl.   │   │ │ append-only, WORM,    │
          │ - Hinweis an User │  │   E-Mail/Chat    │   │ │ pseudonymisiert,      │
          └───────┬───────────┘  │   (Envelope-Enc) │   │ │ Hash-Kette            │
                  │              │ - At-Rest AES-256│   │ └───────────────────────┘
                  ▼              └────────┬─────────┘   │
          ┌───────────────────┐           │             │
          │ LLM-Adapter       │  ┌────────▼─────────┐   │ ┌───────────────────────┐
          │ - Zero-Retention/ │  │ KMS/HSM (EU)     │◄──┴─┤ DSR-Worker (L04)      │
          │   Training AUS    │  │ - Schlüssel je   │     │ - Export JSON/CSV     │
          │ - Option: lokal   │  │   Mandant        │     │ - Löschung + Backups  │
          │   (Qwen/Llama auf │  │ - Crypto-Shred.  │     │ - signierte Download- │
          │   EU-Hoster)      │  └──────────────────┘     │   URL, Ablauf 7 Tage  │
          └───────────────────┘                           └───────────────────────┘
          Objektspeicher (EU, verschlüsselt): Exporte, Anhänge; Lifecycle-Regeln
          Backups: verschlüsselt, Aufbewahrung begrenzt (Art. 5 Abs. 1 lit. e)
```

**Wo Verschlüsselung und Audit sitzen**
- *In Transit:* TLS am Edge. Intern mTLS oder ein privates Netz (Art. 32 Abs. 1 lit. a).
- *At Rest:* Datenträger-Verschlüsselung (Standard). Zusätzlich **Feldverschlüsselung** für E-Mail, Chat-Logs und Verhaltensmetriken mit Schlüsseln je Mandant oder Nutzer im KMS. Das erlaubt **Crypto-Shredding** bei Löschung, auch in Backups, wenn diese die Schlüssel nicht enthalten.
- *Audit:* nur anhängend (append-only), mit pseudonymisierter Nutzer-Referenz und manipulationssicher (Hash-Kette oder WORM-Bucket). Inhalt wird nicht protokolliert, nur Metadaten (wer, was, Zweck, Rechtsgrundlage).
- *Privacy by Design/Default (Art. 25):* Opt-ins standardmäßig aus, kürzeste Aufbewahrung als Default, Analytics nur mit Einwilligung (zusätzlich § 25 TDDDG für Endgerätezugriff).
- *Subprozessor-Tiefe 1 (Ziel aus L02):* jeder Dienstleister bindet keine weiteren, oder die Kette ist vollständig bekannt und gelistet (Art. 28 Abs. 2 und 4).

**Datenflüsse je L00-Klasse**

| Klasse | Erhebung | Speicher | Verschlüsselung | Aufbewahrung (Vorschlag, juristisch festlegen) |
|---|---|---|---|---|
| ID | Registrierung | `users` | Feld (E-Mail), Lookup über HMAC | Konto-Laufzeit + kurze Karenz |
| IP | Edge/Backend | Logs | gekürzt oder gehasht | 7–30 Tage |
| EMAIL | Registrierung | `users.email_enc` | Envelope-Enc. | Konto-Laufzeit |
| CHAT_LOGS | KI-Funktion | `chat_messages` | Envelope-Enc. je Nutzer | nutzerkonfigurierbar, Default kurz |
| METRIC_BEHAVIOR | Telemetrie (nur mit Einwilligung) | aggregiert | pseudonymisiert | aggregieren, Rohdaten kurz |

---

## 3. Entwicklungsplan in Phasen, jeweils mit Exit-Kriterium

1. **Scoping und Dateninventar.** Zwecke, Datenkategorien, Betroffene, Rechtsgrundlagen (Art. 6, bei Gesundheitsdaten Art. 9 Abs. 2 lit. a: *ausdrückliche* Einwilligung).
   *Exit:* `data_inventory` befüllt, VVT-Entwurf (Art. 30) liegt vor, DSFA-Schwellwertprüfung (Art. 35) ist dokumentiert.
2. **Verträge vor Echtdaten.** AVVs mit allen Dienstleistern (siehe Abschnitt 5), Drittlandprüfung (DPF/SCC/TIA), Subprozessor-Liste.
   *Exit:* keine Echtdaten bei einem Dienstleister ohne unterschriebenen AVV. Das wird per Checkliste nachgewiesen.
3. **Fundament.** EU-Region, KMS, Feldverschlüsselung, RLS, Audit-Log, Backup-Konzept, Rollen und Zugriffe nach Least Privilege.
   *Exit:* Test belegt, dass Klartext-PII in DB-Dumps und Logs fehlt. Die Schlüsselrotation ist geübt.
4. **Einwilligung und Transparenz.** Consent-Service mit Versionierung, Widerruf so einfach wie Erteilung (Art. 7 Abs. 3), Informationen nach Art. 13.
   *Exit:* jede zweckgebundene Verarbeitung prüft den Consent-Status maschinell, und es gibt Tests dafür.
5. **KI-Laufzeit (L03).** Hinweis auf KI-Interaktion (Art. 50 Abs. 1 KI-VO; nach meinem Stand anwendbar ab 02.08.2026, Art. 113; mögliche spätere Änderungen bitte prüfen). PII- und Art.-9-Erkennung vor dem LLM-Aufruf (redigieren oder Nutzer informieren), Vendor-Training vertraglich und technisch aus, Zero-Retention wo verfügbar.
   *Exit:* Red-Team-Testsatz mit Gesundheits- und Ausweisdaten wird zu 100 % erkannt oder geloggt-und-gemeldet. Die Vertragsklausel zum Training liegt vor.
6. **Betroffenenrechte (L04).** Self-Service für Export (Art. 15, zusätzlich maschinenlesbar nach Art. 20), Berichtigung (Art. 16), Löschung (Art. 17) inkl. Backups und Dienstleister (Art. 19), Einschränkung (Art. 18), Widerspruch (Art. 21).
   *Exit:* Ende-zu-Ende-Test zeigt: Export vollständig gegen `data_inventory`, Löschung nach Lauf in keiner Quelle mehr auffindbar, Frist von einem Monat überwacht (Art. 12 Abs. 3).
7. **Sicherheitsnachweis.** TOM-Dokument (Art. 32), Pentest, Datenpannen-Runbook mit 72-h-Meldung (Art. 33) und Benachrichtigung der Betroffenen (Art. 34).
   *Exit:* Pentest-Befunde „hoch“ behoben, Tabletop-Übung der Datenpanne durchgeführt.
8. **Rechtliche Abnahme (L05).** Datenschutzerklärung, AGB, Kunden-AVV, VVT, TOMs und DSFA werden von Jurist oder DSB geprüft. KI-generierte Vertragstexte gelten nur als Entwurf. DSB benennen, falls Art. 37 oder § 38 BDSG greift.
   *Exit:* schriftliche Freigabe von Jurist oder DSB, datiert.
9. **Betrieb.** Löschjobs nach Fristen, Monitoring der Subprozessoren (Änderungsmitteilungen), jährlicher Review von VVT, TOMs und DSFA, Prüfung des DPF-Status.
   *Exit:* Kalender-Routinen mit Verantwortlichen stehen. Der erste Review-Zyklus ist abgeschlossen.

---

## 4. Export-Schema

### 4.1 SQL (PostgreSQL)

```sql
-- Pseudonymisierung: externe Referenz = zufällige UUID; E-Mail nur verschlüsselt + HMAC-Lookup.
CREATE TABLE users (
  user_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subject_ref      UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(), -- Pseudonym für Logs
  email_enc        BYTEA NOT NULL,           -- Envelope-verschlüsselt (KMS-Key je Nutzer/Mandant)
  email_hmac       BYTEA UNIQUE NOT NULL,    -- HMAC-SHA256(email, server_secret) für Login-Lookup
  display_name_enc BYTEA,
  key_id           TEXT NOT NULL,            -- KMS-Schlüssel; Löschung = Crypto-Shredding
  locale           TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_active_at   TIMESTAMPTZ,
  status           TEXT NOT NULL CHECK (status IN ('active','restricted','pending_erasure','erased'))
);

CREATE TABLE consents (
  consent_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES users(user_id),
  purpose        TEXT NOT NULL,          -- z.B. 'ai_chat', 'analytics', 'health_data_art9'
  legal_basis    TEXT NOT NULL,          -- 'art6_1_a','art6_1_b','art9_2_a', ...
  text_version   TEXT NOT NULL,          -- Version des Einwilligungstexts (Nachweis Art. 7 Abs. 1)
  granted_at     TIMESTAMPTZ NOT NULL,
  withdrawn_at   TIMESTAMPTZ,
  channel        TEXT NOT NULL,          -- 'web','ios','api'
  evidence_hash  BYTEA                   -- Hash von UI-Zustand/Request, kein Klartext
);

CREATE TABLE processing_log (            -- append-only (REVOKE UPDATE, DELETE)
  log_id         BIGSERIAL PRIMARY KEY,
  subject_ref    UUID NOT NULL,           -- Pseudonym, nicht user_id
  actor          TEXT NOT NULL,           -- 'system','support:<pseudonym>','vendor:<name>'
  action         TEXT NOT NULL,           -- 'read','create','update','export','erase','llm_call'
  data_category  TEXT NOT NULL,           -- L00: 'ID','IP','EMAIL','CHAT_LOGS','METRIC_BEHAVIOR'
  purpose        TEXT NOT NULL,
  legal_basis    TEXT NOT NULL,
  recipient      TEXT,                    -- Empfänger/Subprozessor (für Art. 15 Abs. 1 lit. c)
  third_country  TEXT,                    -- ISO-3166 bei Drittlandübermittlung
  occurred_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  prev_hash      BYTEA,                   -- Hash-Kette gegen Manipulation
  row_hash       BYTEA NOT NULL
);

CREATE TABLE export_requests (
  request_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES users(user_id),
  kind           TEXT NOT NULL CHECK (kind IN ('art15_access','art20_portability')),
  format         TEXT NOT NULL CHECK (format IN ('json','csv','both')),
  received_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  identity_verified_at TIMESTAMPTZ,
  due_at         TIMESTAMPTZ NOT NULL,    -- received_at + 1 Monat (Art. 12 Abs. 3)
  extended_until TIMESTAMPTZ,             -- max. +2 Monate, mit Begründung an Betroffenen
  completed_at   TIMESTAMPTZ,
  package_uri    TEXT,                    -- signierte URL, kurzlebig
  package_sha256 BYTEA,
  expires_at     TIMESTAMPTZ,             -- Paket nach z.B. 7 Tagen löschen
  status         TEXT NOT NULL CHECK (status IN ('received','verifying','building','ready','delivered','expired','rejected'))
);

CREATE TABLE erasure_requests (
  request_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subject_hmac   BYTEA NOT NULL,          -- bleibt nach Löschung als Nachweis; kein Klartext
  received_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  due_at         TIMESTAMPTZ NOT NULL,
  scope          TEXT NOT NULL,           -- 'full','category:<x>'
  exemptions     JSONB,                   -- Art. 17 Abs. 3 (z.B. gesetzl. Aufbewahrung), mit Fundstelle
  primary_done_at   TIMESTAMPTZ,
  backups_done_at   TIMESTAMPTZ,          -- oder: Crypto-Shredding-Zeitpunkt
  vendors_notified_at TIMESTAMPTZ,        -- Art. 19 / Art. 28 Abs. 3 lit. g
  completed_at   TIMESTAMPTZ,
  status         TEXT NOT NULL
);

CREATE TABLE data_inventory (            -- Quelle der Wahrheit für Export UND VVT
  item_id        TEXT PRIMARY KEY,        -- 'users.email_enc', 'chat_messages.body_enc', ...
  data_category  TEXT NOT NULL,           -- L00-Klasse
  special_category BOOLEAN NOT NULL DEFAULT false,  -- Art. 9
  purpose        TEXT NOT NULL,
  legal_basis    TEXT NOT NULL,
  source         TEXT NOT NULL,           -- 'user','derived','vendor' (Art. 15 Abs. 1 lit. g)
  recipients     TEXT[],
  third_country_safeguard TEXT,           -- 'none','adequacy_DPF','SCC_2021_914', ...
  retention      INTERVAL,                -- oder Regeltext
  retention_rule TEXT,
  exportable     BOOLEAN NOT NULL DEFAULT true,
  erasable       BOOLEAN NOT NULL DEFAULT true,
  encryption     TEXT NOT NULL            -- 'field_envelope','disk','hash_only'
);
```

**Hinweise zu Aufbewahrung und Pseudonymisierung**
- Pseudonymisierte Daten bleiben personenbezogen (Art. 4 Nr. 5 und ErwGr 26). `processing_log` unterliegt also weiter der DSGVO, die Fristen gelten auch dort.
- `processing_log`: 12–36 Monate als Vorschlag, juristisch festzulegen. Nach der Löschung eines Nutzers bleibt `subject_ref` ohne Rückbezug, wenn die Zuordnung (`users`) gelöscht ist.
- Nachweise in `erasure_requests` und `consents`: Viele bewahren sie wegen der Rechenschaftspflicht (Art. 5 Abs. 2) bis zur regelmäßigen Verjährung (3 Jahre, § 195 BGB) auf. Das ist Praxis, kein Gesetzesbefehl. Der DSB legt es fest.
- Exportpakete: kurzlebig, z. B. 7 Tage, danach automatisch löschen.
- Steuerrelevante Daten (Rechnungen) unterliegen eigenen Pflichten (§ 147 AO, § 257 HGB) und sind die typische Ausnahme nach Art. 17 Abs. 3 lit. b.

### 4.2 JSON Schema für das Auskunftspaket (Art. 15)

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://example.eu/schemas/dsr-export/1.0.json",
  "title": "Art. 15 DSGVO Auskunftspaket",
  "type": "object",
  "required": ["manifest", "art15_information", "data"],
  "properties": {
    "manifest": {
      "type": "object",
      "required": ["schema_version", "request_id", "generated_at", "controller", "files"],
      "properties": {
        "schema_version": { "const": "1.0" },
        "request_id": { "type": "string", "format": "uuid" },
        "generated_at": { "type": "string", "format": "date-time" },
        "controller": {
          "type": "object",
          "required": ["name", "contact"],
          "properties": {
            "name": { "type": "string" }, "contact": { "type": "string" },
            "dpo_contact": { "type": "string" }
          }
        },
        "files": {
          "type": "array",
          "items": {
            "type": "object",
            "required": ["path", "sha256", "media_type"],
            "properties": {
              "path": { "type": "string" },
              "sha256": { "type": "string", "pattern": "^[a-f0-9]{64}$" },
              "media_type": { "enum": ["application/json", "text/csv"] }
            }
          }
        }
      }
    },
    "art15_information": {
      "type": "object",
      "description": "Pflichtangaben Art. 15 Abs. 1 lit. a-h und Abs. 2",
      "required": ["purposes", "categories", "recipients", "retention", "rights", "complaint_authority", "sources", "automated_decision_making"],
      "properties": {
        "purposes":   { "type": "array", "items": { "type": "string" } },
        "categories": { "type": "array", "items": { "type": "string" } },
        "recipients": { "type": "array", "items": {
          "type": "object",
          "properties": {
            "name": { "type": "string" }, "role": { "enum": ["processor", "controller", "joint_controller"] },
            "country": { "type": "string" }, "safeguard": { "type": "string" }
          } } },
        "retention":  { "type": "array", "items": {
          "type": "object", "properties": { "category": { "type": "string" }, "rule": { "type": "string" } } } },
        "rights": { "type": "array", "items": { "enum": ["art16", "art17", "art18", "art20", "art21"] } },
        "complaint_authority": { "type": "string" },
        "sources": { "type": "array", "items": { "type": "string" } },
        "automated_decision_making": {
          "type": "object",
          "properties": { "exists": { "type": "boolean" }, "logic": { "type": "string" }, "effects": { "type": "string" } }
        },
        "third_country_safeguards": { "type": "array", "items": { "type": "string" } }
      }
    },
    "data": {
      "type": "object",
      "properties": {
        "profile":        { "type": "object" },
        "consents":       { "type": "array", "items": { "type": "object" } },
        "chat_logs":      { "type": "array", "items": {
          "type": "object", "properties": {
            "message_id": { "type": "string" }, "created_at": { "type": "string", "format": "date-time" },
            "role": { "enum": ["user", "assistant"] }, "content": { "type": "string" },
            "redactions": { "type": "array", "items": { "type": "string" } } } } },
        "metrics":        { "type": "array", "items": { "type": "object" } },
        "processing_log": { "type": "array", "items": { "type": "object" } }
      }
    }
  }
}
```

### 4.3 CSV-Spezifikation (eine Datei je Abschnitt)

Allgemein: UTF-8 ohne BOM, RFC 4180, Komma als Trenner, Kopfzeile Pflicht, Zeitstempel ISO 8601 in UTC, leere Werte als leeres Feld (nicht `null`). Alle Dateien werden im `manifest` mit SHA-256 gelistet.

| Datei | Spalten |
|---|---|
| `profile.csv` | `user_id, email, display_name, locale, created_at, last_active_at, status` |
| `consents.csv` | `consent_id, purpose, legal_basis, text_version, granted_at, withdrawn_at, channel` |
| `chat_logs.csv` | `message_id, conversation_id, created_at, role, content, redacted_categories` |
| `metrics.csv` | `metric_id, name, value, unit, recorded_at, aggregation` |
| `processing_log.csv` | `occurred_at, action, data_category, purpose, legal_basis, recipient, third_country` (Akteure intern pseudonymisiert; Mitarbeiter-Identitäten nicht offenlegen, vgl. Art. 15 Abs. 4) |
| `recipients.csv` | `name, role, country, safeguard` |

**Hinweis zur Matrix:** „Maschinenlesbar“ ist streng genommen eine Anforderung aus Art. 20 Abs. 1 (strukturiert, gängig, maschinenlesbar). Art. 15 Abs. 3 verlangt bei elektronischem Antrag ein „gängiges elektronisches Format“. Ein Paket aus JSON und CSV erfüllt beides. Art. 20 betrifft aber nur die vom Nutzer *bereitgestellten* Daten, die auf Einwilligung oder Vertrag beruhen.

---

## 5. AVV-Checkliste (Art. 28 DSGVO)

**Pflichtinhalte nach Art. 28 Abs. 3 Satz 1:** Gegenstand und Dauer, Art und Zweck der Verarbeitung, Art der Daten, Kategorien Betroffener, Pflichten und Rechte des Verantwortlichen.

| Punkt | Inhalt | Prüffrage |
|---|---|---|
| lit. a | Verarbeitung nur auf dokumentierte Weisung, auch für Drittlandübermittlungen | Ist der Weisungsweg geregelt? Gibt es eine Ausnahme bei gesetzlicher Pflicht mit Vorab-Information? |
| lit. b | Vertraulichkeitsverpflichtung der befugten Personen | Schriftliche Verpflichtung oder gesetzliche Verschwiegenheit? |
| lit. c | alle Maßnahmen nach Art. 32 | Liegt eine konkrete TOM-Anlage vor, kein Verweis auf eine Website „in jeweils gültiger Fassung“ ohne Änderungsbenachrichtigung? |
| lit. d | Bedingungen für Unterauftragsverarbeiter (Abs. 2 und 4) | Gesonderte oder allgemeine schriftliche Genehmigung? Vorab-Info über Änderungen mit Widerspruchsrecht? Gleiche Pflichten für den Sub? |
| lit. e | Unterstützung bei Betroffenenrechten (Kapitel III) | Technische Mittel für Export und Löschung? Weiterleitungsfrist? |
| lit. f | Unterstützung bei Art. 32–36 (Sicherheit, Datenpannen, DSFA, Konsultation) | Meldefrist bei Datenpannen „unverzüglich“, idealerweise konkret, z. B. ≤24–48 h? |
| lit. g | Löschung oder Rückgabe nach Vertragsende, auch Kopien | Frist? Löschbestätigung? Backups? |
| lit. h | Nachweise und Überprüfungen inkl. Inspektionen | Auditrecht vor Ort oder per Zertifikat (ISO 27001, SOC 2 Type II)? Kostenregelung? |
| Abs. 3 Unterabs. 2 | Hinweispflicht bei rechtswidriger Weisung | Steht sie drin? |
| Abs. 9 | Schriftform, elektronisch genügt | Ist der AVV abgeschlossen und abgelegt? |

**Weitere Punkte**
- **Unterauftragsverarbeiter:** vollständige Liste mit Sitz und Funktion. Ziel aus L02 ist Kettentiefe 1. Änderungsmitteilungen abonnieren.
- **TOM-Anlage:** Verschlüsselung, Zugriffskontrolle, Protokollierung, Wiederherstellbarkeit, Testverfahren (Art. 32 Abs. 1 lit. a–d).
- **Drittlandübermittlung (Art. 44 ff.):**
  - (1) Angemessenheitsbeschluss (Art. 45). Für die USA gilt das EU-US Data Privacy Framework, Durchführungsbeschluss (EU) 2023/1795, **nur für zertifizierte Unternehmen**. Den Status prüfen auf dataprivacyframework.gov, auch je Tochtergesellschaft.
  - (2) Sonst Standardvertragsklauseln (Art. 46 Abs. 2 lit. c, Durchführungsbeschluss (EU) 2021/914, passendes Modul, meist Modul 2 C2P oder Modul 3 P2P) mit **Transfer Impact Assessment**.
  - (3) Ausnahmen nach Art. 49 nur restriktiv.
  - (4) Als Rückfall für den Fall, dass das DPF kippt, die SCCs im Vertrag mitvereinbaren.
- **KI-spezifisch:** Training mit Kundendaten vertraglich ausschließen. Aufbewahrungsdauer von Prompts und Logs festlegen (Zero-Retention-Option?). Abuse-Monitoring-Ausnahmen kennen.
- **Haftung:** Art. 82 regelt die Haftung gegenüber Betroffenen. Freistellungen im Innenverhältnis verhandeln.
- **Kunden-AVV (wenn B2B):** dieselben Punkte umgekehrt, dann ist man selbst Auftragsverarbeiter.

**Typische Anbieter und was zu prüfen ist.** Status- und Produktangaben ändern sich. Bitte jeweils aktuell verifizieren, die Tabelle ist keine Zusicherung.

| Anbieter | Rolle | Was prüfen |
|---|---|---|
| Hetzner (DE) | Hosting, auch für lokale LLMs | AVV im Kundenportal abschließen. EU-Standort, kein Drittland. Rechenzentrums-Standort wählen (DE/FI). |
| Supabase | DB, Auth, Storage | DPA verfügbar? EU-Region wählen (läuft auf AWS). US-Unternehmen: DPF-Status bzw. SCCs. Subprozessor-Liste (u. a. AWS). |
| AWS | IaaS | DPA ist in den Service Terms enthalten. DPF-Status. EU-Region und gegebenenfalls „EU Sovereign Cloud“ prüfen. KMS-Schlüssel in der EU. |
| Cloudflare | CDN, WAF | DPA, DPF-Status, Data Localization Suite (EU-Metadaten). Log-Aufbewahrung. |
| Anthropic / OpenAI / andere LLM-APIs | KI-Laufzeit | Kommerzielle Bedingungen mit DPA (nicht die Verbraucher-Tarife). Training-Opt-out und Default. Retention und Zero-Retention-Vereinbarung. Datenresidenz. DPF/SCC. |
| Apple (CloudKit, App Store Connect, TestFlight) | Plattform | Rollenverteilung klären (Apple teils eigener Verantwortlicher). Developer Program License Agreement mit Datenverarbeitungs-Regelungen. Tester-Daten in App Store Connect. |
| GitHub (Pages, Repo) | Website-Hosting, Code | GitHub DPA (für Pages-Besucher-IPs relevant). DPF-Status. Keine Nutzerdaten in Issues oder Logs. |
| E-Mail-Provider (Support) | Kommunikation | AVV, Standort, Aufbewahrung von Support-Mails. |
| Sentry / Crash-Reporting | Fehleranalyse | PII-Scrubbing, EU-Region, DPA, Sampling. Bei Echoelmusic heute nicht im Einsatz (keine Drittanbieter-SDKs laut `security.html`). |
| Stripe / Zahlungsdienst | Zahlung | Rollenfrage: Stripe ist teils eigener Verantwortlicher. Dazu DPA und SCC. |

**Unsichere Punkte:**
- Das genaue Anwendungsdatum von Art. 50 KI-VO nach möglichen späteren Änderungen der Verordnung.
- Ob ein aus der Herzfrequenz abgeleitetes Erregungsniveau unter „Emotionserkennung“ nach Art. 3 Nr. 39 KI-VO fällt.
- Die Verantwortlichen-Rolle bei einer reinen On-Device-App.

Diese drei Fragen gehören an Jurist oder DSB, am besten über `docs/dev/FOUNDER_INBOX.md`.

---

**Fundstellen im Repo (nur gelesen, nichts geändert)**

- `/home/user/Echoelmusic/docs/privacy.html`
- `/home/user/Echoelmusic/docs/security.html`
- `docs/screenshots/demo-audio.html`, `demo-coherence.html`, `demo-visual.html` — GELÖSCHT 2026-10-08 (trugen Google Fonts)
- `/home/user/Echoelmusic/Sources/Echoelmusic/Sync/AnnouncementCenter.swift`
- `/home/user/Echoelmusic/Sources/Echoelmusic/Core/CloudSync.swift`
- `/home/user/Echoelmusic/Sources/Echoelmusic/EchoelAI/FoundationModelsBrain.swift`
- `/home/user/Echoelmusic/Sources/Echoelmusic/Sequencer/BioMusicDirector.swift`
- `/home/user/Echoelmusic/Sources/Echoelmusic/Sync/MultipeerSession.swift`
- `/home/user/Echoelmusic/Sources/Echoelmusic/Core/WeatherProvider.swift` (laut `CLAUDE.md` am 2026-06-19 gelöscht, existiert aber und ruft `WeatherService` auf; diese Abweichung sollte man melden)
- `/home/user/Echoelmusic/memory/vision.md`