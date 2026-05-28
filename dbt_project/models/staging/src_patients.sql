{{ config(materialized='table') }}

WITH raw_patients AS (
    SELECT
        patient_id,
        first_name,
        last_name,
        insurance_provider,
        city,
        updated_at
    FROM {{ source('medical_stage', 'raw_patients') }}
)

SELECT *
FROM raw_patients
