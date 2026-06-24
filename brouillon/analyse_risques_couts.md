# Analyse des Risques, Coûts et Business Cases
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

1. [Analyse des risques](#1-analyse-des-risques)
2. [Analyse des coûts — TCO](#2-analyse-des-coûts--tco)
3. [Retour sur investissement — ROI](#3-retour-sur-investissement--roi)
4. [Business Case 1 — Élimination de la saisie manuelle](#4-business-case-1--élimination-de-la-saisie-manuelle)
5. [Business Case 2 — Conformité kilométrique et remboursements](#5-business-case-2--conformité-kilométrique-et-remboursements)

---

## 1. Analyse des risques

### 1.1 Matrice des risques

| ID | Catégorie | Risque | Probabilité | Impact | Criticité | Mitigation |
|----|-----------|--------|:-----------:|:------:|:---------:|------------|
| R-01 | Sécurité | Credentials PostgreSQL en clair dans le code n8n | Moyenne | Élevé | **Critique** | Utiliser les credentials n8n chiffrés (`$vars`) ; ne jamais logger les mots de passe |
| R-02 | Sécurité | Exposition du webhook GPS sans authentification | Moyenne | Moyen | **Élevé** | Ajouter un token secret dans le header de la requête GPS ; valider côté n8n |
| R-03 | Sécurité | Proxy NTLM comme point de défaillance unique | Faible | Élevé | **Élevé** | Surveiller le proxy ; prévoir un proxy de secours ou une authentification alternative |
| R-04 | RGPD/LPD | Conservation des données GPS de localisation | Élevée | Élevé | **Critique** | Les coordonnées GPS (lat/lon) ne sont **jamais persistées** — seules les métriques agrégées sont stockées (distance, vitesse, durée) |
| R-05 | RGPD/LPD | Données personnelles clients dans BC sans base légale | Faible | Élevé | **Élevé** | Vérifier que le traitement des données clients est couvert par le contrat de service ; prévoir une procédure de suppression |
| R-06 | RGPD/LPD | Logs n8n contenant des données personnelles | Moyenne | Moyen | **Moyen** | Limiter les logs à des compteurs agrégés (total, errors) — ne pas logger les valeurs de champs personnels |
| R-07 | Disponibilité | Arrêt du service n8n (crash, redémarrage Docker) | Moyenne | Élevé | **Élevé** | Politique de restart automatique Docker (`restart: always`) ; la synchronisation reprend au prochain schedule |
| R-08 | Disponibilité | Arrêt de BC OnPrem pendant la synchronisation | Faible | Élevé | **Moyen** | Les erreurs BC sont comptabilisées sans interrompre la synchro ; la prochaine exécution complète la synchronisation |
| R-09 | Disponibilité | Arrêt PostgreSQL pendant un sous-workflow | Faible | Élevé | **Moyen** | Timeout de connexion configuré (10 000 ms) ; le sous-workflow échoue avec un message clair |
| R-10 | Dépendances | Réseau Docker etl_network défaillant | Faible | Critique | **Élevé** | Isolation des services sur un réseau dédié ; pas d'exposition publique |
| R-11 | Dépendances | Montée de version BC incompatible avec l'API AL | Faible | Élevé | **Moyen** | L'extension AL spécifie `runtime: 13.0` ; tester toute mise à jour BC en environnement de développement avant production |
| R-12 | Dépendances | Changement de format des événements GPS | Moyenne | Moyen | **Moyen** | Documenter le contrat de format avec l'application GPS ; valider le champ `event` à la réception |
| R-13 | Données | Doublons lors de la synchronisation | Faible | Moyen | **Faible** | Pattern upsert (POST → 409 → PATCH) garantit l'idempotence |
| R-14 | Données | Perte de données GPS entre deux lancements Apache Hop | Moyenne | Moyen | **Moyen** | Le fichier de staging est préservé entre les exécutions ; MinIO conserve l'historique versionné |
| R-15 | Performance | fact_ecommerce_lines dépasse 10 000 lignes | Élevée | Faible | **Moyen** | LIMIT 10 000 appliqué ; prévoir un mécanisme de pagination incrémentale si le volume augmente |

### 1.2 Détail des risques RGPD/LPD

La collecte de données GPS est particulièrement sensible au regard du RGPD (Règlement Général sur la Protection des Données) et de la LPD suisse (Loi sur la Protection des Données).

| Point de vigilance | Traitement appliqué dans le projet | Conformité |
|--------------------|------------------------------------|-----------|
| **Localisation des chauffeurs** | Les coordonnées GPS (lat, lon, accuracy) transitent en mémoire dans n8n mais ne sont **jamais écrites** dans un fichier, une base de données ou un log | ✅ Conforme |
| **Durée de conservation** | Les données agrégées (distance, vitesse) sont conservées sans limite définie | ⚠️ Prévoir une politique de rétention (ex. : 3 ans) |
| **Finalité du traitement** | Suivi kilométrique des véhicules de livraison — finalité légitime et proportionnée | ✅ Conforme |
| **Information des personnes** | Les chauffeurs doivent être informés du suivi GPS | ⚠️ À documenter dans le registre des traitements |
| **Droit à l'effacement** | Aucun mécanisme d'effacement d'un `session_id` spécifique n'est implémenté | ⚠️ À prévoir |
| **Transfert hors UE** | Toutes les données restent sur l'infrastructure locale (OnPrem) | ✅ Conforme |

### 1.3 Plan de mitigation prioritaire

| Priorité | Risque | Action | Délai |
|----------|--------|--------|-------|
| 1 | R-01 | Migrer les credentials PostgreSQL vers les variables d'environnement n8n chiffrées | Immédiat |
| 2 | R-04 | Documenter explicitement l'absence de persistance des coordonnées GPS | Immédiat |
| 3 | R-02 | Ajouter un header `X-GPS-Token` au webhook WF-04B | Court terme |
| 4 | R-05 | Vérifier la base légale du traitement des données clients | Court terme |
| 5 | R-15 | Implémenter la pagination incrémentale pour fact_ecommerce_lines | Moyen terme |

---

## 2. Analyse des coûts — TCO

### 2.1 Coûts d'infrastructure (annuels estimés)

| Composant | Type | Coût annuel estimé | Justification |
|-----------|------|-------------------|---------------|
| Serveur hôte (VM / machine physique) | Infrastructure | 800 € | Serveur dédié ou VM cloud OnPrem |
| Licence Business Central OnPrem | Logiciel | 2 400 € | BC 26.0 OnPrem Essential (~200 €/utilisateur/mois × 1) |
| PostgreSQL | Logiciel | 0 € | Open source |
| n8n | Logiciel | 0 € | Self-hosted, open source |
| Apache Hop | Logiciel | 0 € | Open source (Apache Foundation) |
| MinIO | Logiciel | 0 € | Open source |
| Docker / Docker Compose | Logiciel | 0 € | Open source |
| Proxy NTLM (Squid) | Logiciel | 0 € | Open source |
| **Total infrastructure annuel** | | **3 200 €** | |

### 2.2 Coûts de développement (one-shot)

| Phase | Tâche | Jours/homme | Taux journalier | Coût |
|-------|-------|:-----------:|:---------------:|------|
| Conception | CDC, specs, architecture | 3 j | 400 € | 1 200 € |
| Développement AL | Extension BC (tables + codeunit + pages) | 4 j | 400 € | 1 600 € |
| Développement n8n | 8 workflows (WF-04B + WF-08 + 6 sous-WF) | 3 j | 400 € | 1 200 € |
| Développement Hop | 2 pipelines Silver + Gold | 2 j | 400 € | 800 € |
| Migration SQL | Schema Gold updates | 0,5 j | 400 € | 200 € |
| Tests | Protocole + exécution | 2 j | 400 € | 800 € |
| Documentation | Docs techniques + rapport | 2 j | 400 € | 800 € |
| **Total développement** | | **16,5 j** | | **6 600 €** |

### 2.3 Coûts opérationnels annuels

| Poste | Coût annuel estimé |
|-------|-------------------|
| Maintenance corrective (bugs, mises à jour BC) | 400 € (1 j/an) |
| Maintenance évolutive (nouvelles entités, changements de format) | 800 € (2 j/an) |
| Surveillance et monitoring | 200 € (0,5 j/an) |
| **Total opérationnel annuel** | **1 400 €** |

### 2.4 TCO sur 3 ans

| Poste | Année 0 (développement) | Année 1 | Année 2 | Année 3 | Total |
|-------|:-----------------------:|:-------:|:-------:|:-------:|-------|
| Infrastructure | 0 € | 3 200 € | 3 200 € | 3 200 € | 9 600 € |
| Développement | 6 600 € | 0 € | 0 € | 0 € | 6 600 € |
| Opérationnel | 0 € | 1 400 € | 1 400 € | 1 400 € | 4 200 € |
| **Total** | **6 600 €** | **4 600 €** | **4 600 €** | **4 600 €** | **20 400 €** |

---

## 3. Retour sur investissement — ROI

### 3.1 Gains identifiés

| Source de gain | Calcul | Gain annuel estimé |
|----------------|--------|-------------------|
| **Élimination de la saisie manuelle** | 2 h/jour × 5 jours/semaine × 48 semaines × 30 €/h | 14 400 € |
| **Réduction des erreurs de saisie** | 3 corrections/semaine × 1 h × 48 semaines × 30 €/h | 4 320 € |
| **Remboursements kilométriques précis** | Réduction des litiges : 2 litiges/mois × 2 h × 12 mois × 50 €/h | 2 400 € |
| **Décisions plus rapides** | Gain de productivité sur le reporting : 3 h/semaine × 48 semaines × 40 €/h | 5 760 € |
| **Total gains annuels** | | **26 880 €** |

### 3.2 Calcul du ROI

```
Investissement initial     =  6 600 € (développement)
Gains année 1              = 26 880 € - 4 600 € (coûts annuels) = 22 280 €
Gains année 2              = 26 880 € - 4 600 € = 22 280 €
Gains année 3              = 26 880 € - 4 600 € = 22 280 €

ROI année 1 = (22 280 - 6 600) / 6 600 × 100 = 237 %
Retour sur investissement atteint en : 3,5 mois
TCO 3 ans                  = 20 400 €
Gains totaux 3 ans         = 26 880 × 3 = 80 640 €
Gain net 3 ans             = 80 640 - 20 400 = 60 240 €
```

---

## 4. Business Case 1 — Élimination de la saisie manuelle

### 4.1 Situation actuelle (avant projet)

Avant la mise en place du pipeline ETL_Projet_BC, les données de clients, articles, expéditions et ventes e-commerce devaient être saisies manuellement dans Business Central par les gestionnaires. Ce processus présentait les problèmes suivants :

| Problème | Conséquence |
|----------|-------------|
| Saisie manuelle quotidienne de centaines de lignes | 2 heures de travail non productif par jour |
| Risques d'erreurs de frappe (codes articles, montants) | Litiges clients, corrections coûteuses |
| Délai entre la génération des données et leur disponibilité dans BC | Décisions prises sur des données de la veille ou de l'avant-veille |
| Aucune traçabilité de l'import | Impossible de savoir si les données sont complètes et à jour |

### 4.2 Solution apportée

Le pipeline ETL automatise l'intégralité du flux de données de l'entrepôt Gold vers BC :

- **Synchronisation quotidienne automatique** à 09h00 (schedule cron)
- **Déclenchement manuel** depuis le Dashboard BC si besoin en dehors des horaires
- **Rapport de synchronisation** `{inserted, updated, errors}` disponible dans les logs n8n
- **Idempotence garantie** : aucun doublon possible, re-exécution sans risque

### 4.3 Critères de succès

| Critère | Cible | Méthode de mesure |
|---------|-------|------------------|
| Taux d'erreurs de données BC | < 0,1 % des enregistrements | Compteur `errors` dans le rapport de synchro |
| Délai de disponibilité dans BC | < 30 minutes après 09h00 | Durée d'exécution de WF-08 |
| Réduction du temps de saisie | 100 % (zéro saisie manuelle) | Observation métier |
| Fiabilité de la synchronisation | > 99 % des exécutions sans erreur bloquante | Logs n8n sur 30 jours |

### 4.4 Conclusion Business Case 1

L'automatisation totale de la saisie supprime un poste de 14 400 €/an de travail à faible valeur ajoutée et réduit à quasi-zéro les erreurs de données dans BC. Le retour sur investissement de ce seul cas d'usage couvre l'intégralité du coût de développement du projet en moins de 6 mois.

---

## 5. Business Case 2 — Conformité kilométrique et remboursements

### 5.1 Situation actuelle (avant projet)

Le suivi des kilomètres parcourus par les camions de livraison reposait sur l'API Google Distance Matrix, qui fournit des **estimations théoriques** de distances entre une origine et une destination. Ces estimations présentaient plusieurs limites :

| Limitation | Conséquence |
|------------|-------------|
| Distance estimée ≠ distance réelle parcourue | Remboursements de carburant incorrects (sur ou sous-estimés) |
| Pas de prise en compte des détours, embouteillages, arrêts | Données non conformes à la réalité terrain |
| Facturation Google Distance Matrix API | Coût récurrent pour des données inexactes |
| Aucune traçabilité des trajets réels | Impossible de justifier les kilométrages en cas de litige |

### 5.2 Solution apportée

Le remplacement de l'API Google Distance Matrix par un **webhook de réception GPS en temps réel** (WF-04B) collecte les données réelles des véhicules :

| Métrique collectée | Utilisation métier |
|-------------------|--------------------|
| `total_distance_km` | Base exacte de remboursement carburant |
| `total_distance_meters` | Précision au mètre pour les rapports réglementaires |
| `max_speed_kmh` | Détection des excès de vitesse |
| `avg_speed_kmh` | Analyse des performances de livraison |
| `total_active_seconds` | Calcul du temps effectif de conduite |
| `event_count` | Vérification de la couverture GPS de la session |
| `first_event_at` / `last_event_at` | Horodatage précis début/fin de session |

### 5.3 Gains quantifiés

| Poste | Calcul | Gain annuel |
|-------|--------|-------------|
| Suppression coût API Google | ~500 requêtes/mois × 0,005 $/requête × 12 | ~30 € |
| Remboursements carburant précis | Réduction des sur-remboursements estimée à 5 % sur 24 000 €/an de carburant | 1 200 € |
| Réduction des litiges kilométriques | 2 litiges/mois × 2 h × 50 €/h × 12 mois | 2 400 € |
| Gain de temps chauffeur (saisie manuelle supprimée) | 15 min/jour × 220 jours × 20 €/h | 1 100 € |
| **Total gains annuels** | | **4 730 €** |

### 5.4 Bénéfices non financiers

| Bénéfice | Description |
|----------|-------------|
| **Conformité réglementaire** | Les données GPS réelles peuvent servir de preuve en cas de contrôle (temps de conduite, zones de livraison) |
| **Sécurité des conducteurs** | La métrique `max_speed_kmh` permet d'identifier les comportements à risque |
| **Optimisation des tournées** | L'analyse des `avg_speed_kmh` et `total_active_seconds` sur plusieurs sessions identifie les axes à optimiser |
| **Indépendance technologique** | Aucune dépendance à une API commerciale tierce (Google) ; les données sont propriété de l'entreprise |

### 5.5 Critères de succès

| Critère | Cible | Méthode de mesure |
|---------|-------|------------------|
| Couverture GPS des sessions | > 95 % des trajets couverts | `event_count > 0` pour 95 % des sessions Gold |
| Précision des distances | Écart < 5 % avec le compteur kilométrique physique | Comparaison manuelle sur échantillon mensuel |
| Délai de disponibilité des données dans BC | < 24 h après la session | `last_event_at` vs `etlLoadedAt` dans etlDistances |
| Réduction des litiges | 0 litige de remboursement sur données GPS en 6 mois | Suivi RH/comptabilité |

### 5.6 Conclusion Business Case 2

Le remplacement de l'API Google Distance Matrix par un système GPS temps réel apporte 4 730 €/an de gains directs, mais surtout des bénéfices qualitatifs majeurs : conformité réglementaire, sécurité, et indépendance technologique. Ce cas d'usage démontre que le projet va au-delà d'une simple intégration technique — il transforme la qualité de la donnée kilométrique de l'estimation à la mesure réelle.
