{% macro log_dbt_model_history(results) %}
  {% if execute %}
  
    {% set gh_run_id = env_var('DBT_ENV_GH_RUN_ID', 'manual_run_no_id') %}
    {% set insert_values = [] %}

    {% for res in results %}
      {% if res.node.resource_type in ['model', 'snapshot'] %}
      
        {% set model_name = res.node.name %}
        {% set status = res.status %}
        
        {% set start_time = 'NULL' %}
        {% set end_time = 'NULL' %}
        
        {% if res.timing and res.timing | length > 0 %}
          {% set start_time = "'" ~ res.timing[0].started_at ~ "'" %}
          {% set end_time = "'" ~ res.timing[-1].completed_at ~ "'" %}
        {% endif %}

        {% set row_values = "('" ~ gh_run_id ~ "', '" ~ model_name ~ "', " ~ start_time ~ ", " ~ end_time ~ ", '" ~ status ~ "')" %}
        {% do insert_values.append(row_values) %}
        
      {% endif %}
    {% endfor %}

    -- Output the raw SQL directly. dbt will capture this text and execute it natively.
    {% if insert_values | length > 0 %}
      INSERT INTO MEDICAL.AUDIT.DEPLOYMENT_HISTORY_DBT_MODEL (
          GH_RUN_ID,
          DBT_MODEL_NAME,
          QUERY_START_TIME,
          QUERY_END_TIME,
          DEPLOYMENT_STATUS
      ) VALUES 
      {{ insert_values | join(',\n') }};
    {% endif %}
    
  {% endif %}
{% endmacro %}