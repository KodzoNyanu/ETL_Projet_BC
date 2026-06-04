# Documentation Technique
## Projet ETL Pipeline — Intégration Gold → Business Central

---

| Champ        | Valeur                                          |
|--------------|-------------------------------------------------|
| **Projet**   | ETL_Projet_BC — Intégration Data Warehouse → BC |
| **Version**  | 2.0.0                                           |
| **Date**     | 2026-06-04                                      |
| **Auteur**   | Kodzo Nyanu                                     |

---

## Table des matières

1. [Architecture globale](#1-architecture-globale)
2. [Topologie réseau](#2-topologie-réseau)
3. [Diagrammes de flux](#3-diagrammes-de-flux)
4. [Architecture de l'extension AL](#4-architecture-de-lextension-al)
5. [Architecture n8n](#5-architecture-n8n)
6. [Architecture Apache Hop](#6-architecture-apache-hop)
7. [Schéma de la base de données Gold](#7-schéma-de-la-base-de-données-gold)
8. [Dictionnaire technique des composants](#8-dictionnaire-technique-des-composants)

---

## 1. Architecture globale

### 1.1 Vue d'ensemble — Architecture Médaillon étendue

```
╔══════════════════════════════════════════════════════════════════════╗
║                    ARCHITECTURE MÉDAILLON ÉTENDUE                    ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  [APP GPS]           [FICHIERS CSV]        [API EXTERNES]            ║
║  distance_update     clients, articles     (réservé)                 ║
║       │                    │                                         ║
║       ▼                    ▼                                         ║
║  ┌─────────────────────────────────────────┐                        ║
║  │          BRONZE — MinIO (S3)            │                        ║
║  │  raw/enrichment/distances/              │                        ║
║  │  raw/customers/, raw/articles/, ...     │                        ║
║  └───────────────────┬─────────────────────┘                        ║
║                      │ Apache Hop                                    ║
║                      ▼                                               ║
║  ┌─────────────────────────────────────────┐                        ║
║  │    SILVER — PostgreSQL (silver.*)        │                        ║
║  │  silver.distance_matrix (VARCHAR)        │                        ║
║  └───────────────────┬─────────────────────┘                        ║
║                      │ Apache Hop                                    ║
║                      ▼                                               ║
║  ┌─────────────────────────────────────────┐                        ║
║  │    GOLD — PostgreSQL (public.*)          │                        ║
║  │  dim_customers    dim_articles           │                        ║
║  │  dim_shipment_headers  dim_distances     │                        ║
║  │  fact_shipment_lines   fact_ecom_lines   │                        ║
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
| Base de données | PostgreSQL | 15 | Silver + Gold |
| Orchestrateur ETL | Apache Hop | 2.x | Pipelines Silver et Gold |
| Orchestrateur workflows | n8n | 1.x | Réception GPS, synchro BC |
| ERP | Microsoft Business Central | 26.0 OnPrem | Cible de synchronisation |
| Extension ERP | AL Runtime | 13.0 | Tables, logique, pages |
| Proxy NTLM | Squid / NTLM Proxy | — | Authentification BC |
| Conteneurisation | Docker + Docker Compose | 24.x | Isolation des services |

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
│  172.18.0.7  ┌─────────────┐                               │
│  Apache Hop  │  hop-server │  port 8080                    │
│              │  (optionnel)│                               │
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
| ETL Silver | Apache Hop | PostgreSQL 172.18.0.4 | 5432 | TCP/pg |
| ETL Gold | Apache Hop | PostgreSQL 172.18.0.4 | 5432 | TCP/pg |

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
  ├─ Versioned : raw/enrichment/distances/YYYY/MM/DD/distances_HHmmss.json
  └─ Latest    : raw/enrichment/distances/latest.json
  │
  ▼
Réponse HTTP 200 OK → App GPS
  │
  │  (déclenchement manuel ou planifié)
  ▼
Apache Hop — 05_silver_distances.hpl
  │
  ├─ Lire /staging/enrichment/distances_realtime.json
  ├─ Mapper champs JSON → silver.distance_matrix (VARCHAR)
  └─ TRUNCATE + INSERT silver.distance_matrix
  │
  ▼
Apache Hop — 05_dim_distances.hpl
  │
  ├─ Lire silver.distance_matrix
  ├─ ScriptValueMod : parse ISO→Timestamp, VARCHAR→Decimal/Integer
  └─ TRUNCATE + INSERT dim_distances
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
| `wf04b-distance-realtime-v1` | WF-04B | Webhook POST | Réception GPS → MinIO |
| `wf08-gold-to-bc-v2` | WF-08 | Webhook + Schedule + Sub | Orchestration sync Gold → BC |
| `wf08a-sync-customers-v1` | WF-08A | executeWorkflowTrigger | dim_customers → etlCustomers |
| `wf08b-sync-articles-v1` | WF-08B | executeWorkflowTrigger | dim_articles → etlArticles |
| `wf08c-sync-headers-v1` | WF-08C | executeWorkflowTrigger | dim_shipment_headers → etlShipmentHeaders |
| `wf08d-sync-distances-v1` | WF-08D | executeWorkflowTrigger | dim_distances → etlDistances |
| `wf08e-sync-shiplines-v1` | WF-08E | executeWorkflowTrigger | fact_shipment_lines → etlShipmentLines |
| `wf08f-sync-ecomlines-v1` | WF-08F | executeWorkflowTrigger | fact_ecommerce_lines → etlEcommerceLines |

### 5.2 Variables d'environnement n8n

| Variable | Valeur | Usage |
|----------|--------|-------|
| `BC_COMPANY_ID` | GUID de la société BC | Toutes les requêtes OData |

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

## 6. Architecture Apache Hop

### 6.1 Pipelines créés dans ETL_Projet_BC

| Fichier | Couche | Source | Destination | Mode |
|---------|--------|--------|-------------|------|
| `05_silver_distances.hpl` | Bronze→Silver | `/staging/enrichment/distances_realtime.json` | `silver.distance_matrix` | TRUNCATE + INSERT |
| `05_dim_distances.hpl` | Silver→Gold | `silver.distance_matrix` | `dim_distances` | TRUNCATE + INSERT |

### 6.2 Détail pipeline 05_dim_distances.hpl

```
[TableInput]                    [ScriptValueMod]              [TableOutput]
Read from                  ──▶  Parse types               ──▶  Load
silver.distance_matrix          ─────────────────               dim_distances
                                parseISO(first_event_at)
SELECT session_id,              parseISO(last_event_at)         TRUNCATE Y
       session_date,            parseFloat(dist_km)             specify_fields Y
       total_distance_km,       parseFloat(dist_m)
       total_distance_meters,   parseFloat(max_spd)             Mapping :
       max_speed_kmh,           parseFloat(avg_spd)             session_id
       avg_speed_kmh,           parseInt(act_secs)              session_date
       total_active_seconds,    parseInt(evt_cnt)               total_distance_km
       event_count,                                             total_distance_meters
       first_event_at,          Types sortants :                max_speed_kmh
       last_event_at            BigNumber(10,4)                 avg_speed_kmh
FROM silver.distance_matrix     BigNumber(10,2)                 total_active_seconds
                                BigNumber(10,3) × 2             event_count
                                Integer × 2                     first_event_at
                                Date × 2                        last_event_at
```

### 6.3 Connexion PostgreSQL (postgres_gold)

| Paramètre | Valeur |
|-----------|--------|
| Host | 172.18.0.4 |
| Port | 5432 |
| Database | data_warehouse_gold |
| User | nyanu |
| Schema Silver | silver |
| Schema Gold | public |

---

## 7. Schéma de la base de données Gold

### 7.1 Diagramme entité-relation (Gold)

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

### 7.2 Schéma Silver

```
silver.distance_matrix
─────────────────────────────────────────────────────
session_id             VARCHAR(50)   ← ID session GPS
session_date           VARCHAR(10)   ← YYYY-MM-DD
total_distance_km      VARCHAR(30)   ← valeur décimale
total_distance_meters  VARCHAR(30)   ← valeur décimale
max_speed_kmh          VARCHAR(30)   ← valeur décimale
avg_speed_kmh          VARCHAR(30)   ← calculé
total_active_seconds   VARCHAR(20)   ← entier
event_count            VARCHAR(20)   ← entier
first_event_at         VARCHAR(50)   ← ISO 8601
last_event_at          VARCHAR(50)   ← ISO 8601
```

---

## 8. Dictionnaire technique des composants

| Composant | Fichier | Rôle | Entrée | Sortie |
|-----------|---------|------|--------|--------|
| WF-04B | `n8n/workflows/04b_distance_webhook.json` | Réception GPS | Événement JSON | MinIO + staging |
| WF-08 | `n8n/workflows/08_gold_to_bc.json` | Orchestration | Trigger | Résumé sync |
| WF-08A | `n8n/workflows/08a_sync_customers.json` | Sync customers | PostgreSQL | BC etlCustomers |
| WF-08B | `n8n/workflows/08b_sync_articles.json` | Sync articles | PostgreSQL | BC etlArticles |
| WF-08C | `n8n/workflows/08c_sync_headers.json` | Sync headers | PostgreSQL | BC etlShipmentHeaders |
| WF-08D | `n8n/workflows/08d_sync_distances.json` | Sync distances | PostgreSQL | BC etlDistances |
| WF-08E | `n8n/workflows/08e_sync_shipment_lines.json` | Sync ship. lines | PostgreSQL | BC etlShipmentLines |
| WF-08F | `n8n/workflows/08f_sync_ecommerce_lines.json` | Sync ecom. lines | PostgreSQL | BC etlEcommerceLines |
| Pipeline Silver | `apache_hop_data/pipelines/silver/05_silver_distances.hpl` | JSON→Silver | Staging JSON | silver.distance_matrix |
| Pipeline Gold | `apache_hop_data/pipelines/gold/05_dim_distances.hpl` | Silver→Gold | silver.distance_matrix | dim_distances |
| Migration SQL | `schema_gold_updates.sql` | Mise à jour schéma | — | Schéma Gold mis à jour |
| Codeunit AL | `al_etl_extension/src/Codeunit50210.ETLBCImportManager.al` | Logique BC | Appel AL | Tables BC + HTTP |
| Tables AL | `al_etl_extension/src/Table502XX.*.al` | Stockage BC | API OData | Enregistrements BC |
| Dashboard AL | `al_etl_extension/src/Page50211.ETLBCDashboard.al` | Supervision | Tables AL | Interface utilisateur |
