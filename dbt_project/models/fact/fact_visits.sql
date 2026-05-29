{{ config(
    materialized='incremental',
    unique_key='visit_id'
) }}

select
    v.visit_id,
    v.patient_id,
    v.doctor_id,
    v.visit_date,

    p.first_name,
    p.last_name,
    p.city,

    d.doctor_name,
    d.specialty

from {{ ref('src_visits') }} v

left join {{ ref('dim_patients') }} p
    on v.patient_id = p.patient_id
    and p.dbt_valid_to is null

left join {{ ref('dim_doctors') }} d
    on v.doctor_id = d.doctor_id

{% if is_incremental() %}

where v.visit_date >
    (select max(visit_date) from {{ this }})

{% endif %}