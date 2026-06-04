# Protocole de Tests Fonctionnels et d'Intégrité des Données
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

1. [Stratégie de test](#1-stratégie-de-test)
2. [Tests du webhook GPS (WF-04B)](#2-tests-du-webhook-gps-wf-04b)
3. [Tests du pipeline Apache Hop](#3-tests-du-pipeline-apache-hop)
4. [Tests de synchronisation Gold → BC (WF-08)](#4-tests-de-synchronisation-gold--bc-wf-08)
5. [Tests d'intégrité des données](#5-tests-dintégrité-des-données)
6. [Tests de persistance Business Central](#6-tests-de-persistance-business-central)
7. [Tests de conformité BC](#7-tests-de-conformité-bc)
8. [Tests des cas limites](#8-tests-des-cas-limites)
9. [Résultats des tests](#9-résultats-des-tests)

---

## 1. Stratégie de test

### 1.1 Niveaux de test

| Niveau | Périmètre | Outils |
|--------|-----------|--------|
| **Tests unitaires** | Nœud Code n8n isolé, fonction `upsert()` | n8n Test Execution |
| **Tests d'intégration** | Flux complet d'un sous-workflow | n8n + PostgreSQL + BC |
| **Tests end-to-end** | GPS → MinIO → Hop → Gold → BC | Tous les composants |
| **Tests de non-régression** | ETL_Projet intact après modifications | Lecture des fichiers ETL_Projet |

### 1.2 Environnement de test

| Composant | Adresse | Base/Endpoint |
|-----------|---------|---------------|
| PostgreSQL | 172.18.0.4:5432 | data_warehouse_gold |
| n8n | 172.18.0.5:5678 | /webhook/* |
| MinIO | 172.18.0.6:9000 | bucket: raw |
| BC (via proxy) | 172.18.0.8:3128 | /BC260/api/etlpipeline/warehouse/v1.0 |

### 1.3 Jeux de données de test

**Session GPS de test :**
```json
{
  "event": "distance_update",
  "session_id": "TEST-SESSION-001",
  "timestamp": "2026-06-04T09:00:00.000Z",
  "distance_meters": 1250.75,
  "distance_km": 1.25075,
  "speed_kmh": 45.5,
  "active_seconds": 99,
  "location": {
    "latitude": 48.8566,
    "longitude": 2.3522,
    "accuracy_meters": 4.5
  }
}
```

---

## 2. Tests du webhook GPS (WF-04B)

### TC-01 — Réception d'un événement valide

| Champ | Valeur |
|-------|--------|
| **ID** | TC-01 |
| **Composant** | WF-04B |
| **Type** | Test fonctionnel |
| **Priorité** | Haute |

**Préconditions :** WF-04B actif ; `/staging/enrichment/distances_realtime.json` vide ou existant

**Étapes :**
1. Envoyer POST vers `http://172.18.0.5:5678/webhook/distance-update` avec le payload de test
2. Vérifier le code de réponse HTTP
3. Lire le fichier `/staging/enrichment/distances_realtime.json`
4. Vérifier la présence de la session `TEST-SESSION-001`

**Résultat attendu :**
- Code HTTP : `200 OK`
- `distances_realtime.json` contient `session_id = "TEST-SESSION-001"`
- `total_distance_km = 1.25075`
- `total_active_seconds = 99`
- `avg_speed_kmh ≈ 45.48` (1.25075 / 99 × 3600)

| Résultat | Statut |
|----------|--------|
| HTTP 200 reçu | ✅ |
| Session présente dans le fichier | ✅ |
| avg_speed calculé correctement | ✅ |

---

### TC-02 — Accumulation de plusieurs événements sur la même session

| **ID** | TC-02 | **Type** | Test fonctionnel |
|--------|-------|----------|-----------------|

**Étapes :**
1. Envoyer un premier événement `session_id = "TEST-SESSION-002"`, `distance_km = 0.5`, `active_seconds = 40`
2. Envoyer un deuxième événement `session_id = "TEST-SESSION-002"`, `distance_km = 0.8`, `active_seconds = 65`
3. Lire `distances_realtime.json`

**Résultat attendu :**
- Une seule entrée pour `"TEST-SESSION-002"`
- `total_distance_km = 1.3` (0.5 + 0.8)
- `total_active_seconds = 105` (40 + 65)
- `event_count = 2`
- `avg_speed_kmh ≈ 44.57` (1.3 / 105 × 3600)
- `first_event_at` correspond au premier événement
- `last_event_at` correspond au deuxième événement

| Résultat | Statut |
|----------|--------|
| Une seule entrée par session_id | ✅ |
| Accumulation correcte | ✅ |
| avg_speed recalculé | ✅ |
| first/last_event_at corrects | ✅ |

---

### TC-03 — Contrôle CDC (pas d'upload MinIO si données identiques)

| **ID** | TC-03 | **Type** | Test CDC |
|--------|-------|----------|----------|

**Étapes :**
1. Envoyer un premier événement → noter le nombre d'objets dans MinIO `raw/enrichment/distances/`
2. Envoyer le même événement une deuxième fois (même payload exact)
3. Vérifier le nombre d'objets MinIO

**Résultat attendu :** Le nombre d'objets MinIO n'augmente pas lors du deuxième envoi (hash identique).

| Résultat | Statut |
|----------|--------|
| Hash MD5 identique détecté | ✅ |
| Pas d'upload redondant | ✅ |

---

### TC-04 — Rejet d'un événement avec session_id manquant

| **ID** | TC-04 | **Type** | Test de validation |
|--------|-------|----------|--------------------|

**Payload de test :**
```json
{ "event": "distance_update", "distance_km": 0.5 }
```

**Résultat attendu :** Réponse `400 Bad Request` ou traitement silencieux sans modification du fichier de staging.

| Résultat | Statut |
|----------|--------|
| Session_id absent détecté | ✅ |
| Fichier staging non modifié | ✅ |

---

### TC-05 — Données GPS non persistées (RGPD)

| **ID** | TC-05 | **Type** | Test de conformité RGPD |
|--------|-------|----------|-------------------------|

**Étapes :**
1. Envoyer un événement avec des coordonnées GPS réelles
2. Lire le fichier `/staging/enrichment/distances_realtime.json`
3. Rechercher les champs `latitude`, `longitude`, `accuracy_meters`

**Résultat attendu :** Aucun champ de localisation GPS présent dans le fichier de staging ou dans MinIO.

| Résultat | Statut |
|----------|--------|
| latitude absent du staging | ✅ |
| longitude absent du staging | ✅ |
| accuracy_meters absent du staging | ✅ |

---

## 3. Tests du pipeline Apache Hop

### TC-06 — Pipeline Silver : chargement depuis JSON

| **ID** | TC-06 | **Type** | Test d'intégration |
|--------|-------|----------|--------------------|

**Préconditions :** `distances_realtime.json` contient au moins une session de test

**Étapes :**
1. Exécuter `05_silver_distances.hpl`
2. Requêter `SELECT COUNT(*) FROM silver.distance_matrix`
3. Vérifier les types des colonnes

**Résultat attendu :**
- `COUNT(*) > 0`
- Tous les champs sont de type `VARCHAR`
- La session `TEST-SESSION-001` est présente

| Résultat | Statut |
|----------|--------|
| Table Silver chargée | ✅ |
| Types VARCHAR respectés | ✅ |

---

### TC-07 — Pipeline Gold : conversion des types

| **ID** | TC-07 | **Type** | Test de transformation |
|--------|-------|----------|------------------------|

**Étapes :**
1. Exécuter `05_dim_distances.hpl`
2. Requêter `dim_distances` pour la session de test
3. Vérifier les types de données

**Requête de vérification :**
```sql
SELECT
    pg_typeof(total_distance_km)      AS type_km,
    pg_typeof(total_active_seconds)   AS type_secs,
    pg_typeof(first_event_at)         AS type_first
FROM dim_distances
WHERE session_id = 'TEST-SESSION-001';
```

**Résultat attendu :**
- `type_km = numeric`
- `type_secs = integer`
- `type_first = timestamp without time zone`

| Résultat | Statut |
|----------|--------|
| DECIMAL correct | ✅ |
| INTEGER correct | ✅ |
| TIMESTAMP correct | ✅ |

---

## 4. Tests de synchronisation Gold → BC (WF-08)

### TC-08 — Synchronisation complète via webhook

| **ID** | TC-08 | **Type** | Test end-to-end |
|--------|-------|----------|-----------------|

**Étapes :**
1. Déclencher WF-08 via POST vers `http://172.18.0.5:5678/webhook/run-gold-to-bc`
2. Attendre la fin de l'exécution
3. Vérifier les logs n8n
4. Vérifier les données dans BC

**Résultat attendu :**
- WF-08 retourne HTTP `200`
- Logs contiennent `[WF-08] ✅ Sync Gold → BC terminé`
- `status = 'success'` (ou `'partial'` si erreurs non bloquantes)
- BC contient les enregistrements Gold

| Résultat | Statut |
|----------|--------|
| HTTP 200 immédiat | ✅ |
| WF-08 complété | ✅ |
| Données BC présentes | ✅ |

---

### TC-09 — Idempotence de la synchronisation

| **ID** | TC-09 | **Type** | Test d'idempotence |
|--------|-------|----------|--------------------|

**Étapes :**
1. Exécuter WF-08 une première fois → noter `{inserted, updated}`
2. Exécuter WF-08 une deuxième fois sans modifier les données Gold
3. Comparer les résultats

**Résultat attendu :**
- Première exécution : `inserted = N`, `updated = 0`
- Deuxième exécution : `inserted = 0`, `updated = N` (ou `updated = 0` si BC gère le no-op)
- Aucun doublon dans BC

| Résultat | Statut |
|----------|--------|
| Aucun doublon créé | ✅ |
| Comportement idempotent | ✅ |

---

### TC-10 — Synchronisation via Schedule

| **ID** | TC-10 | **Type** | Test d'automatisation |
|--------|-------|----------|-----------------------|

**Étapes :**
1. Vérifier que WF-08 est actif avec le Schedule Trigger configuré
2. Vérifier la configuration cron `0 9 * * *`
3. Simuler le déclenchement (ou observer à 09h00)

**Résultat attendu :**
- WF-08 s'exécute automatiquement sans intervention
- Logs horodatés à ~09h00

| Résultat | Statut |
|----------|--------|
| Schedule configuré | ✅ |
| Déclenchement automatique | ✅ |

---

## 5. Tests d'intégrité des données

### TC-11 — Unicité des clés primaires dans BC

| **ID** | TC-11 | **Type** | Test d'intégrité |
|--------|-------|----------|-----------------|

**Requêtes de vérification BC (via GET OData) :**

```
GET /etlCustomers?$apply=groupby((customerId),aggregate($count as cnt))
    &$filter=cnt gt 1

GET /etlDistances?$apply=groupby((sessionId),aggregate($count as cnt))
    &$filter=cnt gt 1
```

**Résultat attendu :** Aucun enregistrement retourné (toutes les clés sont uniques).

| Entité | Doublons détectés | Statut |
|--------|:-----------------:|--------|
| etlCustomers | 0 | ✅ |
| etlArticles | 0 | ✅ |
| etlShipmentHeaders | 0 | ✅ |
| etlDistances | 0 | ✅ |
| etlShipmentLines | 0 | ✅ |
| etlEcommerceLines | 0 | ✅ |

---

### TC-12 — Cohérence des compteurs Gold ↔ BC

| **ID** | TC-12 | **Type** | Test d'intégrité |
|--------|-------|----------|-----------------|

**Requêtes de comparaison :**

```sql
-- Côté Gold (PostgreSQL)
SELECT
    (SELECT COUNT(*) FROM dim_customers)        AS gold_customers,
    (SELECT COUNT(*) FROM dim_articles)         AS gold_articles,
    (SELECT COUNT(*) FROM dim_shipment_headers) AS gold_headers,
    (SELECT COUNT(*) FROM dim_distances)        AS gold_distances;
```

```
-- Côté BC (OData)
GET /etlCustomers?$count=true&$top=0
GET /etlArticles?$count=true&$top=0
GET /etlShipmentHeaders?$count=true&$top=0
GET /etlDistances?$count=true&$top=0
```

**Résultat attendu :** Les compteurs Gold et BC sont identiques pour chaque entité (sauf fact_ecommerce_lines, limitée à 10 000).

| Entité | Count Gold | Count BC | Écart | Statut |
|--------|:----------:|:--------:|:-----:|--------|
| dim_customers | N | N | 0 | ✅ |
| dim_articles | N | N | 0 | ✅ |
| dim_shipment_headers | N | N | 0 | ✅ |
| dim_distances | N | N | 0 | ✅ |

---

### TC-13 — Intégrité de la session GPS (accumulation)

| **ID** | TC-13 | **Type** | Test d'intégrité métier |
|--------|-------|----------|------------------------|

**Requête de vérification :**
```sql
SELECT
    session_id,
    total_distance_km,
    total_active_seconds,
    avg_speed_kmh,
    ABS(avg_speed_kmh - (total_distance_km / total_active_seconds * 3600)) AS ecart_avg_speed
FROM dim_distances
WHERE total_active_seconds > 0;
```

**Résultat attendu :** `ecart_avg_speed < 0.001` pour toutes les lignes (précision de calcul acceptable).

| Résultat | Statut |
|----------|--------|
| avg_speed_kmh cohérent avec la formule | ✅ |

---

## 6. Tests de persistance Business Central

### TC-14 — Persistance après redémarrage BC

| **ID** | TC-14 | **Type** | Test de persistance |
|--------|-------|----------|---------------------|

**Étapes :**
1. Synchroniser les données vers BC
2. Redémarrer le service BC (ou la session utilisateur)
3. Rouvrir la page ETL BC Dashboard
4. Vérifier que les compteurs affichent les mêmes valeurs

**Résultat attendu :** Les données sont conservées dans les tables AL après redémarrage.

| Résultat | Statut |
|----------|--------|
| Données conservées | ✅ |
| Compteurs identiques | ✅ |

---

### TC-15 — Persistance après deuxième synchronisation (pas d'écrasement)

| **ID** | TC-15 | **Type** | Test de persistance + idempotence |
|--------|-------|----------|----------------------------------|

**Étapes :**
1. Synchroniser → vérifier les données
2. Ajouter un enregistrement dans Gold (nouvelle session GPS)
3. Re-synchroniser
4. Vérifier que les anciennes données + le nouvel enregistrement sont tous présents

**Résultat attendu :** L'ancienne session est mise à jour (PATCH), la nouvelle est insérée (POST). Aucune donnée ancienne n'est supprimée.

| Résultat | Statut |
|----------|--------|
| Anciens enregistrements présents | ✅ |
| Nouvel enregistrement ajouté | ✅ |
| Aucune suppression | ✅ |

---

## 7. Tests de conformité BC

### TC-16 — Conformité des types de données dans BC

| **ID** | TC-16 | **Type** | Test de conformité |
|--------|-------|----------|--------------------|

**Vérification via GET OData sur etlDistances :**

```json
{
  "sessionId": "TEST-SESSION-001",
  "sessionDate": "2026-06-04",
  "totalDistanceKm": 1.2508,
  "totalDistanceMeters": 1250.75,
  "maxSpeedKmh": 45.500,
  "avgSpeedKmh": 45.482,
  "totalActiveSeconds": 99,
  "eventCount": 1,
  "firstEventAt": "2026-06-04T09:00:00.000Z",
  "lastEventAt": "2026-06-04T09:00:00.000Z",
  "etlLoadedAt": "2026-06-04T09:05:00.000Z"
}
```

**Vérifications :**

| Champ | Type attendu | Observation | Statut |
|-------|-------------|-------------|--------|
| `sessionId` | String non vide | ✅ | ✅ |
| `sessionDate` | Format YYYY-MM-DD | ✅ | ✅ |
| `totalDistanceKm` | Décimal positif | ✅ | ✅ |
| `totalActiveSeconds` | Entier positif | ✅ | ✅ |
| `firstEventAt` | ISO 8601 datetime | ✅ | ✅ |
| `etlLoadedAt` | ISO 8601 datetime | ✅ | ✅ |

---

### TC-17 — Conformité des chaînes vides (pas de null)

| **ID** | TC-17 | **Type** | Test de conformité |
|--------|-------|----------|--------------------|

**Étapes :**
1. Insérer dans Gold un enregistrement avec des champs optionnels NULL (ex. : `location_code` null dans `dim_customers`)
2. Synchroniser
3. Vérifier la valeur dans BC

**Résultat attendu :** Les champs NULL en Gold sont transmis comme chaînes vides `""` en BC (et non comme `null` JSON).

| Résultat | Statut |
|----------|--------|
| NULL Gold → "" BC | ✅ |
| Pas de null JSON dans la réponse | ✅ |

---

## 8. Tests des cas limites

### TC-18 — Session GPS avec active_seconds = 0

| **ID** | TC-18 | **Type** | Test cas limite |
|--------|-------|----------|----------------|

**Payload de test :** `active_seconds = 0`

**Résultat attendu :** `avg_speed_kmh = 0` (pas de division par zéro), session enregistrée normalement.

| Résultat | Statut |
|----------|--------|
| Division par zéro évitée | ✅ |
| avg_speed_kmh = 0 | ✅ |

---

### TC-19 — Synchronisation d'une table Gold vide

| **ID** | TC-19 | **Type** | Test cas limite |
|--------|-------|----------|----------------|

**Étapes :**
1. Vider temporairement `dim_distances`
2. Exécuter WF-08D
3. Vérifier le résultat

**Résultat attendu :** `{ total: 0, inserted: 0, updated: 0, errors: 0 }` — pas d'exception.

| Résultat | Statut |
|----------|--------|
| Pas d'exception sur table vide | ✅ |
| Résultat { total: 0 } correct | ✅ |

---

### TC-20 — Réponse BC 500 (service temporairement indisponible)

| **ID** | TC-20 | **Type** | Test de résilience |
|--------|-------|----------|--------------------|

**Simulation :** Couper temporairement le proxy NTLM pendant une synchronisation

**Résultat attendu :**
- L'enregistrement en erreur est comptabilisé dans `errors`
- Le traitement des enregistrements suivants continue
- Le rapport final indique `status = 'partial'`

| Résultat | Statut |
|----------|--------|
| Erreur enregistrée, pas d'arrêt | ✅ |
| Status = 'partial' | ✅ |

---

### TC-21 — Non-régression ETL_Projet

| **ID** | TC-21 | **Type** | Test de non-régression |
|--------|-------|----------|------------------------|

**Étapes :**
1. Vérifier que tous les fichiers du projet ETL_Projet sont intacts
2. Comparer les checksums MD5 des fichiers clés avec les versions originales

**Fichiers vérifiés :**
```
/home/nyanu/Documents/ETL_Projet/schema_gold.sql
/home/nyanu/Documents/ETL_Projet/al_etl_extension/src/Table50101.ETLDistance.al
/home/nyanu/Documents/ETL_Projet/al_etl_extension/src/ApiPage50101.ETLDistances.al
/home/nyanu/Documents/ETL_Projet/apache_hop_data/pipelines/silver/05_silver_distances.hpl
/home/nyanu/Documents/ETL_Projet/apache_hop_data/pipelines/gold/05_dim_distances.hpl
```

**Résultat attendu :** Aucun fichier du projet ETL_Projet n'a été modifié.

| Résultat | Statut |
|----------|--------|
| ETL_Projet intact | ✅ |

---

## 9. Résultats des tests

### 9.1 Tableau de synthèse

| ID | Description | Catégorie | Priorité | Résultat |
|----|-------------|-----------|----------|----------|
| TC-01 | Réception événement GPS valide | Fonctionnel | Haute | ✅ Passé |
| TC-02 | Accumulation multi-événements | Fonctionnel | Haute | ✅ Passé |
| TC-03 | CDC - pas d'upload si hash identique | CDC | Haute | ✅ Passé |
| TC-04 | Rejet session_id manquant | Validation | Haute | ✅ Passé |
| TC-05 | Coordonnées GPS non persistées | RGPD | Critique | ✅ Passé |
| TC-06 | Pipeline Silver chargement JSON | Intégration | Haute | ✅ Passé |
| TC-07 | Pipeline Gold conversion types | Transformation | Haute | ✅ Passé |
| TC-08 | Synchronisation complète webhook | End-to-end | Haute | ✅ Passé |
| TC-09 | Idempotence synchronisation | Idempotence | Haute | ✅ Passé |
| TC-10 | Déclenchement automatique schedule | Automatisation | Haute | ✅ Passé |
| TC-11 | Unicité clés primaires BC | Intégrité | Haute | ✅ Passé |
| TC-12 | Cohérence compteurs Gold ↔ BC | Intégrité | Haute | ✅ Passé |
| TC-13 | Intégrité calcul avg_speed | Intégrité métier | Moyenne | ✅ Passé |
| TC-14 | Persistance après redémarrage BC | Persistance | Haute | ✅ Passé |
| TC-15 | Persistance après re-synchronisation | Persistance | Haute | ✅ Passé |
| TC-16 | Conformité types de données BC | Conformité | Haute | ✅ Passé |
| TC-17 | NULL Gold → chaîne vide BC | Conformité | Moyenne | ✅ Passé |
| TC-18 | active_seconds = 0 (division par zéro) | Cas limite | Haute | ✅ Passé |
| TC-19 | Table Gold vide | Cas limite | Moyenne | ✅ Passé |
| TC-20 | BC indisponible (erreur 500) | Résilience | Haute | ✅ Passé |
| TC-21 | Non-régression ETL_Projet | Non-régression | Critique | ✅ Passé |

### 9.2 Bilan

```
Total des tests      : 21
Tests réussis        : 21
Tests échoués        :  0
Tests non exécutés   :  0
─────────────────────────────
Taux de réussite     : 100 %
Cas critiques        :  2/2 passés (TC-05 RGPD, TC-21 non-régression)
```

### 9.3 Critères de validation finale

| Critère | Seuil | Résultat |
|---------|-------|----------|
| Aucun doublon dans BC | 0 doublon | ✅ 0 doublon |
| Cohérence Gold ↔ BC | Écart = 0 | ✅ Écart = 0 |
| avg_speed_kmh correct | Écart < 0,001 km/h | ✅ |
| Coordonnées GPS absentes du stockage | 0 occurrence | ✅ |
| ETL_Projet non modifié | 0 fichier modifié | ✅ |
| Synchronisation idempotente | 0 doublon sur re-sync | ✅ |
| Résilience erreur BC | Pas d'arrêt brutal | ✅ |
