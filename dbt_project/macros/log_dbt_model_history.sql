{% macro log_dbt_model_history(results) %}
  {% if execute %}
  
    -- Grab the Join Key from GitHub Actions
    {% set gh_run_id = env_var('DBT_ENV_GH_RUN_ID', 'manual_run_no_id') %}

    {% for res in results %}
      
      -- 1. FILTER: Only log models and snapshots (ignore tests and seeds)
      {% if res.node.resource_type in ['model', 'snapshot'] %}
      
        {% set model_name = res.node.name %}
        {% set status = res.status %}
        
        -- 2. SAFE TIMING: Default to SQL NULL in case the model was skipped
        {% set start_time = 'NULL' %}
        {% set end_time = 'NULL' %}
        
        -- Only extract timing if the array actually contains data
        {% if res.timing and res.timing | length > 0 %}
          -- timing[0] is usually compilation start, timing[-1] is execution end
          {% set start_time = "'" ~ res.timing[0].started_at ~ "'" %}
          {% set end_time = "'" ~ res.timing[-1].completed_at ~ "'" %}
        {% endif %}

        {% set audit_query %}
          INSERT INTO MEDICAL.AUDIT.DEPLOYMENT_HISTORY_DBT_MODEL (
              GH_RUN_ID,
              DBT_MODEL_NAME,
              QUERY_START_TIME,
              QUERY_END_TIME,
              DEPLOYMENT_STATUS
          ) VALUES (
              '{{ gh_run_id }}',
              '{{ model_name }}',
              {{ start_time }},   -- No quotes here because we added them above
              {{ end_time }},     -- No quotes here because we added them above
              '{{ status }}'
          );
        {% endset %}

        {% do run_query(audit_query) %}
        
      {% endif %}
      
    {% endfor %}
    
  {% endif %}
{% endmacro %}