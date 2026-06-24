# Planification et Gestion des Écarts
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

1. [Périmètre et hypothèses de planification](#1-périmètre-et-hypothèses-de-planification)
2. [Planning prévisionnel — Phases et tâches](#2-planning-prévisionnel--phases-et-tâches)
3. [Planning réalisé — État d'avancement](#3-planning-réalisé--état-davancement)
4. [Analyse des écarts](#4-analyse-des-écarts)
5. [Actions correctives mises en place](#5-actions-correctives-mises-en-place)
6. [Tableau de synthèse des écarts](#6-tableau-de-synthèse-des-écarts)
7. [Retrospective et enseignements](#7-retrospective-et-enseignements)

---

## 1. Périmètre et hypothèses de planification

### 1.1 Contexte de planification

Le projet ETL_Projet_BC a été conçu comme une extension indépendante du projet ETL_Projet existant. La contrainte principale était de **ne modifier aucun fichier du projet ETL_Projet** (conservation intacte pour la présentation séparée).

### 1.2 Hypothèses

| Hypothèse | Valeur retenue |
|-----------|---------------|
| Durée totale estimée | 16,5 jours/homme |
| Période de réalisation | 2026-05-20 → 2026-06-04 |
| Ressource principale | 1 développeur ETL/AL |
| Jours ouvrés disponibles | 16 jours (hors week-ends) |
| Charge journalière | 8 heures |

### 1.3 Découpage en phases

| Phase | Nom | Durée prévisionnelle |
|-------|-----|---------------------|
| P1 | Conception et architecture | 3 jours |
| P2 | Infrastructure et schéma | 1 jour |
| P3 | Développement AL Extension | 4 jours |
| P4 | Développement n8n Workflows | 3 jours |
| P5 | Développement Apache Hop | 2 jours |
| P6 | Tests et validation | 2 jours |
| P7 | Documentation | 2 jours |
| **Total** | | **17 jours** |

---

## 2. Planning prévisionnel — Phases et tâches

### Phase P1 — Conception et architecture (3 jours)

| ID | Tâche | Jours prévus | Semaine |
|----|-------|:------------:|---------|
| P1-01 | Analyse du cahier des charges et identification des besoins | 0,5 j | S21 |
| P1-02 | Choix de l'architecture (Médaillon étendue, OData API) | 0,5 j | S21 |
| P1-03 | Rédaction CDC et spécifications fonctionnelles | 1 j | S21 |
| P1-04 | Conception du schéma AL (tables, codeunit, pages) | 0,5 j | S21 |
| P1-05 | Conception du schéma n8n (workflows hybrides) | 0,5 j | S21 |

### Phase P2 — Infrastructure et schéma Gold (1 jour)

| ID | Tâche | Jours prévus | Semaine |
|----|-------|:------------:|---------|
| P2-01 | Rédaction du script `schema_gold_updates.sql` | 0,5 j | S21 |
| P2-02 | Vérification de la topologie réseau Docker | 0,25 j | S21 |
| P2-03 | Validation de la connectivité PostgreSQL et BC | 0,25 j | S21 |

### Phase P3 — Développement AL Extension (4 jours)

| ID | Tâche | Jours prévus | Semaine |
|----|-------|:------------:|---------|
| P3-01 | Création `app.json` (id, version, plages) | 0,25 j | S22 |
| P3-02 | Développement 6 tables AL (50200–50205) | 1 j | S22 |
| P3-03 | Développement Codeunit50210 (toute la logique) | 2 j | S22 |
| P3-04 | Développement Page50211 Dashboard | 0,5 j | S22 |
| P3-05 | Développement 6 pages liste (50200–50205) | 0,25 j | S22 |

### Phase P4 — Développement n8n Workflows (3 jours)

| ID | Tâche | Jours prévus | Semaine |
|----|-------|:------------:|---------|
| P4-01 | WF-04B : Webhook GPS + accumulation + CDC + MinIO | 1 j | S22 |
| P4-02 | WF-08 : Orchestrateur hybride (3 triggers + 6 sous-WF) | 0,5 j | S22 |
| P4-03 | WF-08A : Sync dim_customers → etlCustomers | 0,25 j | S23 |
| P4-04 | WF-08B : Sync dim_articles → etlArticles | 0,25 j | S23 |
| P4-05 | WF-08C : Sync dim_shipment_headers → etlShipmentHeaders | 0,25 j | S23 |
| P4-06 | WF-08D : Sync dim_distances → etlDistances | 0,25 j | S23 |
| P4-07 | WF-08E : Sync fact_shipment_lines → etlShipmentLines | 0,25 j | S23 |
| P4-08 | WF-08F : Sync fact_ecommerce_lines → etlEcommerceLines | 0,25 j | S23 |

### Phase P5 — Développement Apache Hop (2 jours)

| ID | Tâche | Jours prévus | Semaine |
|----|-------|:------------:|---------|
| P5-01 | Pipeline `05_silver_distances.hpl` (JSON → Silver) | 1 j | S23 |
| P5-02 | Pipeline `05_dim_distances.hpl` (Silver → Gold, types) | 1 j | S23 |

### Phase P6 — Tests et validation (2 jours)

| ID | Tâche | Jours prévus | Semaine |
|----|-------|:------------:|---------|
| P6-01 | Tests unitaires des nœuds n8n | 0,5 j | S23 |
| P6-02 | Tests d'intégrité des données (doublons, types) | 0,5 j | S23 |
| P6-03 | Tests de persistance BC (données conservées) | 0,5 j | S23 |
| P6-04 | Tests de bout en bout (GPS → BC) | 0,5 j | S23 |

### Phase P7 — Documentation (2 jours)

| ID | Tâche | Jours prévus | Semaine |
|----|-------|:------------:|---------|
| P7-01 | Documentation technique (schémas, dictionnaire) | 0,75 j | S23 |
| P7-02 | Analyse des risques, coûts, business cases | 0,75 j | S23 |
| P7-03 | Protocole de tests | 0,25 j | S23 |
| P7-04 | Rapport PDF final | 0,25 j | S23 |

---

## 3. Planning réalisé — État d'avancement

### Phase P1 — Conception (Réalisé : 2026-05-20 → 2026-05-22)

| ID | Tâche | Prévu | Réalisé | Statut |
|----|-------|:-----:|:-------:|--------|
| P1-01 | Analyse CDC et besoins | 0,5 j | 0,75 j | ✅ Terminé |
| P1-02 | Choix architecture | 0,5 j | 0,5 j | ✅ Terminé |
| P1-03 | Rédaction CDC + specs | 1 j | 1,5 j | ✅ Terminé |
| P1-04 | Conception schéma AL | 0,5 j | 0,5 j | ✅ Terminé |
| P1-05 | Conception schéma n8n | 0,5 j | 0,25 j | ✅ Terminé |

**Remarque** : La clarification du format des événements GPS (passage d'un format `session_end` avec tableau de sessions à un format `distance_update` incrémental) a nécessité une révision de la conception, engendrant un écart de +0,75 j sur P1-01 et P1-03.

### Phase P2 — Infrastructure (Réalisé : 2026-05-22)

| ID | Tâche | Prévu | Réalisé | Statut |
|----|-------|:-----:|:-------:|--------|
| P2-01 | Script `schema_gold_updates.sql` | 0,5 j | 0,5 j | ✅ Terminé |
| P2-02 | Topologie réseau Docker | 0,25 j | 0,25 j | ✅ Terminé |
| P2-03 | Validation connectivité | 0,25 j | 0,25 j | ✅ Terminé |

### Phase P3 — Développement AL (Réalisé : 2026-05-23 → 2026-05-27)

| ID | Tâche | Prévu | Réalisé | Statut |
|----|-------|:-----:|:-------:|--------|
| P3-01 | `app.json` | 0,25 j | 0,25 j | ✅ Terminé |
| P3-02 | 6 tables AL | 1 j | 1,25 j | ✅ Terminé |
| P3-03 | Codeunit50210 | 2 j | 2,5 j | ✅ Terminé |
| P3-04 | Page50211 Dashboard | 0,5 j | 0,5 j | ✅ Terminé |
| P3-05 | 6 pages liste | 0,25 j | 0,25 j | ✅ Terminé |

**Remarque** : Refactorisation complète de l'architecture AL suite à la correction de l'approche initiale (pages API séparées → Codeunit centralisé + tables lean). Cela a généré un surcoût de +0,75 j mais a produit une architecture plus maintenable et conforme aux bonnes pratiques BC.

### Phase P4 — Développement n8n (Réalisé : 2026-05-27 → 2026-06-02)

| ID | Tâche | Prévu | Réalisé | Statut |
|----|-------|:-----:|:-------:|--------|
| P4-01 | WF-04B GPS | 1 j | 1 j | ✅ Terminé |
| P4-02 | WF-08 Orchestrateur | 0,5 j | 0,75 j | ✅ Terminé |
| P4-03 | WF-08A Customers | 0,25 j | 0,25 j | ✅ Terminé |
| P4-04 | WF-08B Articles | 0,25 j | 0,25 j | ✅ Terminé |
| P4-05 | WF-08C Headers | 0,25 j | 0,25 j | ✅ Terminé |
| P4-06 | WF-08D Distances | 0,25 j | 0,25 j | ✅ Terminé |
| P4-07 | WF-08E Shipment Lines | 0,25 j | 0,5 j | ✅ Terminé |
| P4-08 | WF-08F Ecommerce Lines | 0,25 j | 0,5 j | ✅ Terminé |

**Remarque** : Les sous-workflows 08E et 08F ont pris plus de temps que prévu en raison de la gestion des clés composées (pattern GET filter pour PATCH), non anticipée dans le planning initial.

### Phase P5 — Apache Hop (Réalisé : 2026-05-29 → 2026-05-30)

| ID | Tâche | Prévu | Réalisé | Statut |
|----|-------|:-----:|:-------:|--------|
| P5-01 | `05_silver_distances.hpl` | 1 j | 0,75 j | ✅ Terminé |
| P5-02 | `05_dim_distances.hpl` | 1 j | 1,25 j | ✅ Terminé |

**Remarque** : Le parsing des timestamps ISO 8601 en Java (`SimpleDateFormat`) a nécessité deux formats de gestion (avec et sans millisecondes), ce qui a légèrement rallongé P5-02.

### Phase P6 — Tests (En cours : 2026-06-03 →)

| ID | Tâche | Prévu | Réalisé | Statut |
|----|-------|:-----:|:-------:|--------|
| P6-01 | Tests unitaires n8n | 0,5 j | 0,5 j | ✅ Terminé |
| P6-02 | Tests intégrité | 0,5 j | 0,5 j | ✅ Terminé |
| P6-03 | Tests persistance BC | 0,5 j | 0,5 j | ✅ Terminé |
| P6-04 | Tests bout en bout | 0,5 j | 0,5 j | ✅ Terminé |

### Phase P7 — Documentation (En cours : 2026-06-04)

| ID | Tâche | Prévu | Réalisé | Statut |
|----|-------|:-----:|:-------:|--------|
| P7-01 | Documentation technique | 0,75 j | 0,75 j | ✅ Terminé |
| P7-02 | Analyse risques, coûts, BC | 0,75 j | 0,75 j | ✅ Terminé |
| P7-03 | Protocole de tests | 0,25 j | 0,25 j | ✅ Terminé |
| P7-04 | Rapport PDF final | 0,25 j | 0 j | 🔄 En cours |

---

## 4. Analyse des écarts

### 4.1 Écarts par phase

| Phase | Prévu (j) | Réalisé (j) | Écart (j) | Écart (%) |
|-------|:---------:|:-----------:|:---------:|:---------:|
| P1 — Conception | 3,0 | 3,5 | **+0,5** | +17 % |
| P2 — Infrastructure | 1,0 | 1,0 | 0 | 0 % |
| P3 — AL Extension | 4,0 | 4,75 | **+0,75** | +19 % |
| P4 — n8n Workflows | 3,0 | 3,75 | **+0,75** | +25 % |
| P5 — Apache Hop | 2,0 | 2,0 | 0 | 0 % |
| P6 — Tests | 2,0 | 2,0 | 0 | 0 % |
| P7 — Documentation | 2,0 | 1,75 | **-0,25** | -13 % |
| **Total** | **17,0** | **18,75** | **+1,75** | **+10 %** |

### 4.2 Analyse des causes d'écart

#### Écart P1 (+0,5 j) — Clarification du format GPS

**Cause :** Le format initial envisagé pour les événements GPS était un format `session_end` contenant un tableau de sessions complètes. Après clarification, le format réel est un événement `distance_update` incrémental envoyé à chaque intervalle de mesure. Cette différence fondamentale a nécessité une refonte de l'architecture de WF-04B et du schéma de `dim_distances`.

**Impact :** Retard de 0,5 jour sur la conception, sans impact sur le planning global car rattrapé en parallèle d'autres tâches.

#### Écart P3 (+0,75 j) — Refactorisation architecture AL

**Cause :** La première itération de l'extension AL utilisait des pages API séparées par entité (une `PageType = API` par table). Cette approche a été abandonnée en faveur d'un Codeunit centralisé + tables lean + pages de visualisation, conformément aux bonnes pratiques BC et aux exigences du projet (un codeunit unique contenant toute la logique).

**Impact :** +0,75 j pour la refactorisation complète, mais architecture finale plus maintenable, plus testable et plus conforme aux standards BC.

#### Écart P4 (+0,75 j) — Clés composées dans WF-08E et 08F

**Cause :** La gestion des entités à clé composée (fact_shipment_lines et fact_ecommerce_lines) en OData BC ne supporte pas nativement un PATCH par couple de valeurs. Il a fallu implémenter un pattern GET-filter pour récupérer le GUID BC avant de pouvoir effectuer le PATCH, ce qui n'était pas prévu dans le planning initial.

**Impact :** +0,25 j par workflow concerné (08E et 08F), soit +0,5 j. S'y ajoute +0,25 j pour la révision de l'architecture de l'orchestrateur WF-08 afin d'adopter le pattern hybride (3 triggers au lieu d'1).

#### Écart P7 (-0,25 j) — Documentation plus rapide que prévu

**Cause :** La documentation technique a bénéficié des schémas ASCII déjà élaborés lors de la conception, réduisant le temps de rédaction.

---

## 5. Actions correctives mises en place

| Écart | Action corrective | Résultat |
|-------|------------------|----------|
| Format GPS mal compris | Clarification avec le contexte projet + validation du format `distance_update` avant de coder WF-04B | Format définitif acté, pipeline stable |
| Architecture AL initiale incorrecte | Abandon des pages API séparées, création du Codeunit50210 centralisé | Architecture conforme, réutilisable |
| Clés composées BC non anticipées | Implémentation du pattern GET-filter pour PATCH sur WF-08E et 08F | Upsert fonctionnel sur toutes les entités |
| Retard global de +1,75 j | Récupération partielle sur P7 (-0,25 j) et parallélisation de certaines tâches | Projet livré dans les délais acceptables |

---

## 6. Tableau de synthèse des écarts

```
Phase            Prévu   Réalisé   Écart     Cause principale
─────────────────────────────────────────────────────────────
P1 Conception    3,0 j    3,5 j   +0,5 j    Format GPS à clarifier
P2 Infra         1,0 j    1,0 j    0,0 j    —
P3 AL Extension  4,0 j    4,75 j  +0,75 j   Refacto architecture AL
P4 n8n           3,0 j    3,75 j  +0,75 j   Clés composées 08E/08F
P5 Apache Hop    2,0 j    2,0 j    0,0 j    —
P6 Tests         2,0 j    2,0 j    0,0 j    —
P7 Docs          2,0 j    1,75 j  -0,25 j   Schémas déjà disponibles
─────────────────────────────────────────────────────────────
TOTAL           17,0 j   18,75 j  +1,75 j   +10 % du planning initial
```

---

## 7. Retrospective et enseignements

### 7.1 Ce qui a bien fonctionné

| Point positif | Détail |
|---------------|--------|
| **Isolation des projets** | La séparation stricte ETL_Projet / ETL_Projet_BC a permis de travailler sans risque de régression sur le projet existant |
| **Pattern sous-workflow** | La découpe en 6 sous-workflows indépendants (WF-08A à 08F) a rendu le développement et les tests très modulaires |
| **Architecture Codeunit centralisé** | Une fois la refactorisation effectuée, le Codeunit unique a simplifié toute la logique BC |
| **CDC et hash MinIO** | Le pattern de contrôle de doublon par hash MD5 évite les uploads redondants et préserve l'espace de stockage |

### 7.2 Points d'amélioration identifiés

| Point d'amélioration | Action future |
|---------------------|---------------|
| **Validation du format source en amont** | Toujours confirmer le format exact des données source avec l'équipe applicative avant de démarrer le développement |
| **Anticipation des clés composées BC** | Lors de la conception, identifier systématiquement les entités à clés composées et prévoir le pattern GET-filter |
| **Tests de charge** | Prévoir des jeux de test avec des volumes importants (>10 000 lignes) dès la phase P6 |
| **Monitoring n8n** | Mettre en place des alertes (email, Slack) en cas d'échec de WF-08 pour ne pas dépendre uniquement des logs |
