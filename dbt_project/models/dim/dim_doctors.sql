{{ config(materialized='table') }}

select
    doctor_id,
    doctor_name,
    specialty

from {{ ref('src_doctors') }}