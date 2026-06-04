# Guide Réseau — Connexion Application GPS → n8n Webhook
## Projet ETL_Projet_BC

---

| Champ        | Valeur                                          |
|--------------|-------------------------------------------------|
| **Projet**   | ETL_Projet_BC — Intégration Data Warehouse → BC |
| **Date**     | 2026-06-04                                      |
| **Auteur**   | Kodzo Nyanu                                     |

---

## 1. Situation réseau

```
[Réseau de l'application GPS]          [Réseau ETL — Docker Host]
  Sous-réseau app                         10.14.210.159 (ens34)
       │                                       │
       │  ←── traversée inter-réseau ──────────┤
       │       TCP port 5678                   │
       │                                  172.18.0.1 (bridge Docker)
       │                                       │
       ▼                                  172.18.0.5:5678
  App envoie POST                         n8n (container: ingestion_n8n)
  /webhook/distance-update                exposé 0.0.0.0:5678 → 5678
```

**Constat :** n8n écoute sur `0.0.0.0:5678` sur l'hôte — le port est déjà accessible depuis n'importe quel sous-réseau pouvant joindre `10.14.210.159`.

---

## 2. URL du webhook à donner à l'application

### Version HTTP (immédiatement utilisable)

```
http://10.14.210.159:5678/webhook/distance-update
```

### Version HTTPS (recommandée — voir section 4)

```
https://10.14.210.159/webhook/distance-update
```

---

## 3. Configuration requise côté application

L'application doit envoyer **obligatoirement** le header `X-API-KEY` dans chaque requête.

### Format de la requête

```http
POST http://10.14.210.159:5678/webhook/distance-update HTTP/1.1
Content-Type: application/json
X-API-KEY: <valeur_de_GPS_WEBHOOK_SECRET>

{
  "event": "distance_update",
  "session_id": "1717449600000",
  "timestamp": "2026-06-04T09:00:05.000Z",
  "distance_meters": 125.45,
  "distance_km": 0.12545,
  "speed_kmh": 9.0,
  "active_seconds": 5,
  "location": {
    "latitude": 48.8566,
    "longitude": 2.3522,
    "accuracy_meters": 4.5
  }
}
```

### Réponses possibles

| Code | Signification | Action côté app |
|------|--------------|-----------------|
| `200 { "status": "ok" }` | Événement traité | Continuer |
| `200 { "status": "ok", "message": "No change detected" }` | Hash identique, pas d'upload | Normal, continuer |
| `401 { "error": "Unauthorized" }` | Clé API absente ou incorrecte | Vérifier `X-API-KEY` |
| `500` | Erreur interne n8n | Retry après délai |

---

## 4. Configuration de la clé API dans n8n

### Étape 1 — Ajouter la variable dans n8n

Dans l'interface n8n (`http://10.14.210.159:5678`) :

```
Settings → Variables → Ajouter une variable

Nom   : GPS_WEBHOOK_SECRET
Valeur: <générer une clé forte — voir ci-dessous>
```

### Génération d'une clé sécurisée

```bash
# Générer une clé aléatoire de 32 octets (64 caractères hex)
openssl rand -hex 32
# Exemple de sortie : a3f8e2d1c4b5a6f7e8d9c0b1a2f3e4d5c6b7a8f9e0d1c2b3a4f5e6d7c8b9a0f1
```

### Exemple de valeur à configurer

```
GPS_WEBHOOK_SECRET = a3f8e2d1c4b5a6f7e8d9c0b1a2f3e4d5c6b7a8f9e0d1c2b3a4f5e6d7c8b9a0f1
```

> **Important :** cette valeur doit être partagée uniquement avec l'équipe développant l'application GPS. Ne jamais la committer dans le code source.

---

## 5. Mise en place du TLS (HTTPS) — Recommandé

Pour sécuriser le transit sur le réseau, il est recommandé de passer les communications en HTTPS. Deux approches sont possibles.

### Option A — Nginx reverse proxy (recommandée)

Installer nginx sur l'hôte Docker comme terminaison TLS, qui relaie vers n8n en HTTP interne.

#### 5.1 Créer un certificat auto-signé (réseau interne)

```bash
# Créer le répertoire de certificats
mkdir -p /etc/nginx/ssl/etl

# Générer le certificat auto-signé (valable 3 ans)
openssl req -x509 -nodes -days 1095 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/etl/privkey.pem \
  -out    /etc/nginx/ssl/etl/fullchain.pem \
  -subj "/C=FR/ST=IDF/L=Paris/O=ETLPipeline/CN=10.14.210.159"
```

#### 5.2 Configuration nginx (`/etc/nginx/sites-available/n8n-webhook`)

```nginx
server {
    listen 443 ssl;
    server_name 10.14.210.159;

    ssl_certificate     /etc/nginx/ssl/etl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/etl/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    # Exposer uniquement le webhook GPS — pas l'UI n8n
    location /webhook/distance-update {
        proxy_pass         http://127.0.0.1:5678;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto https;
        proxy_read_timeout 30s;
    }

    # Bloquer tout autre accès
    location / {
        return 403 '{"error":"Forbidden"}';
        add_header Content-Type application/json;
    }
}

# Redirection HTTP → HTTPS
server {
    listen 80;
    server_name 10.14.210.159;
    return 301 https://$host$request_uri;
}
```

#### 5.3 Activer et démarrer nginx

```bash
ln -s /etc/nginx/sites-available/n8n-webhook /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
```

#### 5.4 URL finale avec TLS

```
https://10.14.210.159/webhook/distance-update
```

> **Note côté application :** avec un certificat auto-signé, l'application devra soit désactiver la vérification TLS (`ssl_verify: false`), soit importer le fichier `fullchain.pem` comme CA de confiance.

---

### Option B — TLS natif n8n (plus simple, sans nginx)

Configurer n8n pour écouter directement en HTTPS en ajoutant ces variables d'environnement dans le `docker-compose.yml` du conteneur `ingestion_n8n` :

```yaml
environment:
  - N8N_PROTOCOL=https
  - N8N_SSL_KEY=/home/node/.n8n/ssl/privkey.pem
  - N8N_SSL_CERT=/home/node/.n8n/ssl/fullchain.pem
volumes:
  - /etc/nginx/ssl/etl:/home/node/.n8n/ssl:ro
```

Puis redémarrer : `docker compose restart ingestion_n8n`

L'URL devient alors :
```
https://10.14.210.159:5678/webhook/distance-update
```

---

## 6. Vérification de l'ouverture de port

### Depuis l'hôte ETL

```bash
# Vérifier que n8n écoute bien
ss -tlnp | grep 5678
# Résultat attendu : LISTEN 0 4096 0.0.0.0:5678

# Tester le webhook en local
curl -s -X POST http://localhost:5678/webhook/distance-update \
  -H "Content-Type: application/json" \
  -H "X-API-KEY: VOTRE_CLE" \
  -d '{"event":"distance_update","session_id":"TEST-001","timestamp":"2026-06-04T09:00:00.000Z","distance_meters":100,"distance_km":0.1,"speed_kmh":36,"active_seconds":10,"location":{"latitude":48.8566,"longitude":2.3522,"accuracy_meters":5}}'
```

### Depuis le sous-réseau de l'application GPS

```bash
# Tester la connectivité TCP (depuis la machine de l'app)
telnet 10.14.210.159 5678

# Tester le webhook complet
curl -s -X POST http://10.14.210.159:5678/webhook/distance-update \
  -H "Content-Type: application/json" \
  -H "X-API-KEY: VOTRE_CLE" \
  -d '{"event":"distance_update","session_id":"TEST-001","timestamp":"2026-06-04T09:00:00.000Z","distance_meters":100,"distance_km":0.1,"speed_kmh":36,"active_seconds":10,"location":{"latitude":48.8566,"longitude":2.3522,"accuracy_meters":5}}'

# Réponse attendue :
# {"status":"ok","message":"Distance event processed","sessionId":"TEST-001"}
```

### Test de rejet sans clé (vérifier la sécurité)

```bash
curl -s -X POST http://10.14.210.159:5678/webhook/distance-update \
  -H "Content-Type: application/json" \
  -d '{"event":"distance_update","session_id":"TEST-001",...}'

# Réponse attendue :
# {"error":"Unauthorized","message":"Missing or invalid X-API-KEY header"}
# HTTP 401
```

---

## 7. Checklist de mise en service

| # | Étape | Responsable | Statut |
|---|-------|-------------|--------|
| 1 | Générer la clé `GPS_WEBHOOK_SECRET` (`openssl rand -hex 32`) | ETL Admin | ☐ |
| 2 | Ajouter `GPS_WEBHOOK_SECRET` dans les variables n8n (Settings → Variables) | ETL Admin | ☐ |
| 3 | Recharger WF-04B dans n8n (import du JSON mis à jour) | ETL Admin | ☐ |
| 4 | Tester le webhook depuis l'hôte ETL (curl local) | ETL Admin | ☐ |
| 5 | Vérifier l'ouverture du port 5678 depuis le sous-réseau de l'app | Réseau / App Team | ☐ |
| 6 | Transmettre l'URL et la clé à l'équipe application (canal sécurisé) | ETL Admin | ☐ |
| 7 | (Optionnel) Mettre en place nginx + TLS | ETL Admin | ☐ |
| 8 | Test end-to-end depuis l'application GPS réelle | App Team | ☐ |

---

## 8. Récapitulatif à transmettre à l'équipe application

```
┌─────────────────────────────────────────────────────────────┐
│          INFORMATIONS D'INTÉGRATION GPS WEBHOOK             │
├─────────────────────────────────────────────────────────────┤
│  URL (HTTP)    : http://10.14.210.159:5678/webhook/         │
│                  distance-update                            │
│  URL (HTTPS)   : https://10.14.210.159/webhook/             │
│                  distance-update  (après config nginx)      │
│  Méthode       : POST                                       │
│  Content-Type  : application/json                           │
│  Auth header   : X-API-KEY: <valeur GPS_WEBHOOK_SECRET>     │
│  Réponse OK    : HTTP 200 { "status": "ok" }                │
│  Réponse ERR   : HTTP 401 { "error": "Unauthorized" }       │
└─────────────────────────────────────────────────────────────┘
```
