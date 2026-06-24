# Documentation Technique
## Projet ETL Pipeline — Intégration Gold → Business Central

---

| Champ        | Valeur                                          |
|--------------|-------------------------------------------------|
| **Projet**   | ETL_Projet_BC — Intégration Data Warehouse → BC |
| **Version**  | 2.1.0                                           |
| **Date**     | 2026-06-12                                      |
| **Auteur**   | Kodzo Nyanu                                     |

---

## Table des matières

1. [Architecture globale](#1-architecture-globale)
   - 1.3 [Structure du bucket Bronze (MinIO)](#13-structure-du-bucket-bronze-minio)
2. [Topologie réseau](#2-topologie-réseau)
3. [Diagrammes de flux](#3-diagrammes-de-flux)
4. [Architecture de l'extension AL](#4-architecture-de-lextension-al)
5. [Architecture n8n](#5-architecture-n8n)
6. [Schéma de la base de données Gold](#6-schéma-de-la-base-de-données-gold)
7. [Dictionnaire technique des composants](#7-dictionnaire-technique-des-composants)

---

## 1. Architecture globale

### 1.1 Vue d'ensemble — Architecture Médaillon étendue

```
╔══════════════════════════════════════════════════════════════════════╗
║                    ARCHITECTURE MÉDAILLON ÉTENDUE                    ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  [APP GPS]    [CSV/JSON]   [PG Windows]  [Véhicules]  [API EXT]     ║
║  distance_    data.csv    clients,       logistics    (réservé)      ║
║  update       data.json   articles...    JSON                        ║
║       │           │            │             │                       ║
║       ▼           ▼            ▼             ▼                       ║
║  ┌─────────────────────────────────────────────────────────────┐    ║
║  │               BRONZE — MinIO (bucket: bronze)               │    ║
║  │  etl-projet-bc/raw/                                         │    ║
║  │  ├─ flat_files/                                             │    ║
║  │  │   ├─ data_csv/YYYY/MM/DD/YYYYMMDD_HHmm/data.csv         │    ║
║  │  │   └─ data_merged.json   (CSV+JSON fusionnés)            │    ║
║  │  ├─ database/                                               │    ║
║  │  │   ├─ articles/latest/articles.json                       │    ║
║  │  │   ├─ clients/latest/clients.json                         │    ║
║  │  │   ├─ salesshipmentheader/latest/                         │    ║
║  │  │   └─ salesshipmentline/latest/                           │    ║
║  │  ├─ distances/                                              │    ║
║  │  │   ├─ YYYY/MM/DD/YYYYMMDD_HHmm/distances_realtime.json   │    ║
║  │  │   └─ latest/distances_realtime.json                      │    ║
║  │  └─ vehicles/                                               │    ║
║  │      ├─ gestion_logistique_vehicules_YYYY-MM-DD.json        │    ║
║  │      └─ gestion_logistique_vehicules_latest.json            │    ║
║  └───────────────────────┬─────────────────────────────────────┘    ║
║                      │ n8n (lecture directe)                        ║
║                      ▼                                               ║
║  ┌─────────────────────────────────────────┐                        ║
║  │    GOLD — PostgreSQL (bc_gold.*)         │                        ║
║  │  clients          articles               │                        ║
║  │  salesshipmentheader  distances          │                        ║
║  │  salesshipmentline  (ecom via staging)   │                        ║
║  └───────────────────┬─────────────────────┘                        ║
║                      │ n8n WF-08 (OData HTTP)                       ║
║                      ▼                                               ║
║  ┌─────────────────────────────────────────┐                        ║
║  │    BUSINESS CENTRAL — Extension AL       │                        ║
║  │  ETLBCCustomer    ETLBCArticle           │                        ║
║  │  ETLBCShipmentHeader  ETLBCDistance      │                        ║
║  │  ETLBCShipmentLine  ETLBCEcommerceLine   │                        ║
║  │  ──────────────────────────────────────  │                        ║
║  │  Dashboard (Page50211) + Listes          │                        ║
║  └─────────────────────────────────────────┘                        ║
╚══════════════════════════════════════════════════════════════════════╝
```

### 1.2 Composants techniques

| Composant | Technologie | Version | Rôle |
|-----------|-------------|---------|------|
| Stockage Bronze | MinIO | RELEASE.2024 | Stockage objet S3-compatible |
| Base de données Gold | PostgreSQL | 15 | bc_gold — données lues par n8n |
| Orchestrateur workflows | n8n | 2.21.7 | Réception GPS, Bronze → BC, supervision |
| ERP | Microsoft Business Central | 26.0 OnPrem | Cible de synchronisation |
| Extension ERP | AL Runtime | 13.0 | Tables, logique, pages |
| Proxy NTLM | Squid / NTLM Proxy | — | Authentification BC |
| Conteneurisation | Docker + Docker Compose | 24.x | Isolation des services |

### 1.3 Structure du bucket Bronze (MinIO)

Bucket : **`bronze`** — préfixe projet : `etl-projet-bc/raw/`

```
bronze/
└─ etl-projet-bc/
   └─ raw/
      ├─ flat_files/                             ← Fichiers sources plats
      │   ├─ data_csv/
      │   │   └─ YYYY/MM/DD/YYYYMMDD_HHmm/
      │   │       └─ data.csv                    (19 MiB, versionné par WF-01BC)
      │   └─ data_merged.json                    (103 MiB, CSV+JSON fusionnés)
      │
      ├─ database/                               ← Extraits PostgreSQL Windows
      │   ├─ articles/latest/articles.json
      │   ├─ clients/latest/clients.json
      │   ├─ salesshipmentheader/latest/salesshipmentheader.json
      │   └─ salesshipmentline/latest/salesshipmentline.json
      │
      ├─ distances/                              ← Télémétrie GPS temps réel
      │   ├─ YYYY/MM/DD/YYYYMMDD_HHmm/
      │   │   └─ distances_realtime.json         (versionné à chaque événement)
      │   └─ latest/distances_realtime.json      (dernière version)
      │
      └─ vehicles/                               ← Référentiel véhicules
          ├─ gestion_logistique_vehicules_YYYY-MM-DD.json  (versionné)
          └─ gestion_logistique_vehicules_latest.json
```

| Sous-dossier | Workflow producteur | Fréquence |
|---|---|---|
| `flat_files/data_csv/` | WF-01BC | À la demande / WF-08 |
| `flat_files/data_merged.json` | WF-01BC | À la demande / WF-08 |
| `database/*/latest/` | WF-03BC | À la demande / WF-08 |
| `distances/` | WF-04B | Temps réel (chaque événement GPS) |
| `vehicles/` | WF-06 | À la demande (CDC sur fichier) |

---

## 2. Topologie réseau

### 2.1 Réseau Docker `etl_network`

```
┌─────────────────────────────────────────────────────────────┐
│                   etl_network  172.18.0.0/16                │
│                                                             │
│  172.18.0.4  ┌─────────────┐                               │
│  PostgreSQL  │  postgres   │  port 5432                    │
│              │  data_wh_   │  base: data_warehouse_gold    │
│              │  gold       │  user: nyanu                  │
│              └──────┬──────┘                               │
│                     │                                       │
│  172.18.0.5  ┌─────────────┐                               │
│  n8n         │    n8n      │  port 5678                    │
│              │  workflows  │  webhooks REST                │
│              └──────┬──────┘                               │
│                     │                                       │
│  172.18.0.6  ┌─────────────┐                               │
│  MinIO       │   minio     │  port 9000 (API S3)           │
│              │             │  port 9001 (Console)          │
│              └──────┬──────┘                               │
│                     │                                       │
│  172.18.0.8  ┌─────────────┐                               │
│  Proxy NTLM  │   proxy     │  port 3128                    │
│              │  (Squid +   │  auth: NTLM → BC              │
│              │   NTLM)     │                               │
│              └──────┬──────┘                               │
│                     │                                       │
└─────────────────────┼───────────────────────────────────────┘
                      │ NTLM / HTTP
                      ▼
              ┌───────────────┐
              │  Business     │  /BC260/api/etlpipeline/
              │  Central      │  warehouse/v1.0/
              │  OnPrem 26.0  │
              └───────────────┘
```

### 2.2 Flux réseau par cas d'usage

| Flux | Source | Destination | Port | Protocole |
|------|--------|-------------|------|-----------|
| Réception GPS | App GPS (externe) | n8n 172.18.0.5 | 5678 | HTTP POST |
| Upload MinIO | n8n | MinIO 172.18.0.6 | 9000 | HTTP S3 |
| Lecture Gold | n8n sous-workflows | PostgreSQL 172.18.0.4 | 5432 | TCP/pg |
| Sync → BC | n8n → Proxy | BC via 172.18.0.8 | 3128 | HTTP/NTLM |
| Trigger sync | BC Codeunit | n8n 172.18.0.5 | 5678 | HTTP POST |
| Lecture bc_gold | n8n WF-09BC | PostgreSQL 172.18.0.4 | 5432 | TCP/pg |

---

## 3. Diagrammes de flux

### 3.1 Flux GPS : Événement → Gold

```
App GPS
  │
  │  POST /webhook/distance-update
  │  { event, session_id, timestamp,
  │    distance_km, speed_kmh, active_seconds,
  │    location: {lat, lon, accuracy} }
  ▼
n8n WF-04B — Nœud "Accumuler Session"
  │
  ├─ Lire distances_realtime.json
  ├─ session_id existe ?
  │     OUI → Accumuler (+=distance, +=active_secs, max speed, last_event)
  │     NON → Créer entrée (first_event_at = timestamp)
  ├─ Recalculer avg_speed = (total_km / total_secs) × 3600
  └─ Écrire distances_realtime.json
  │
  ▼
n8n WF-04B — Nœud "CDC Hash"
  │
  ├─ MD5(distances_realtime.json)
  ├─ Hash == checksum précédent ?
  │     OUI → Réponse 200 (fin, pas d'upload)
  │     NON → Continuer
  │
  ▼
n8n WF-04B — Nœud "Upload MinIO"
  │
  ├─ Versioned : raw/distances/YYYY/MM/DD/YYYYMMDD_HHmm/distances_realtime.json
  └─ Latest    : raw/distances/latest/distances_realtime.json
  │
  ▼
Réponse HTTP 200 OK → App GPS
  │
  │  (déclenchement via WF-04B → WF-08D automatique)
  ▼
WF-08D — Sync distances → BC (etlDistances OData)
  │
  ├─ SELECT * FROM bc_gold.distances
  ├─ POST /etlDistances → 409 → PATCH (upsert)
  └─ return { table, total, inserted, updated, errors }
```

### 3.2 Flux synchronisation Gold → BC (WF-08 complet)

```
                    ┌─────────────────┐
                    │   DÉCLENCHEURS  │
                    └────────┬────────┘
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
   Webhook POST       Schedule 09h00     Sous-workflow
   /run-gold-to-bc    (cron 0 9 * * *)   parent
          │                  │                  │
          └──────────────────┴──────────────────┘
                             │
                             ▼
                    WF-08 Orchestrateur
                             │
              ┌──────────────▼──────────────┐
              │     Execute WF-08A          │
              │   dim_customers → BC        │
              │   { inserted, updated, errors } │
              └──────────────┬──────────────┘
                             │
              ┌──────────────▼──────────────┐
              │     Execute WF-08B          │
              │   dim_articles → BC         │
              └──────────────┬──────────────┘
                             │
              ┌──────────────▼──────────────┐
              │     Execute WF-08C          │
              │   dim_shipment_headers → BC │
              └──────────────┬──────────────┘
                             │
              ┌──────────────▼──────────────┐
              │     Execute WF-08D          │
              │   dim_distances → BC        │
              └──────────────┬──────────────┘
                             │
              ┌──────────────▼──────────────┐
              │     Execute WF-08E          │
              │   fact_shipment_lines → BC  │
              └──────────────┬──────────────┘
                             │
              ┌──────────────▼──────────────┐
              │     Execute WF-08F          │
              │   fact_ecommerce_lines → BC │
              │   (LIMIT 10 000)            │
              └──────────────┬──────────────┘
                             │
                    ┌────────▼────────┐
                    │  Merge (append) │
                    │  6 résultats    │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  Résumé sync BC │
                    │  total_inserted │
                    │  total_updated  │
                    │  total_errors   │
                    │  status: success│
                    │          partial│
                    └─────────────────┘
```

### 3.3 Logique upsert par enregistrement

```
Pour chaque ligne PostgreSQL :
         │
         ▼
    POST /ENTITY  {payload JSON}
         │
    ┌────┴────┐
    │  201 ?  │ ──── OUI ──▶ { action: 'inserted' }
    └────┬────┘
         │ NON
    ┌────▼────┐
    │ 409/422?│ ──── NON ──▶ { action: 'error', status, detail }
    └────┬────┘
         │ OUI
         │
   [Clé simple]          [Clé composée]
   PATCH /ENTITY         GET /ENTITY?$filter=A eq 'x' and B eq y
   ('keyValue')          └─▶ Récupérer GUID BC
         │                          │
         ▼                   PATCH /ENTITY(guid)
    200 OK ?                        │
    { action: 'updated' }    200 OK → { action: 'updated' }
                             404    → { action: 'error' }
```

---

## 4. Architecture de l'extension AL

### 4.1 Diagramme des objets AL

```
┌─────────────────────────────────────────────────────────────┐
│               EXTENSION AL — ETL Pipeline Warehouse BC      │
│                   app.json v2.0.0.0 | range 50200-50215     │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         Codeunit50210 — ETLBCImportManager           │   │
│  │  ─────────────────────────────────────────────────   │   │
│  │  + TriggerFullSync()                                 │   │
│  │  + UpsertCustomer(id, name, country, ...)            │   │
│  │  + UpsertArticle(id, desc, uom, ...)                 │   │
│  │  + UpsertShipmentHeader(id, custId, ...)             │   │
│  │  + UpsertDistance(sessionId, date, km, ...)          │   │
│  │  + UpsertShipmentLine(docNo, lineNo, ...)            │   │
│  │  + UpsertEcommerceLine(invNo, lineNo, ...)           │   │
│  │  + GetRecordCount(TableName): Integer                │   │
│  └───────────────┬──────────────────────────────────────┘   │
│                  │ utilise                                   │
│          ┌───────┴────────────────────────┐                 │
│          │                                │                 │
│  ┌───────▼──────┐  ┌──────────────────────▼──────────────┐  │
│  │  Tables AL   │  │         Pages AL                     │  │
│  │  (données)   │  │                                      │  │
│  │              │  │  Page50211 — ETLBCDashboard          │  │
│  │  T50200      │  │  (CardPage — supervision principale) │  │
│  │  ShipHeader  │  │  ┌─ Groupe Stats (GetRecordCount)   │  │
│  │              │  │  ├─ Part : ETLBCDistanceList         │  │
│  │  T50201      │  │  └─ Actions : SyncAll, Navigation   │  │
│  │  Distance    │  │                                      │  │
│  │              │  │  Page50200 — ShipmentHeaderList      │  │
│  │  T50202      │  │  Page50201 — DistanceList            │  │
│  │  ShipLine    │  │  Page50202 — ShipmentLineList        │  │
│  │              │  │  Page50203 — EcommerceLineList       │  │
│  │  T50203      │  │  Page50204 — CustomerList            │  │
│  │  EcomLine    │  │  Page50205 — ArticleList             │  │
│  │              │  │  (toutes en lecture seule)           │  │
│  │  T50204      │  └──────────────────────────────────────┘  │
│  │  Customer    │                                            │
│  │              │                                            │
│  │  T50205      │                                            │
│  │  Article     │                                            │
│  └──────────────┘                                            │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 Détail Codeunit50210 — méthodes et interactions

| Méthode | Interaction externe | Table cible |
|---------|-------------------|-------------|
| `TriggerFullSync()` | HTTP POST → n8n `/webhook/run-gold-to-bc` | — |
| `UpsertCustomer()` | Rec.GET + Rec.INSERT/MODIFY | ETLBCCustomer (50204) |
| `UpsertArticle()` | Rec.GET + Rec.INSERT/MODIFY | ETLBCArticle (50205) |
| `UpsertShipmentHeader()` | Rec.GET + Rec.INSERT/MODIFY | ETLBCShipmentHeader (50200) |
| `UpsertDistance()` | Rec.GET + Rec.INSERT/MODIFY | ETLBCDistance (50201) |
| `UpsertShipmentLine()` | Rec.GET + Rec.INSERT/MODIFY | ETLBCShipmentLine (50202) |
| `UpsertEcommerceLine()` | Rec.GET + Rec.INSERT/MODIFY | ETLBCEcommerceLine (50203) |
| `GetRecordCount()` | Rec.COUNT | Table dynamique par nom |

### 4.3 Plages d'ID AL

| Plage | Objets |
|-------|--------|
| 50200–50205 | Tables (6 entités) |
| 50210 | Codeunit (logique) |
| 50200–50205 | Pages liste (lecture seule) |
| 50211 | Page Dashboard |

---

## 5. Architecture n8n

### 5.1 Inventaire des workflows

| ID workflow | Nom | Déclencheurs | Rôle |
|-------------|-----|-------------|------|
| `wf01bc-csv-json-minio-v1` | WF-01BC | executeWorkflowTrigger | data.csv + data.json → data_merged.json → MinIO raw/flat_files/ |
| `wf03bc-postgres-minio-v1` | WF-03BC | executeWorkflowTrigger | PostgreSQL Windows → MinIO raw/database/ |
| `wf04b-distance-realtime-v1` | WF-04B | Webhook POST (ngrok) | Réception GPS → MinIO raw/distances/ → WF-08D |
| `wf06-vehicles-minio-v1` | WF-06 | Webhook POST | gestion_logistique_vehicules.json → MinIO raw/vehicles/ + bc_gold |
| `wf08-gold-to-bc-v2` | WF-08 | Webhook + Schedule 02h00 + Sub | Orchestration complète Bronze → BC → Gold |
| `wf08a-sync-customers-v1` | WF-08A | executeWorkflowTrigger | clients → etlCustomers (BC OData) |
| `wf08b-sync-articles-v1` | WF-08B | executeWorkflowTrigger | articles → etlArticles (BC OData) |
| `wf08c-sync-headers-v1` | WF-08C | executeWorkflowTrigger | salesshipmentheader → etlShipmentHeaders (BC OData) |
| `wf08d-sync-distances-v1` | WF-08D | executeWorkflowTrigger | distances → etlDistances (BC OData) |
| `wf08e-sync-shiplines-v1` | WF-08E | executeWorkflowTrigger | salesshipmentline → etlShipmentLines (BC OData) |
| `wf08f-sync-ecomlines-v1` | WF-08F | executeWorkflowTrigger | data_merged → etlEcommerceLines (BC OData) |
| `wf09bc-bc-to-gold-v1` | WF-09BC | executeWorkflowTrigger | BC OData → bc_gold PostgreSQL (lecture inverse) |
| `wf10bc-health-monitor-v1` | WF-10BC | Schedule | Health check BC + alertes Gmail |

### 5.2 Variables d'environnement n8n

| Variable | Valeur | Usage |
|----------|--------|-------|
| `BC_COMPANY_ID` | GUID de la société BC | Toutes les requêtes OData |
| `GPS_WEBHOOK_SECRET` | Hash SHA-256 (64 car.) | Validation X-API-KEY — WF-04B |

### 5.3 Pattern de nœud Code (sous-workflows 08A–08F)

Chaque sous-workflow contient exactement 2 nœuds :

```
[executeWorkflowTrigger]  →  [Code node]
                              ├─ require('pg') + require('http')
                              ├─ Connexion PostgreSQL 172.18.0.4:5432
                              ├─ SELECT * FROM table_gold
                              ├─ for (row of rows) → upsert(row)
                              │     POST → 409/422 → PATCH
                              └─ return [{ json: {table, total, inserted, updated, errors} }]
```

---

## 6. Schéma de la base de données Gold

### 6.1 Diagramme entité-relation (Gold)

```
┌──────────────────┐        ┌────────────────────────┐
│  dim_customers   │        │  dim_shipment_headers   │
│─────────────────-│        │────────────────────────-│
│ customer_id  PK  │◄───┐   │ header_id  PK           │
│ name             │    │   │ customer_id  FK ─────────┤
│ country          │    │   │ order_no                │
│ post_code        │    └───┤ shipment_date           │
│ location_code    │        │ ship_to_city            │
│ currency_code    │        │ ship_to_country         │
│ salesperson_code │        └───────────┬─────────────┘
└──────────────────┘                    │
                                        │
                        ┌───────────────▼─────────────┐
                        │   fact_shipment_lines        │
                        │─────────────────────────────-│
                        │ document_no  PK              │
                        │ line_no      PK              │
                        │ article_id   FK ─────────────┐
                        │ quantity                     │
                        │ location_code                │
                        └──────────────────────────────┤
                                                       │
┌──────────────────┐                    ┌──────────────▼─────┐
│   dim_articles   │                    │   fact_ecom_lines  │
│─────────────────-│                    │───────────────────-│
│ article_id  PK   │◄───────────────────┤ invoice_no   PK    │
│ description      │    (stock_code     │ line_no      PK    │
│ unit_of_measure  │     référence)     │ stock_code         │
│ type             │                    │ description        │
│ item_category    │                    │ quantity           │
│ unit_price       │                    │ unit_price         │
│ unit_cost        │                    │ total_amount       │
│ costing_method   │                    │ customer_id        │
└──────────────────┘                    │ country            │
                                        │ invoice_date       │
                                        └────────────────────┘

┌───────────────────────────┐
│      dim_distances        │
│──────────────────────────-│
│ session_id          PK    │  ← Clé = timestamp Unix ms
│ session_date              │
│ total_distance_km         │
│ total_distance_meters     │
│ max_speed_kmh             │
│ avg_speed_kmh             │
│ total_active_seconds      │
│ event_count               │
│ first_event_at            │
│ last_event_at             │
│ extracted_at              │
└───────────────────────────┘
```

---

## 7. Dictionnaire technique des composants

| Composant | Fichier | Rôle | Entrée | Sortie |
|-----------|---------|------|--------|--------|
| WF-01BC | `n8n/workflows/01bc_csv_json_to_minio.json` | Fusion CSV+JSON → Bronze | `/data_sources/data.csv` | MinIO `raw/flat_files/data_merged.json` |
| WF-03BC | `n8n/workflows/03bc_postgres_to_minio.json` | PG Windows → Bronze | PostgreSQL Windows | MinIO `raw/database/*/latest/` |
| WF-04B | `n8n/workflows/04b_distance_webhook.json` | Réception GPS temps réel | Webhook POST (ngrok) | MinIO `raw/distances/` + staging + WF-08D |
| WF-06 | `n8n/workflows/06_vehicles_to_minio.json` | Véhicules → Bronze | JSON fichier local | MinIO `raw/vehicles/` + bc_gold |
| WF-08 | `n8n/workflows/08_gold_to_bc.json` | Orchestration complète | Webhook / Schedule | Résumé sync (inserts+updates) |
| WF-08A | `n8n/workflows/08a_sync_customers.json` | Sync clients | PostgreSQL | BC etlCustomers |
| WF-08B | `n8n/workflows/08b_sync_articles.json` | Sync articles | PostgreSQL | BC etlArticles |
| WF-08C | `n8n/workflows/08c_sync_headers.json` | Sync en-têtes expédition | PostgreSQL | BC etlShipmentHeaders |
| WF-08D | `n8n/workflows/08d_sync_distances.json` | Sync distances | PostgreSQL bc_gold | BC etlDistances |
| WF-08E | `n8n/workflows/08e_sync_shipment_lines.json` | Sync lignes expédition | PostgreSQL | BC etlShipmentLines |
| WF-08F | `n8n/workflows/08f_sync_ecommerce_lines.json` | Sync lignes e-commerce | MinIO data_merged.json | BC etlEcommerceLines |
| WF-09BC | `n8n/workflows/09bc_bc_to_gold.json` | Lecture inverse BC→Gold | BC OData | bc_gold PostgreSQL |
| WF-10BC | `n8n/workflows/10bc_health_monitor.json` | Supervision + alertes | Schedule | Gmail alertes |
| Migration SQL | `schema_gold_updates.sql` | Mise à jour schéma | — | Schéma Gold mis à jour |
| Codeunit AL | `al_etl_extension/src/Codeunit50210.ETLBCImportManager.al` | Logique BC | Appel AL | Tables BC + HTTP |
| Tables AL | `al_etl_extension/src/Table502XX.*.al` | Stockage BC | API OData | Enregistrements BC |
| Dashboard AL | `al_etl_extension/src/Page50211.ETLBCDashboard.al` | Supervision | Tables AL | Interface utilisateur |
