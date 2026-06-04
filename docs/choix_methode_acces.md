# Choix et Justification de la Méthode d'Accès
## Intégration Data Warehouse Gold → Microsoft Business Central

---

| Champ             | Valeur                                              |
|-------------------|-----------------------------------------------------|
| **Projet**        | ETL_Projet_BC — Intégration Data Warehouse → BC     |
| **Version**       | 2.0.0                                               |
| **Date**          | 2026-06-04                                          |
| **Auteur**        | Kodzo Nyanu                                         |
| **Décision**      | API BC / OData (Custom API Pages AL)                |

---

## Table des matières

1. [Contexte de la décision](#1-contexte-de-la-décision)
2. [Méthodes candidates évaluées](#2-méthodes-candidates-évaluées)
3. [Analyse détaillée par méthode](#3-analyse-détaillée-par-méthode)
4. [Tableau comparatif synthétique](#4-tableau-comparatif-synthétique)
5. [Justification du choix retenu](#5-justification-du-choix-retenu)
6. [Conclusion](#6-conclusion)

---

## 1. Contexte de la décision

### 1.1 Besoin à satisfaire

Le projet requiert l'injection **automatisée, récurrente et fiable** de données provenant d'un entrepôt PostgreSQL Gold vers Microsoft Business Central OnPrem 26.0. Les contraintes structurantes sont les suivantes :

- **6 entités** à synchroniser (clients, articles, en-têtes d'expédition, distances GPS, lignes d'expédition, lignes e-commerce)
- **Idempotence obligatoire** : une deuxième exécution ne doit pas créer de doublons
- **Déclenchement hybride** : automatique (cron 09h00) + manuel (bouton Dashboard BC)
- **Environnement OnPrem** isolé : pas d'accès cloud direct, authentification NTLM via proxy interne (172.18.0.8:3128)
- **Volume** : de quelques centaines à 10 000 lignes par entité et par exécution

### 1.2 Méthodes candidates identifiées

Quatre grandes familles de méthodes d'accès à BC ont été identifiées et évaluées :

| # | Méthode | Description courte |
|---|---------|-------------------|
| M1 | **API BC / OData (Custom API Pages AL)** | Pages API développées en AL, exposées via OData REST |
| M2 | **Data Export / RapidStart** | Packages de configuration BC pour import/export de données |
| M3 | **Fichiers plats (CSV / XML)** | Import via XMLport ou traitement par lot BC |
| M4 | **Connecteur tiers** | Middleware commercial (Power Automate, KingswaySoft, Scribe, Celigo) |

---

## 2. Méthodes candidates évaluées

### M1 — API BC / OData (Custom API Pages AL)

L'API BC expose les entités Business Central via le protocole OData v4 (REST/JSON). En AL, il est possible de créer des pages de type `API` (`PageType = API`) qui définissent des endpoints personnalisés accessibles via HTTP. La logique d'import (upsert, validation) est centralisée dans un Codeunit AL.

**Endpoint type :** `GET/POST/PATCH /BC260/api/etlpipeline/warehouse/v1.0/companies(ID)/etlCustomers`

### M2 — Data Export / RapidStart (Packages de configuration)

BC intègre un mécanisme natif appelé **RapidStart Services** permettant d'importer des données via des packages de configuration (fichiers Excel ou XML). Ces packages définissent un mapping entre les colonnes d'un fichier et les champs des tables BC.

**Utilisation typique :** migration initiale de données, import de référentiels statiques.

### M3 — Fichiers plats (CSV / XML via XMLport)

BC propose le mécanisme **XMLport** qui permet de définir des schémas d'import/export de fichiers CSV ou XML. Un objet XMLport AL définit le mapping entre le fichier et la table BC. L'import est déclenché manuellement ou via un traitement par lot (Job Queue).

**Utilisation typique :** échanges EDI, import de données depuis des systèmes legacy.

### M4 — Connecteur tiers (Middleware commercial)

Des solutions tierces comme **Microsoft Power Automate**, **KingswaySoft** (connecteur SSIS pour BC), **Scribe Insight** ou **Celigo** proposent des connecteurs BC clé en main. Ces outils gèrent l'authentification, la pagination OData, la transformation et la gestion des erreurs de manière visuelle/low-code.

**Utilisation typique :** intégrations cloud Dynamics 365, synchronisation CRM/ERP.

---

## 3. Analyse détaillée par méthode

### 3.1 M1 — API BC / OData (Custom API Pages AL)

#### Architecture mise en œuvre

```
n8n (Code node)
    │  HTTP POST/PATCH (JSON)
    │  via proxy NTLM 172.18.0.8:3128
    ▼
BC API Endpoint
/api/etlpipeline/warehouse/v1.0/companies(ID)/etlCustomers
    │
    ▼
PageType = API (Page50204)
    │  Source = Table50204 (ETLBCCustomer)
    ▼
Codeunit50210.UpsertCustomer()
    │  Logique métier centralisée
    ▼
Table50204 (ETLBCCustomer)
```

#### Avantages

| Avantage | Détail |
|----------|--------|
| **Contrôle total** | La logique d'upsert, de validation et de transformation est codée en AL dans le Codeunit — aucune boîte noire |
| **Idempotence native** | Pattern POST → 409/422 → PATCH implémenté explicitement et maîtrisé |
| **Standard OData v4** | Protocole documenté, compatible avec tout client HTTP (n8n, curl, Python, etc.) |
| **Pas de dépendance externe** | Aucune licence tierce, aucun abonnement cloud |
| **Granularité** | Contrôle enregistrement par enregistrement, rapport `{inserted, updated, errors}` |
| **Intégration BC native** | Les données sont directement dans les tables BC, accessibles aux autres modules |
| **Déclenchement programmatique** | Le Codeunit peut appeler le webhook n8n via HttpClient pour orchestrer le flux inverse |

#### Inconvénients

| Inconvénient | Mitigation |
|-------------|------------|
| **Développement AL requis** | Pages API + Codeunit à coder, mais standard et documenté |
| **Performances séquentielles** | Upsert enregistrement par enregistrement (pas de bulk insert natif BC) → mitigé par la limite 10 000 lignes sur fact_ecommerce_lines |
| **Authentification NTLM** | Nécessite un proxy interne — déjà en place (172.18.0.8:3128) |

#### Évaluation

| Critère | Note /5 |
|---------|---------|
| Facilité d'implémentation | 3/5 |
| Contrôle et fiabilité | 5/5 |
| Idempotence | 5/5 |
| Coût | 5/5 |
| Adaptation OnPrem | 5/5 |
| Maintenabilité | 5/5 |
| **Total** | **28/30** |

---

### 3.2 M2 — Data Export / RapidStart (Packages de configuration)

#### Architecture type

```
PostgreSQL Gold
    │  Export CSV/Excel
    ▼
Fichier de package RapidStart (.xlsx / .xml)
    │  Import manuel dans BC
    ▼
BC RapidStart Services
    │  Mapping colonnes → champs BC
    ▼
Tables BC standard
```

#### Avantages

| Avantage | Détail |
|----------|--------|
| **Aucun développement AL** | Interface graphique dans BC pour configurer le mapping |
| **Import en lot** | Toutes les lignes importées en une seule opération |
| **Adapté aux migrations initiales** | Conçu pour peupler BC rapidement lors d'un démarrage |

#### Inconvénients

| Inconvénient | Impact |
|-------------|--------|
| **Manuel par nature** | Requiert qu'un utilisateur déclenche l'import dans l'interface BC |
| **Pas d'automatisation native** | Aucune API REST pour déclencher l'import programmatiquement depuis n8n |
| **Pas d'idempotence** | Pas de gestion native des doublons — risque d'écrasement ou d'erreur sur des données existantes |
| **Adapté à l'initialisation, pas à la synchronisation récurrente** | Non conçu pour des synchros quotidiennes automatisées |
| **Tables BC standards uniquement** | Difficulté à créer des entités Gold personnalisées |
| **Gestion des erreurs limitée** | Rapport d'erreur basique, pas de rollback partiel |

#### Évaluation

| Critère | Note /5 |
|---------|---------|
| Facilité d'implémentation | 4/5 |
| Contrôle et fiabilité | 2/5 |
| Idempotence | 1/5 |
| Coût | 5/5 |
| Adaptation OnPrem | 3/5 |
| Maintenabilité | 2/5 |
| **Total** | **17/30** |

---

### 3.3 M3 — Fichiers plats (CSV / XML via XMLport)

#### Architecture type

```
PostgreSQL Gold
    │  Export CSV (n8n ou script)
    ▼
Fichier CSV déposé sur un partage réseau / SFTP
    │
    ▼
BC Job Queue (traitement par lot)
    │  Lecture fichier via XMLport AL
    ▼
Tables BC personnalisées
```

#### Avantages

| Avantage | Détail |
|----------|--------|
| **Standard BC éprouvé** | XMLport est un mécanisme natif BC stable et documenté |
| **Automatisable via Job Queue** | BC peut planifier l'import automatiquement |
| **Performance** | Import en lot plus rapide que l'upsert enregistrement par enregistrement |

#### Inconvénients

| Inconvénient | Impact |
|-------------|--------|
| **Développement AL requis** | XMLport à définir pour chaque entité |
| **Dépendance à un système de fichiers partagé** | Nécessite un partage réseau accessible par BC et n8n — contrainte d'infrastructure |
| **Idempotence complexe** | Doit être gérée manuellement dans le XMLport (vérifier si l'enregistrement existe avant d'insérer) |
| **Pas de retour HTTP synchrone** | Impossible pour n8n de savoir si l'import a réussi sans interroger BC |
| **Gestion des formats de date/nombre** | Sensible aux paramètres régionaux BC (séparateurs décimaux, formats de date) |
| **Traçabilité limitée** | Moins de visibilité sur les erreurs enregistrement par enregistrement |

#### Évaluation

| Critère | Note /5 |
|---------|---------|
| Facilité d'implémentation | 2/5 |
| Contrôle et fiabilité | 3/5 |
| Idempotence | 2/5 |
| Coût | 5/5 |
| Adaptation OnPrem | 3/5 |
| Maintenabilité | 3/5 |
| **Total** | **18/30** |

---

### 3.4 M4 — Connecteur tiers (Power Automate / KingswaySoft)

#### Architecture type (Power Automate)

```
PostgreSQL Gold
    │  Connexion via connecteur SQL (Power Automate Premium)
    ▼
Power Automate Cloud Flow
    │  Connecteur Dynamics 365 BC
    ▼
BC API Standard (clients, articles…)
```

#### Architecture type (KingswaySoft — SSIS)

```
PostgreSQL Gold
    │  Source SSIS
    ▼
SQL Server Integration Services
    │  KingswaySoft BC Destination Adapter
    ▼
BC OData API
```

#### Avantages

| Avantage | Détail |
|----------|--------|
| **Low-code** | Pas de développement AL pour la partie connecteur |
| **Gestion des erreurs intégrée** | Retry automatique, alertes |
| **Pagination OData gérée** | Transparente pour le développeur |

#### Inconvénients

| Inconvénient | Impact |
|-------------|--------|
| **Coût de licence** | Power Automate Premium ~15 €/utilisateur/mois ; KingswaySoft plusieurs milliers d'euros/an |
| **Dépendance cloud (Power Automate)** | Requiert une connectivité Azure — incompatible avec un environnement OnPrem isolé |
| **Boîte noire** | Logique de transformation cachée dans le connecteur, difficile à déboguer |
| **Pas de contrôle fin** | Upsert selon la logique du connecteur, pas personnalisable |
| **Sur-dimensionné** | Conçu pour des intégrations cloud Dynamics 365, pas pour un ETL OnPrem custom |
| **KingswaySoft nécessite SQL Server** | Infrastructure SSIS non présente dans ce projet |

#### Évaluation

| Critère | Note /5 |
|---------|---------|
| Facilité d'implémentation | 4/5 |
| Contrôle et fiabilité | 3/5 |
| Idempotence | 3/5 |
| Coût | 1/5 |
| Adaptation OnPrem | 1/5 |
| Maintenabilité | 2/5 |
| **Total** | **14/30** |

---

## 4. Tableau comparatif synthétique

| Critère | Poids | M1 — API OData AL | M2 — RapidStart | M3 — Fichiers plats | M4 — Connecteur tiers |
|---------|-------|:-----------------:|:---------------:|:-------------------:|:---------------------:|
| **Automatisation complète** | ★★★★★ | ✅ Native HTTP | ❌ Manuel | ⚠️ Job Queue | ⚠️ Flow planifié |
| **Idempotence (upsert)** | ★★★★★ | ✅ POST→PATCH | ❌ Non géré | ⚠️ Complexe | ⚠️ Selon connecteur |
| **Contrôle de la logique** | ★★★★ | ✅ Total (AL) | ❌ Aucun | ⚠️ Partiel | ❌ Boîte noire |
| **Compatibilité OnPrem isolé** | ★★★★★ | ✅ NTLM proxy | ✅ Local | ✅ Local | ❌ Cloud requis |
| **Rapport d'erreurs détaillé** | ★★★★ | ✅ Par enregistrement | ❌ Basique | ⚠️ Limité | ⚠️ Selon outil |
| **Coût** | ★★★ | ✅ Gratuit | ✅ Gratuit | ✅ Gratuit | ❌ Licence coûteuse |
| **Déclenchement depuis BC** | ★★★ | ✅ HttpClient AL | ❌ Non | ❌ Non | ⚠️ Selon outil |
| **Développement requis** | ★★★ | ⚠️ AL (maîtrisé) | ✅ Aucun | ⚠️ XMLport AL | ✅ Low-code |
| **Entités personnalisées** | ★★★★ | ✅ Tables AL custom | ❌ Tables standard | ⚠️ Tables AL custom | ⚠️ Limité |
| **Maintenabilité** | ★★★★ | ✅ Code centralisé | ❌ Dépend des fichiers | ⚠️ Dispersé | ❌ Dépendance vendeur |
| **Score pondéré /30** | | **28** | **17** | **18** | **14** |

**Légende :** ✅ Satisfait pleinement — ⚠️ Satisfait partiellement — ❌ Ne satisfait pas

---

## 5. Justification du choix retenu

### 5.1 Méthode retenue : API BC / OData avec Custom API Pages AL

La méthode **M1 — API BC / OData** a été retenue avec un score de **28/30**, soit 10 points d'avance sur la deuxième méthode (M3 — fichiers plats, 18/30).

### 5.2 Arguments déterminants

#### Argument 1 — Automatisation et déclenchement programmatique

L'API OData est la seule méthode permettant à n8n de déclencher un import via une simple requête HTTP, **sans intervention humaine**. Le Codeunit BC peut également appeler n8n via HttpClient (bouton Dashboard), créant une **boucle de déclenchement bidirectionnelle** impossible avec les autres méthodes.

#### Argument 2 — Idempotence garantie

La synchronisation étant quotidienne, le même enregistrement sera présenté plusieurs fois à BC au fil des jours. Le pattern `POST → 409/422 → PATCH (If-Match: *)` garantit qu'aucun doublon n'est créé quelle que soit la fréquence d'exécution. Cette propriété est **absente de RapidStart** et **complexe à implémenter avec les XMLport**.

#### Argument 3 — Compatibilité OnPrem sans dépendance cloud

L'environnement de déploiement est un réseau Docker isolé (172.18.0.0/16) avec BC OnPrem. Power Automate requiert une connectivité Azure Active Directory ; KingswaySoft nécessite SQL Server Integration Services. L'API OData BC fonctionne **nativement en HTTP local** via le proxy NTLM existant.

#### Argument 4 — Rapport d'erreurs enregistrement par enregistrement

Chaque sous-workflow retourne `{ table, total, inserted, updated, errors }`. L'orchestrateur WF-08 consolide ces métriques en un résumé global. Aucune autre méthode ne permet cette granularité sans développement supplémentaire.

#### Argument 5 — Coût nul

Aucune licence tierce n'est requise. Le seul coût est le temps de développement AL (Codeunit + tables + pages), qui est par ailleurs valorisé comme livrable du projet.

### 5.3 Pourquoi les alternatives ont été écartées

| Méthode | Raison principale d'exclusion |
|---------|------------------------------|
| **M2 — RapidStart** | Non automatisable ; conçu pour migrations initiales, pas pour synchros récurrentes ; aucune gestion des doublons |
| **M3 — Fichiers plats** | Dépendance à un partage réseau externe ; format CSV sensible aux paramètres régionaux ; idempotence à implémenter manuellement dans chaque XMLport |
| **M4 — Connecteur tiers** | Coût de licence incompatible avec un projet interne ; dépendance cloud incompatible avec l'environnement OnPrem isolé ; perte de contrôle sur la logique d'import |

---

## 6. Conclusion

Le choix de l'**API BC/OData avec Custom API Pages AL** repose sur cinq critères non négociables dans ce projet : automatisation complète, idempotence, compatibilité OnPrem, contrôle de la logique et coût nul. Les alternatives évaluées présentent chacune une ou plusieurs incompatibilités rédhibitoires avec les contraintes du projet (environnement isolé, synchronisation récurrente automatisée, rapport d'erreurs détaillé).

L'architecture retenue — Codeunit centralisé + 6 tables AL + 7 pages + 8 workflows n8n — constitue une solution **maîtrisée de bout en bout**, sans dépendance externe et entièrement documentée.

```
Décision finale : M1 — API BC / OData (Custom API Pages AL)
Score           : 28/30
Alternatives    : M2 (17/30), M3 (18/30), M4 (14/30)
```
