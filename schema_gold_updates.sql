-- ============================================================
--  ETL_Projet_BC — Migration SQL
--  À exécuter sur la base data_warehouse_gold APRÈS ETL_Projet
--  pour ajouter le support des sessions GPS temps réel
-- ============================================================

-- 1. Supprimer l'ancienne dim_distances (Google Distance Matrix)
DROP TABLE IF EXISTS dim_distances CASCADE;

-- 2. Créer silver.distance_matrix avec le nouveau schéma GPS
CREATE SCHEMA IF NOT EXISTS silver;
DROP TABLE IF EXISTS silver.distance_matrix;
CREATE TABLE silver.distance_matrix (
    session_id             VARCHAR(50),
    session_date           VARCHAR(10),
    total_distance_km      VARCHAR(30),
    total_distance_meters  VARCHAR(30),
    max_speed_kmh          VARCHAR(30),
    avg_speed_kmh          VARCHAR(30),
    total_active_seconds   VARCHAR(20),
    event_count            VARCHAR(20),
    first_event_at         VARCHAR(50),
    last_event_at          VARCHAR(50)
);

-- 3. Recréer dim_distances avec le schéma sessions GPS
--    session_id = clé naturelle (ID de session envoyé par l'application)
CREATE TABLE dim_distances (
    session_id             VARCHAR(50)    PRIMARY KEY,
    session_date           DATE,
    total_distance_km      DECIMAL(10,4),
    total_distance_meters  DECIMAL(10,2),
    max_speed_kmh          DECIMAL(10,3),
    avg_speed_kmh          DECIMAL(10,3),
    total_active_seconds   INTEGER,
    event_count            INTEGER,
    first_event_at         TIMESTAMP,
    last_event_at          TIMESTAMP,
    extracted_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. Supprimer la FK dim_date de fact_shipment_lines (dim_date supprimée)
--    Si la contrainte existe encore (projet ETL_Projet déjà appliqué)
ALTER TABLE fact_shipment_lines
    DROP CONSTRAINT IF EXISTS fact_shipment_lines_shipment_date_fkey;

-- 5. Vérification
SELECT
    'dim_distances' AS table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name   = 'dim_distances'
ORDER BY ordinal_position;
