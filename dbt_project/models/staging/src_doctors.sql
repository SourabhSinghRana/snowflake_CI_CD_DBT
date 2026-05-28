{{ config(materialized='table') }}

WITH raw_doctors AS (
    SELECT
        doctor_id,
        doctor_name,
        specialty,
        updated_at
    FROM {{ source('medical_stage', 'raw_doctors') }}
)

SELECT *
FROM raw_doctors
