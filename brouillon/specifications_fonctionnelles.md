# Spécifications Fonctionnelles
## Projet ETL Pipeline — Intégration Gold → Business Central

---

| Champ             | Valeur                                              |
|-------------------|-----------------------------------------------------|
| **Projet**        | ETL_Projet_BC — Intégration Data Warehouse → BC     |
| **Version**       | 2.0.0                                               |
| **Date**          | 2026-06-04                                          |
| **Auteur**        | Kodzo Nyanu                                         |
| **Référence CDC** | `docs/cahier_des_charges.md`                        |

---

## Table des matières

1. [Vue d'ensemble du système](#1-vue-densemble-du-système)
2. [Cas d'usage](#2-cas-dusage)
3. [Règles métier](#3-règles-métier)
4. [Règles de validation des données](#4-règles-de-validation-des-données)
5. [Dictionnaire des données](#5-dictionnaire-des-données)
6. [Gestion des erreurs et cas limites](#6-gestion-des-erreurs-et-cas-limites)
7. [Contraintes d'intégrité](#7-contraintes-dintégrité)

---

## 1. Vue d'ensemble du système

### 1.1 Flux de données global

```
[Application GPS]
      │  POST /webhook/distance-update
      │  { event, session_id, timestamp, distance_meters,
      │    distance_km, speed_kmh, active_seconds, location }
      ▼
[n8n WF-04B — Réception GPS]
      │  Accumulation par session_id
      │  distances_realtime.json
      │  CDC hash → MinIO raw/enrichment/distances/
      ▼
[Apache Hop — 05_silver_distances.hpl]
      │  JSON → silver.distance_matrix (VARCHAR)
      ▼
[Apache Hop — 05_dim_distances.hpl]
      │  Parse types → dim_distances (DECIMAL, TIMESTAMP)
      ▼
[PostgreSQL Gold]  ←──  dim_customers, dim_articles,
      │                  dim_shipment_headers, dim_distances,
      │                  fact_shipment_lines, fact_ecommerce_lines
      │
      │  [WF-08 Orchestrateur]
      │  Déclencheur : Webhook /run-gold-to-bc
      │              | Schedule 09h00
      │              | Sous-workflow parent
      │
      ▼
[n8n WF-08A à 08F — Sous-workflows]
      │  POST → 409/422 → PATCH (upsert OData)
      ▼
[Business Central — Extension AL]
      │  etlCustomers, etlArticles, etlShipmentHeaders,
      │  etlDistances, etlShipmentLines, etlEcommerceLines
      ▼
[Page Dashboard BC — Supervision]
```

### 1.2 Composants du système

| Composant | Rôle | Technologie |
|-----------|------|-------------|
| WF-04B | Réception et accumulation GPS | n8n |
| WF-08 | Orchestration sync Gold → BC | n8n |
| WF-08A à 08F | Synchronisation par table | n8n (sous-workflows) |
| 05_silver_distances | Bronze → Silver | Apache Hop |
| 05_dim_distances | Silver → Gold | Apache Hop |
| Codeunit50210 | Logique BC (upsert, trigger, comptage) | AL |
| Table50200–50205 | Stockage données dans BC | AL |
| Page50211 | Dashboard de supervision | AL |

---

## 2. Cas d'usage

---

### UC-01 — Réception d'un événement GPS

| Champ | Valeur |
|-------|--------|
| **Acteur principal** | Application GPS externe |
| **Déclencheur** | L'application envoie un événement `distance_update` |
| **Précondition** | WF-04B actif et accessible sur le port 5678 |

**Flux principal :**

1. L'application POST vers `http://172.18.0.5:5678/webhook/distance-update` avec le payload JSON
2. n8n valide la présence de `session_id` et `event = "distance_update"`
3. Le nœud "Accumuler Session" lit le fichier `/staging/enrichment/distances_realtime.json`
4. Si la session existe déjà : accumulation des métriques (`total_distance_km += distance_km`, `total_active_seconds += active_seconds`, mise à jour de `max_speed_kmh` si `speed_kmh` supérieur, mise à jour de `last_event_at`, incrément de `event_count`)
5. Si la session est nouvelle : création d'une entrée avec `first_event_at = timestamp`
6. `avg_speed_kmh` est recalculé : `(total_distance_km / total_active_seconds) × 3600`
7. Le fichier de staging est mis à jour
8. Calcul du hash MD5 du fichier
9. Si hash différent du checksum précédent : upload versionnée dans MinIO (`raw/enrichment/distances/YYYY/MM/DD/distances_YYYYMMDD_HHMMSS.json`) + mise à jour du fichier `latest.json`
10. Réponse `200 OK` renvoyée à l'application

**Flux alternatif A — Session inconnue (première occurrence) :**
- Étape 4 : création d'une nouvelle entrée dans `distances_realtime.json` avec `first_event_at = last_event_at = timestamp`

**Flux alternatif B — Hash identique (pas de changement) :**
- Étape 9 : aucun upload MinIO, réponse `200 OK` quand même

**Postcondition :** Le fichier de staging contient la session mise à jour ; MinIO contient une copie versionnée si les données ont changé.

---

### UC-02 — Transformation ETL des distances GPS (Bronze → Gold)

| Champ | Valeur |
|-------|--------|
| **Acteur principal** | Administrateur ETL / Planificateur |
| **Déclencheur** | Exécution manuelle ou planifiée des pipelines Apache Hop |
| **Précondition** | `distances_realtime.json` non vide dans `/staging/enrichment/` |

**Flux principal :**

1. Apache Hop exécute `05_silver_distances.hpl`
2. Le pipeline lit `/staging/enrichment/distances_realtime.json`
3. Chaque session est mappée vers `silver.distance_matrix` (tous les champs en VARCHAR)
4. La table Silver est tronquée et rechargée (TRUNCATE + INSERT)
5. Apache Hop exécute `05_dim_distances.hpl`
6. Le pipeline lit `silver.distance_matrix`
7. Le nœud "Parse types" convertit les champs :
   - `session_date` (VARCHAR) → DATE
   - `total_distance_km`, `total_distance_meters`, `max_speed_kmh`, `avg_speed_kmh` (VARCHAR) → DECIMAL
   - `total_active_seconds`, `event_count` (VARCHAR) → INTEGER
   - `first_event_at`, `last_event_at` (ISO 8601 VARCHAR) → TIMESTAMP
8. Les données typées sont chargées dans `dim_distances` (TRUNCATE + INSERT)

**Postcondition :** `dim_distances` contient toutes les sessions GPS avec les types corrects.

---

### UC-03 — Synchronisation automatique quotidienne Gold → BC

| Champ | Valeur |
|-------|--------|
| **Acteur principal** | Planificateur n8n (cron) |
| **Déclencheur** | Chaque jour à 09h00 (cron `0 9 * * *`) |
| **Précondition** | WF-08 actif ; BC accessible via proxy |

**Flux principal :**

1. Le Schedule Trigger de WF-08 se déclenche à 09h00
2. WF-08 appelle séquentiellement WF-08A → 08B → 08C → 08D → 08E → 08F
3. Chaque sous-workflow :
   a. Ouvre une connexion PostgreSQL Gold
   b. Lit l'intégralité de la table source
   c. Pour chaque enregistrement, effectue un upsert vers BC (voir UC-05)
   d. Ferme la connexion PostgreSQL
   e. Retourne `{ table, total, inserted, updated, errors }`
4. Le nœud Merge collecte les 6 résultats
5. Le nœud "Résumé sync BC" calcule les totaux globaux et détermine le statut (`success` si `errors = 0`, `partial` sinon)
6. Le résumé est loggué dans la console n8n

**Postcondition :** Les 6 tables BC sont à jour avec les données Gold du jour.

---

### UC-04 — Déclenchement manuel depuis le Dashboard BC

| Champ | Valeur |
|-------|--------|
| **Acteur principal** | Utilisateur Business Central |
| **Déclencheur** | Clic sur l'action "Synchroniser tout" dans Page50211 |
| **Précondition** | L'utilisateur a accès à la page ETL BC Dashboard |

**Flux principal :**

1. L'utilisateur ouvre la page "ETL BC Dashboard" (Page50211)
2. Il clique sur l'action "Synchroniser tout"
3. Le codeunit `Codeunit50210.TriggerFullSync()` est appelé
4. BC effectue un POST HTTP vers `http://172.18.0.5:5678/webhook/run-gold-to-bc`
5. n8n répond immédiatement `200 { "status": "sync started" }` (mode `onReceived`)
6. La synchronisation s'exécute en arrière-plan dans n8n
7. Un message de confirmation est affiché à l'utilisateur BC

**Flux alternatif — n8n inaccessible :**
- Étape 4 : le HttpClient BC retourne une erreur réseau
- Un message d'erreur est affiché à l'utilisateur

**Postcondition :** WF-08 est en cours d'exécution en arrière-plan.

---

### UC-05 — Upsert d'un enregistrement vers BC

| Champ | Valeur |
|-------|--------|
| **Acteur principal** | Sous-workflow n8n (08A à 08F) |
| **Déclencheur** | Appelé pour chaque ligne lue depuis PostgreSQL Gold |
| **Précondition** | Connexion proxy 172.18.0.8:3128 disponible |

**Flux principal (clé simple) :**

1. Le sous-workflow envoie POST vers `BASE/companies(COMPANY_ID)/ENTITY` avec le payload JSON
2. Si réponse `201 Created` ou `200 OK` : enregistrement `{ action: 'inserted' }`
3. Si réponse `409 Conflict` ou `422 Unprocessable` : l'entité existe déjà → PATCH vers `ENTITY('keyValue')` avec `If-Match: *`
4. Si PATCH `200 OK` : enregistrement `{ action: 'updated' }`
5. Tout autre code HTTP : enregistrement `{ action: 'error', detail: premiers 200 caractères du corps }`

**Flux principal (clé composite — 08E et 08F) :**

1. POST → 409/422 détecté
2. GET avec filtre OData `$filter=fieldA eq 'valA' and fieldB eq valB&$select=id` pour récupérer le GUID BC
3. Si GUID trouvé : PATCH vers `ENTITY(guid)` avec `If-Match: *`
4. Si GUID non trouvé : erreur enregistrée

**Postcondition :** L'enregistrement est créé ou mis à jour dans BC sans doublons.

---

### UC-06 — Consultation du Dashboard BC

| Champ | Valeur |
|-------|--------|
| **Acteur principal** | Utilisateur Business Central |
| **Déclencheur** | Navigation vers la page "ETL BC Dashboard" |

**Flux principal :**

1. L'utilisateur ouvre Page50211
2. La section "Statistiques" affiche les compteurs en temps réel via `GetRecordCount()`
3. La partie inférieure affiche la liste des sessions de distance (Page50201 en partie)
4. L'utilisateur peut naviguer vers chaque liste détaillée via les actions de navigation
5. Les pages de liste sont en lecture seule (aucune modification possible)

---

## 3. Règles métier

| ID | Règle | Portée |
|----|-------|--------|
| RM-01 | Un `session_id` est unique par session GPS ; il correspond au timestamp Unix en millisecondes du début de session | dim_distances / WF-04B |
| RM-02 | `avg_speed_kmh = (total_distance_km / total_active_seconds) × 3600`. Si `total_active_seconds = 0`, `avg_speed_kmh = 0` | WF-04B |
| RM-03 | Les données de localisation GPS (`latitude`, `longitude`, `accuracy_meters`) ne sont jamais persistées au-delà du traitement en mémoire | WF-04B |
| RM-04 | La synchronisation Gold → BC est idempotente : une deuxième exécution ne crée pas de doublons | WF-08A à 08F |
| RM-05 | `fact_ecommerce_lines` est synchronisé avec une limite de 10 000 lignes par exécution | WF-08F |
| RM-06 | L'ordre de synchronisation est fixe : Customers → Articles → ShipmentHeaders → Distances → ShipmentLines → EcommerceLines. Cet ordre respecte les dépendances référentielles côté BC. | WF-08 |
| RM-07 | Une erreur sur un enregistrement individuel n'interrompt pas la synchronisation des enregistrements suivants | WF-08A à 08F |
| RM-08 | Le statut du résumé est `success` si `errors = 0`, `partial` si `errors > 0` | WF-08 Résumé |

---

## 4. Règles de validation des données

### 4.1 Validation à l'entrée (WF-04B — événement GPS)

| Champ | Règle | Action si invalide |
|-------|-------|--------------------|
| `event` | Doit être `"distance_update"` | Rejet silencieux (réponse 200 sans traitement) |
| `session_id` | Non null, non vide | Rejet avec réponse 400 |
| `distance_km` | Numérique ≥ 0 | Valeur remplacée par 0 |
| `speed_kmh` | Numérique ≥ 0 | Valeur remplacée par 0 |
| `active_seconds` | Entier ≥ 0 | Valeur remplacée par 0 |

### 4.2 Validation à la transformation (Apache Hop — Gold)

| Champ | Règle |
|-------|-------|
| `session_date` | Format `YYYY-MM-DD` ; null si invalide |
| `first_event_at`, `last_event_at` | Format ISO 8601 (`yyyy-MM-dd'T'HH:mm:ss.SSS'Z'` ou sans millisecondes) ; null si invalide |
| `total_distance_km` | DECIMAL(10,4) ; null si non parsable |
| `total_active_seconds` | INTEGER ; null si non parsable |

### 4.3 Validation à l'import BC (WF-08A à 08F)

| Entité | Champ | Transformation appliquée |
|--------|-------|--------------------------|
| Toutes | Chaînes null | Remplacées par `''` (chaîne vide) |
| Toutes | Numériques null | Remplacés par `0` |
| `etlDistances` | `firstEventAt`, `lastEventAt` | `new Date(row.xxx).toISOString()` ou `''` |
| `etlShipmentHeaders` | `shipmentDate` | `.toISOString().split('T')[0]` (format `YYYY-MM-DD`) |
| `etlEcommerceLines` | `invoiceDate` | `.toISOString().split('T')[0]` |

---

## 5. Dictionnaire des données

### 5.1 dim_customers → etlCustomers

| Champ Gold | Champ BC | Type Gold | Type BC | Description |
|------------|----------|-----------|---------|-------------|
| `customer_id` | `customerId` | VARCHAR | Text[50] | Identifiant client (clé primaire) |
| `name` | `name` | VARCHAR | Text[100] | Nom du client |
| `country` | `country` | VARCHAR | Text[50] | Pays |
| `post_code` | `postCode` | VARCHAR | Text[20] | Code postal |
| `location_code` | `locationCode` | VARCHAR | Text[20] | Code magasin/dépôt |
| `currency_code` | `currencyCode` | VARCHAR | Text[10] | Code devise |
| `salesperson_code` | `salespersonCode` | VARCHAR | Text[20] | Code vendeur |
| — | `etlLoadedAt` | — | DateTime | Horodatage de l'import ETL |

### 5.2 dim_articles → etlArticles

| Champ Gold | Champ BC | Type Gold | Type BC | Description |
|------------|----------|-----------|---------|-------------|
| `article_id` | `articleId` | VARCHAR | Text[50] | Référence article (clé primaire) |
| `description` | `description` | VARCHAR | Text[100] | Libellé de l'article |
| `unit_of_measure` | `unitOfMeasure` | VARCHAR | Text[20] | Unité de mesure |
| `type` | `type` | VARCHAR | Text[30] | Type d'article (Inventory, Service…) |
| `item_category` | `itemCategory` | VARCHAR | Text[50] | Catégorie d'article |
| `unit_price` | `unitPrice` | DECIMAL | Decimal | Prix de vente unitaire |
| `unit_cost` | `unitCost` | DECIMAL | Decimal | Coût unitaire |
| `costing_method` | `costingMethod` | VARCHAR | Text[20] | Méthode de valorisation (FIFO, Average…) |
| — | `etlLoadedAt` | — | DateTime | Horodatage de l'import ETL |

### 5.3 dim_shipment_headers → etlShipmentHeaders

| Champ Gold | Champ BC | Type Gold | Type BC | Description |
|------------|----------|-----------|---------|-------------|
| `header_id` | `headerId` | VARCHAR | Text[50] | Identifiant expédition (clé primaire) |
| `customer_id` | `customerId` | VARCHAR | Text[50] | Référence client |
| `order_no` | `orderNo` | VARCHAR | Text[50] | Numéro de commande |
| `shipment_date` | `shipmentDate` | DATE | Text[10] | Date d'expédition (YYYY-MM-DD) |
| `ship_to_city` | `shipToCity` | VARCHAR | Text[50] | Ville de livraison |
| `ship_to_country` | `shipToCountry` | VARCHAR | Text[50] | Pays de livraison |
| — | `etlLoadedAt` | — | DateTime | Horodatage de l'import ETL |

### 5.4 dim_distances → etlDistances

| Champ Gold | Champ BC | Type Gold | Type BC | Description |
|------------|----------|-----------|---------|-------------|
| `session_id` | `sessionId` | VARCHAR(50) | Text[50] | ID de session GPS (clé primaire) |
| `session_date` | `sessionDate` | DATE | Text[10] | Date de la session (YYYY-MM-DD) |
| `total_distance_km` | `totalDistanceKm` | DECIMAL(10,4) | Decimal | Distance totale en kilomètres |
| `total_distance_meters` | `totalDistanceMeters` | DECIMAL(10,2) | Decimal | Distance totale en mètres |
| `max_speed_kmh` | `maxSpeedKmh` | DECIMAL(10,3) | Decimal | Vitesse maximale enregistrée (km/h) |
| `avg_speed_kmh` | `avgSpeedKmh` | DECIMAL(10,3) | Decimal | Vitesse moyenne calculée (km/h) |
| `total_active_seconds` | `totalActiveSeconds` | INTEGER | Integer | Durée totale active en secondes |
| `event_count` | `eventCount` | INTEGER | Integer | Nombre d'événements GPS reçus |
| `first_event_at` | `firstEventAt` | TIMESTAMP | DateTime | Horodatage du premier événement |
| `last_event_at` | `lastEventAt` | DateTime | DateTime | Horodatage du dernier événement |
| — | `etlLoadedAt` | — | DateTime | Horodatage de l'import ETL |

### 5.5 fact_shipment_lines → etlShipmentLines

| Champ Gold | Champ BC | Type Gold | Type BC | Description |
|------------|----------|-----------|---------|-------------|
| `document_no` | `documentNo` | VARCHAR | Text[50] | Numéro de document (PK composée) |
| `line_no` | `lineNo` | INTEGER | Integer | Numéro de ligne (PK composée) |
| `article_id` | `articleId` | VARCHAR | Text[50] | Référence article |
| `quantity` | `quantity` | DECIMAL | Decimal | Quantité expédiée |
| `location_code` | `locationCode` | VARCHAR | Text[20] | Code dépôt source |
| — | `etlLoadedAt` | — | DateTime | Horodatage de l'import ETL |

### 5.6 fact_ecommerce_lines → etlEcommerceLines

| Champ Gold | Champ BC | Type Gold | Type BC | Description |
|------------|----------|-----------|---------|-------------|
| `invoice_no` | `invoiceNo` | VARCHAR | Text[50] | Numéro de facture (PK composée) |
| `line_no` | `lineNo` | INTEGER | Integer | Numéro de ligne (PK composée) |
| `stock_code` | `stockCode` | VARCHAR | Text[50] | Code article e-commerce |
| `description` | `description` | VARCHAR | Text[100] | Description de la ligne |
| `quantity` | `quantity` | DECIMAL | Decimal | Quantité vendue |
| `unit_price` | `unitPrice` | DECIMAL | Decimal | Prix unitaire |
| `total_amount` | `totalAmount` | DECIMAL | Decimal | Montant total de la ligne |
| `customer_id` | `customerId` | VARCHAR | Text[50] | Référence client |
| `country` | `country` | VARCHAR | Text[50] | Pays du client |
| `invoice_date` | `invoiceDate` | DATE | Text[10] | Date de facturation (YYYY-MM-DD) |
| — | `etlLoadedAt` | — | DateTime | Horodatage de l'import ETL |

---

## 6. Gestion des erreurs et cas limites

| Cas | Comportement attendu |
|-----|----------------------|
| Événement GPS avec `session_id` manquant | Rejet, réponse 400, aucun traitement |
| Événement GPS avec `distance_km` négatif | Valeur corrigée à 0 |
| `total_active_seconds = 0` lors du calcul avg_speed | `avg_speed_kmh = 0` (division par zéro évitée) |
| BC retourne 500 lors du POST | Enregistrement en erreur, traitement continue, comptabilisé dans `errors` |
| BC retourne 409 mais GET filtre ne trouve pas le GUID | Enregistrement en erreur avec détail `'record not found for PATCH'` |
| PostgreSQL inaccessible au démarrage du sous-workflow | Exception propagée, sous-workflow en erreur, les suivants continuent |
| `fact_ecommerce_lines` dépasse 10 000 lignes | LIMIT 10 000 appliqué, lignes supplémentaires ignorées pour cette exécution |
| Hash MD5 identique au précédent (données non modifiées) | Pas d'upload MinIO, réponse 200 OK quand même |
| Webhook n8n inaccessible lors du TriggerFullSync BC | HttpClient BC retourne erreur, message affiché à l'utilisateur |

---

## 7. Contraintes d'intégrité

### 7.1 Côté Gold (PostgreSQL)

| Table | Contrainte |
|-------|-----------|
| `dim_distances` | `session_id VARCHAR(50) PRIMARY KEY` |
| `dim_customers` | `customer_id` PK |
| `dim_articles` | `article_id` PK |
| `dim_shipment_headers` | `header_id` PK |
| `fact_shipment_lines` | `(document_no, line_no)` PK composée |
| `fact_ecommerce_lines` | `(invoice_no, line_no)` PK composée |
| `fact_shipment_lines` | FK vers `dim_shipment_headers` supprimée (migration `schema_gold_updates.sql`) |

### 7.2 Côté BC (AL)

| Table AL | Clé primaire | Index secondaire |
|----------|-------------|-----------------|
| `ETLBCShipmentHeader` | `Header Id` | — |
| `ETLBCDistance` | `Session Id` | `ByDate` sur `Session Date` |
| `ETLBCShipmentLine` | `Document No` + `Line No` | — |
| `ETLBCEcommerceLine` | `Invoice No` + `Line No` | — |
| `ETLBCCustomer` | `Customer Id` | — |
| `ETLBCArticle` | `Article Id` | — |

### 7.3 Cohérence transversale

- La synchronisation respecte l'ordre : Customers et Articles doivent exister dans BC avant les entités qui les référencent (ShipmentHeaders, ShipmentLines, EcommerceLines).
- `etlLoadedAt` est horodaté côté n8n (`new Date().toISOString()`) au début de chaque exécution de sous-workflow, garantissant la cohérence temporelle de toutes les lignes d'un même lot.
