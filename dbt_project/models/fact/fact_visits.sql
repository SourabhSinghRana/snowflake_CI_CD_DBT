{{ config(
    materialized='incremental',
    unique_key='visit_id'
) }}

SELECT
    v.visit_id,
    v.patient_id,
    v.doctor_id,
    v.visit_date,

    p.first_name,
    p.last_name,
    p.city,

    d.doctor_name,
    d.specialty

FROM {{ ref('src_visits') }} AS v

LEFT JOIN {{ ref('dim_patients') }} AS p
    ON
        v.patient_id = p.patient_id
        AND p.dbt_valid_to IS null

LEFT JOIN {{ ref('dim_doctors') }} AS d
    ON v.doctor_id = d.doctor_id

{% if is_incremental() %}

    WHERE
        v.visit_date
        > (
            SELECT MAX(f.visit_date)
            FROM {{ this }} AS f
        )

{% endif %}
