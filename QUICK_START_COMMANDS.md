# ⚡ Quick Start Commands

**Copy-Paste Ready Commands for Browser-Only Deployment**

> 📋 **Tipp:** Öffne diese Datei neben dem Hetzner Web Console Terminal und kopiere die Befehle einfach rüber!

---

## 🔧 Server-Setup (Einmalig)

### 1. System aktualisieren

```bash
apt-get update && apt-get upgrade -y
```

### 2. Docker installieren

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
docker --version
```

### 3. Docker Compose installieren

```bash
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
docker-compose --version
```

### 4. Nginx & Certbot installieren

```bash
apt-get install -y nginx certbot python3-certbot-nginx
```

### 5. Firewall konfigurieren

```bash
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
ufw status
```

---

## 📁 Projekt-Setup

### 1. Projektordner erstellen

```bash
mkdir -p /root/echoelmusic/backend
mkdir -p /root/echoelmusic/nginx
cd /root/echoelmusic
```

### 2. Backend-Code holen (via Git)

**Option A: Von GitHub clonen**
```bash
cd /root
git clone https://github.com/vibrationalforce/Echoelmusic.git
cd Echoelmusic/backend
```

**Option B: Manuell hochladen** (wenn kein Git)
- Nutze Hetzner File Upload (Web Console → Upload)
- Oder kopiere Files einzeln mit `nano`

---

## 🔐 Konfigurationsdateien erstellen

### 1. .env Datei erstellen

```bash
cd /root/echoelmusic/backend
nano .env
```

**Inhalt:** (aus Setup Wizard kopieren!)

```bash
# Nach dem Einfügen:
# STRG+O (Speichern)
# Enter (Bestätigen)
# STRG+X (Beenden)
```

### 2. docker-compose.yml erstellen

```bash
nano docker-compose.yml
```

**Inhalt:** (aus Setup Wizard kopieren!)

```bash
# Nach dem Einfügen: STRG+O → Enter → STRG+X
```

### 3. nginx.conf erstellen

```bash
mkdir -p nginx
nano nginx/nginx.conf
```

**Inhalt:** (aus Setup Wizard kopieren!)

```bash
# Nach dem Einfügen: STRG+O → Enter → STRG+X
```

---

## 🚀 Backend starten

### 1. Docker Container bauen und starten

```bash
cd /root/echoelmusic/backend
docker-compose up -d
```

### 2. Status prüfen

```bash
docker-compose ps
docker-compose logs -f api
```

**Erwartete Ausgabe:**
```
✅ echoelmusic-api    running
✅ echoelmusic-nginx  running
```

### 3. Health Check

```bash
curl http://localhost:3000/health
```

**Erwartete Ausgabe:**
```json
{"status":"ok","timestamp":"2024-11-15T..."}
```

---

## 🔒 SSL-Zertifikat einrichten (HTTPS)

### 1. Certbot ausführen

**⚠️ Wichtig:** Ersetze `api.echoelmusic.com` mit deiner Domain!

```bash
certbot --nginx -d api.echoelmusic.com
```

**Fragen beantworten:**
- Email: deine@email.com
- Terms: Y (Ja)
- Share email: N (Nein)
- Redirect HTTP → HTTPS: 2 (Ja)

### 2. Auto-Renewal testen

```bash
certbot renew --dry-run
```

### 3. Cron-Job für Auto-Renewal

```bash
crontab -e
```

**Zeile hinzufügen:**
```bash
0 5 1 * * certbot renew --nginx --quiet
```

---

## 🔄 Backend neu starten

### Stoppen

```bash
cd /root/echoelmusic/backend
docker-compose down
```

### Starten

```bash
docker-compose up -d
```

### Neu bauen (bei Code-Änderungen)

```bash
docker-compose down
docker-compose build
docker-compose up -d
```

### Logs ansehen

```bash
docker-compose logs -f
docker-compose logs -f api
docker-compose logs -f nginx
```

---

## 📊 Monitoring & Wartung

### 1. Server-Ressourcen prüfen

```bash
# CPU & RAM
htop

# Disk Space
df -h

# Docker Stats
docker stats
```

### 2. Logs ansehen

```bash
# API Logs
docker-compose logs -f api

# Nginx Logs
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log

# Alle Logs löschen (bei Platzmangel)
docker-compose logs --tail=0 -f
```

### 3. Alte Docker Images löschen

```bash
docker system prune -a
```

---

## 🆘 Troubleshooting

### Problem: Container startet nicht

```bash
# Logs prüfen
docker-compose logs api

# Container neu starten
docker-compose restart api
```

### Problem: Port 3000 schon belegt

```bash
# Welcher Prozess nutzt Port 3000?
lsof -i :3000

# Prozess beenden
kill -9 PROCESS_ID
```

### Problem: Nginx 502 Bad Gateway

```bash
# API läuft?
docker-compose ps api

# API erreichbar?
curl http://localhost:3000/health

# Nginx neu starten
docker-compose restart nginx
```

### Problem: SSL-Zertifikat abgelaufen

```bash
# Manuell erneuern
certbot renew --nginx

# Nginx neu laden
nginx -s reload
```

### Problem: Kein Speicherplatz mehr

```bash
# Speicher prüfen
df -h

# Docker aufräumen
docker system prune -a --volumes

# Logs löschen
rm -rf /var/log/nginx/*.log
```

---

## 🔄 Updates einspielen

### 1. Code von GitHub pullen

```bash
cd /root/Echoelmusic
git pull origin main
```

### 2. Backend neu bauen

```bash
cd backend
docker-compose down
docker-compose build
docker-compose up -d
```

### 3. Gesundheitscheck

```bash
sleep 10
curl http://localhost:3000/health
```

---

## 🗄️ Datenbank-Backup

### Manuelles Backup

```bash
# Timestamp für Backup
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Supabase Backup (via API)
curl -X POST https://YOUR_PROJECT.supabase.co/rest/v1/rpc/backup \
  -H "apikey: YOUR_SUPABASE_KEY" \
  -H "Content-Type: application/json" \
  > /root/backups/db_backup_$TIMESTAMP.sql
```

### Automatisches Backup (Cron)

```bash
crontab -e
```

**Zeile hinzufügen (täglich um 3 Uhr nachts):**
```bash
0 3 * * * /root/echoelmusic/scripts/backup.sh
```

**Backup-Script erstellen:**

```bash
nano /root/echoelmusic/scripts/backup.sh
```

**Inhalt:**
```bash
#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/root/backups"

mkdir -p $BACKUP_DIR

# Supabase Backup
curl -X POST https://YOUR_PROJECT.supabase.co/rest/v1/rpc/backup \
  -H "apikey: YOUR_SUPABASE_KEY" \
  > $BACKUP_DIR/db_$TIMESTAMP.sql

# Alte Backups löschen (älter als 7 Tage)
find $BACKUP_DIR -name "db_*.sql" -mtime +7 -delete

echo "Backup completed: $TIMESTAMP"
```

**Ausführbar machen:**
```bash
chmod +x /root/echoelmusic/scripts/backup.sh
```

---

## 📋 Schnelle Checkliste

### Nach Server-Neustart

```bash
# 1. Docker läuft?
systemctl status docker

# 2. Container starten
cd /root/echoelmusic/backend
docker-compose up -d

# 3. Nginx läuft?
systemctl status nginx

# 4. Health Check
curl http://localhost:3000/health
curl https://api.echoelmusic.com/health
```

### Vor jedem Deployment

```bash
# 1. Backup erstellen
/root/echoelmusic/scripts/backup.sh

# 2. Tests lokal laufen
npm test

# 3. Container stoppen
docker-compose down

# 4. Code pullen
git pull

# 5. Neu bauen
docker-compose build

# 6. Starten
docker-compose up -d

# 7. Health Check
sleep 10
curl http://localhost:3000/health
```

---

## 🎯 Ein-Befehl-Deployment

**Alles auf einmal (nur bei funktionierendem Setup!):**

```bash
cd /root/echoelmusic/backend && \
  docker-compose down && \
  git pull origin main && \
  docker-compose build && \
  docker-compose up -d && \
  sleep 10 && \
  curl http://localhost:3000/health
```

---

## 📞 Support

**Bei Problemen:**

1. **Logs prüfen:**
   ```bash
   docker-compose logs -f
   ```

2. **GitHub Issues:** https://github.com/vibrationalforce/Echoelmusic/issues

3. **Email:** michaelterbuyken@gmail.com

4. **Dokumentation:** Siehe `BROWSER_ONLY_DEPLOY.md`

---

## 🔗 Wichtige Links

- **Hetzner Console:** https://console.hetzner.cloud
- **Supabase Dashboard:** https://app.supabase.com
- **Stripe Dashboard:** https://dashboard.stripe.com
- **SSL Test:** https://www.ssllabs.com/ssltest/
- **Uptime Monitor:** https://uptimerobot.com

---

**Status:** ⚡ Ready to Deploy!

**Letzte Aktualisierung:** November 15, 2024

---

🎵 **Echoelmusic** - Where Creativity Meets Accessibility

© 2024 Echoel (Michael Terbuyken) | Hamburg, Germany
