{{ config(materialized='table') }}

WITH raw_visits AS (
    SELECT
        visit_id,
        patient_id,
        doctor_id,
        visit_date,
        diagnosis_code,
        billed_amount
    FROM {{ source('medical_stage', 'raw_visits') }}
)

SELECT *
FROM raw_visits
