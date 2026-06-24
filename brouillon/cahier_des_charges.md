# Cahier des Charges
## Projet ETL Pipeline — Intégration Gold → Business Central

---

| Champ             | Valeur                                              |
|-------------------|-----------------------------------------------------|
| **Projet**        | ETL_Projet_BC — Intégration Data Warehouse → BC     |
| **Version**       | 2.0.0                                               |
| **Date**          | 2026-06-04                                          |
| **Auteur**        | Kodzo Nyanu                                         |
| **Statut**        | En cours de réalisation                             |

---

## Table des matières

1. [Contexte et enjeux](#1-contexte-et-enjeux)
2. [Objectifs du projet](#2-objectifs-du-projet)
3. [Périmètre](#3-périmètre)
4. [Acteurs et parties prenantes](#4-acteurs-et-parties-prenantes)
5. [Exigences fonctionnelles](#5-exigences-fonctionnelles)
6. [Exigences non-fonctionnelles](#6-exigences-non-fonctionnelles)
7. [Contraintes techniques](#7-contraintes-techniques)
8. [Livrables attendus](#8-livrables-attendus)
9. [Glossaire](#9-glossaire)

---

## 1. Contexte et enjeux

### 1.1 Contexte métier

Une entreprise de logistique exploite une flotte de camions de livraison dont les déplacements doivent être suivis quotidiennement. Les données de livraison (clients, articles, expéditions, lignes de commande e-commerce) sont actuellement stockées dans un entrepôt de données PostgreSQL structuré en couches médaillon (Bronze → Silver → Gold), mais ne sont pas encore accessibles depuis le système ERP de l'entreprise, Microsoft Business Central (BC).

Par ailleurs, la mesure des distances parcourues reposait jusqu'ici sur l'API Google Distance Matrix, qui fournit des estimations statiques entre des paires origine/destination. Cette approche ne reflète pas les trajets réels effectués par les chauffeurs.

### 1.2 Problématique

- **Absence de synchronisation** entre l'entrepôt de données Gold et Business Central : les équipes de gestion ne disposent pas des données consolidées dans leur ERP.
- **Données de distance non fiables** : les estimations Google Distance Matrix ne correspondent pas aux kilométrages réels des véhicules.
- **Aucune traçabilité temps réel** des sessions GPS des chauffeurs.

### 1.3 Enjeux

| Enjeu | Impact |
|-------|--------|
| Centralisation des données dans BC | Meilleure prise de décision, traçabilité |
| Remplacement du kilométrage estimé par le réel | Conformité réglementaire, remboursements précis |
| Automatisation de la synchronisation | Réduction des erreurs de saisie manuelle |
| Visibilité temps réel des livraisons | Suivi opérationnel amélioré |

---

## 2. Objectifs du projet

### 2.1 Objectif général

Concevoir et déployer un pipeline ETL permettant la synchronisation automatique des données de l'entrepôt de données Gold (PostgreSQL) vers Microsoft Business Central, en intégrant un système de capture des données GPS en temps réel pour remplacer l'API Google Distance Matrix.

### 2.2 Objectifs spécifiques

| ID | Objectif | Priorité |
|----|----------|----------|
| OBJ-01 | Recevoir et accumuler les événements GPS `distance_update` en temps réel via webhook | Haute |
| OBJ-02 | Transformer les événements GPS bruts en sessions agrégées (Silver → Gold) | Haute |
| OBJ-03 | Synchroniser les 6 tables Gold vers BC via l'API OData | Haute |
| OBJ-04 | Automatiser la synchronisation quotidienne (schedule 09h00) | Haute |
| OBJ-05 | Permettre le déclenchement manuel depuis le Dashboard BC | Moyenne |
| OBJ-06 | Fournir un tableau de bord de supervision dans BC | Moyenne |
| OBJ-07 | Garantir l'idempotence de la synchronisation (upsert sans doublons) | Haute |

---

## 3. Périmètre

### 3.1 Dans le périmètre

- Réception des événements GPS via webhook n8n (WF-04B)
- Pipeline ETL Bronze → Silver → Gold pour les données de distance GPS
- Synchronisation Gold → BC pour les 6 entités suivantes :
  - `dim_customers` → `etlCustomers`
  - `dim_articles` → `etlArticles`
  - `dim_shipment_headers` → `etlShipmentHeaders`
  - `dim_distances` → `etlDistances`
  - `fact_shipment_lines` → `etlShipmentLines`
  - `fact_ecommerce_lines` → `etlEcommerceLines`
- Extension AL Business Central (tables + codeunit + pages)
- Orchestration n8n (WF-08 hybride : webhook + schedule + sous-workflows)

### 3.2 Hors périmètre

- Modification du projet ETL_Projet (pipeline CSV et Google Distance Matrix — conservé intact pour présentation)
- Synchronisation BC → Gold (flux inverse)
- Authentification OAuth2/Azure AD (proxy NTLM suffisant pour l'environnement OnPrem)
- Application mobile GPS (système externe, non développé dans ce projet)

---

## 4. Acteurs et parties prenantes

| Acteur | Rôle | Interactions avec le système |
|--------|------|------------------------------|
| **Application GPS externe** | Système source, envoie les événements `distance_update` | POST `/webhook/distance-update` |
| **n8n (orchestrateur ETL)** | Moteur de workflow, orchestre tous les flux | Réception webhook, exécution sous-workflows |
| **Apache Hop** | Moteur de transformation ETL | Pipelines Silver et Gold pour les distances |
| **PostgreSQL Gold** | Entrepôt de données Gold | Source pour la synchronisation BC |
| **MinIO** | Stockage objet Bronze | Stockage des données brutes GPS |
| **Business Central** | ERP cible | Réception des données via API OData |
| **Utilisateur BC** | Gestionnaire / administrateur | Déclenche la synchro, consulte le dashboard |

---

## 5. Exigences fonctionnelles

### EF-01 — Réception des événements GPS

| Champ | Valeur |
|-------|--------|
| **ID** | EF-01 |
| **Titre** | Réception et accumulation des événements GPS |
| **Description** | Le système doit exposer un endpoint webhook capable de recevoir des événements `distance_update` en JSON, les accumuler par `session_id` dans un fichier de staging, puis les persister dans MinIO. |
| **Entrée** | Événement JSON : `session_id`, `timestamp`, `distance_meters`, `distance_km`, `speed_kmh`, `active_seconds`, `location` |
| **Traitement** | Accumulation incrémentale par session ; calcul `avg_speed_kmh = (total_distance_km / total_active_seconds) × 3600` ; contrôle de doublon par hash MD5 |
| **Sortie** | Fichier `distances_realtime.json` mis à jour ; copie versionnée dans MinIO |
| **Priorité** | Haute |

### EF-02 — Transformation ETL des distances GPS

| Champ | Valeur |
|-------|--------|
| **ID** | EF-02 |
| **Titre** | Pipeline ETL Bronze → Silver → Gold pour les distances |
| **Description** | Les données GPS brutes doivent être transformées en sessions agrégées typées, chargées dans `dim_distances`. |
| **Entrée** | `silver.distance_matrix` (champs VARCHAR) |
| **Traitement** | Parsing des timestamps ISO 8601 ; conversion VARCHAR → DECIMAL/INTEGER/TIMESTAMP |
| **Sortie** | Table `dim_distances` avec `session_id` comme clé primaire |
| **Priorité** | Haute |

### EF-03 — Synchronisation Gold → Business Central

| Champ | Valeur |
|-------|--------|
| **ID** | EF-03 |
| **Titre** | Synchronisation des 6 tables Gold vers BC |
| **Description** | Pour chaque table Gold, le système doit lire toutes les lignes et les pousser vers l'entité BC correspondante via l'API OData. La synchronisation doit être idempotente : POST si inexistant, PATCH si existant (détecté par 409/422). |
| **Entrée** | Tables Gold PostgreSQL |
| **Traitement** | Upsert : POST → 409/422 → PATCH avec `If-Match: *` |
| **Sortie** | Données créées ou mises à jour dans BC ; rapport `{inserted, updated, errors}` |
| **Priorité** | Haute |

### EF-04 — Déclenchement automatique quotidien

| Champ | Valeur |
|-------|--------|
| **ID** | EF-04 |
| **Titre** | Synchronisation planifiée à 09h00 |
| **Description** | Le workflow d'orchestration (WF-08) doit s'exécuter automatiquement chaque jour à 09h00 via un déclencheur planifié (cron `0 9 * * *`). |
| **Priorité** | Haute |

### EF-05 — Déclenchement manuel depuis BC

| Champ | Valeur |
|-------|--------|
| **ID** | EF-05 |
| **Titre** | Bouton "Synchroniser tout" dans le Dashboard BC |
| **Description** | L'utilisateur BC doit pouvoir déclencher manuellement la synchronisation Gold → BC depuis la page Dashboard via une action AL. Le codeunit envoie un POST HTTP vers le webhook n8n `/webhook/run-gold-to-bc`. |
| **Priorité** | Moyenne |

### EF-06 — Tableau de bord BC

| Champ | Valeur |
|-------|--------|
| **ID** | EF-06 |
| **Titre** | Page de supervision dans Business Central |
| **Description** | Une page Dashboard doit afficher les compteurs de records par table, permettre la navigation vers les listes détaillées, et exposer l'action de synchronisation manuelle. |
| **Données affichées** | Nombre d'enregistrements : ShipmentHeaders, Distances, ShipmentLines, EcommerceLines, Customers, Articles |
| **Priorité** | Moyenne |

### EF-07 — Gestion des erreurs de synchronisation

| Champ | Valeur |
|-------|--------|
| **ID** | EF-07 |
| **Titre** | Journalisation et non-interruption en cas d'erreur |
| **Description** | Les erreurs de synchronisation (codes HTTP autres que 200/201/409/422) ne doivent pas interrompre le traitement des autres enregistrements. Elles doivent être comptabilisées et remontées dans le résumé final. |
| **Priorité** | Haute |

---

## 6. Exigences non-fonctionnelles

### 6.1 Performance

| ID | Exigence | Valeur cible |
|----|----------|--------------|
| ENF-01 | Temps de réponse du webhook GPS | < 2 secondes |
| ENF-02 | Durée maximale d'une synchronisation complète (6 tables) | < 30 minutes |
| ENF-03 | Limite de traitement `fact_ecommerce_lines` | 10 000 lignes par exécution |

### 6.2 Disponibilité

| ID | Exigence |
|----|----------|
| ENF-04 | Le webhook GPS doit être disponible 24h/24 pour recevoir les événements |
| ENF-05 | La synchronisation planifiée doit tolérer une indisponibilité temporaire de BC (retry à la prochaine exécution) |

### 6.3 Sécurité

| ID | Exigence |
|----|----------|
| ENF-06 | Toutes les communications vers BC passent par le proxy NTLM (172.18.0.8:3128) |
| ENF-07 | Les credentials PostgreSQL ne sont pas exposés dans les logs |
| ENF-08 | L'ID de la société BC est stocké dans une variable d'environnement n8n (`$vars.BC_COMPANY_ID`) |

### 6.4 Conformité RGPD / LPD

| ID | Exigence |
|----|----------|
| ENF-09 | Les données GPS (latitude, longitude) ne sont **pas** persistées dans Gold — seules les métriques agrégées (distance, vitesse, durée) sont conservées |
| ENF-10 | Les données personnelles (nom client, adresse) doivent être traitées conformément au RGPD |

### 6.5 Maintenabilité

| ID | Exigence |
|----|----------|
| ENF-11 | Chaque table Gold est synchronisée par un sous-workflow dédié et indépendant |
| ENF-12 | Toute la logique BC est centralisée dans le Codeunit50210 — aucune logique dans les tables AL |

---

## 7. Contraintes techniques

| Contrainte | Valeur |
|------------|--------|
| ERP cible | Microsoft Business Central 26.0 OnPrem |
| Langage AL | Runtime 13.0 |
| Base de données | PostgreSQL 15, base `data_warehouse_gold` |
| Stockage objet | MinIO (S3-compatible) |
| Orchestrateur ETL | Apache Hop |
| Orchestrateur workflows | n8n |
| Réseau Docker | `etl_network` — 172.18.0.0/16 |
| Proxy BC | 172.18.0.8:3128 (NTLM) |
| PostgreSQL | 172.18.0.4:5432 |
| n8n | 172.18.0.5:5678 |

---

## 8. Livrables attendus

| Livrable | Description | Format |
|----------|-------------|--------|
| Extension AL | Tables, Codeunit, Pages BC | `.al` / `.app` |
| Workflows n8n | WF-04B (GPS) + WF-08 + 6 sous-workflows | `.json` |
| Pipelines Apache Hop | Silver et Gold pour les distances | `.hpl` |
| Script SQL migration | Mise à jour du schéma Gold | `.sql` |
| Documentation technique | Architecture, flux, dictionnaire | `.md` / PDF |
| Cahier des charges | Ce document | `.md` / PDF |
| Spécifications fonctionnelles | Cas d'usage, règles métier | `.md` / PDF |
| Rapport PDF | Document de synthèse complet | PDF |

---

## 9. Glossaire

| Terme | Définition |
|-------|------------|
| **CDC** | Cahier Des Charges |
| **ETL** | Extract, Transform, Load — processus d'extraction, transformation et chargement de données |
| **Medallion Architecture** | Architecture en couches Bronze (brut) → Silver (nettoyé) → Gold (agrégé/prêt à l'usage) |
| **Business Central (BC)** | ERP Microsoft, cible de la synchronisation |
| **OData** | Open Data Protocol — standard REST utilisé par l'API BC |
| **Upsert** | Opération combinant INSERT (si absent) et UPDATE (si existant) |
| **session_id** | Identifiant unique d'une session GPS — généré par l'application mobile (timestamp Unix en ms) |
| **distance_update** | Type d'événement JSON envoyé par l'application GPS à chaque intervalle de mesure |
| **Gold** | Couche finale du Data Warehouse — données nettoyées, typées et agrégées |
| **sous-workflow** | Workflow n8n autonome déclenché par un workflow parent via `executeWorkflow` |
| **NTLM** | NT LAN Manager — protocole d'authentification Windows utilisé par BC OnPrem |
| **TCO** | Total Cost of Ownership — coût total de possession |
| **ROI** | Return on Investment — retour sur investissement |
