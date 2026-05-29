{{ config(materialized='table') }}

SELECT
    doctor_id,
    doctor_name,
    specialty

FROM {{ ref('src_doctors') }}
