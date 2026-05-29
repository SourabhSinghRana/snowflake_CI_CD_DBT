{% snapshot dim_patients %}

{{
    config(
        unique_key='patient_id',
        strategy='timestamp',
        updated_at='updated_at'
    )
}}

select
    patient_id,
    first_name,
    last_name,
    city,
    insurance_provider,
    updated_at

from {{ ref('src_patients') }}

{% endsnapshot %}