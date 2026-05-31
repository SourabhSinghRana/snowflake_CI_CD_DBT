--create python env
python -m venv venv
echo "venv/" >> .gitignore
venv\Scripts\activate


--create dbt profile
mkdir %userprofile%\.dbt


--dbt profile present in this dir
C:\Users\soura\.dbt




sqlfluff lint models --dialect snowflake --profiles-dir C:\Users\soura\.dbt
sqlfluff fix models --dialect snowflake --profiles-dir C:\Users\soura\.dbt


dbt run --select fact_visits  --profiles-dir C:\Users\soura\.dbt
dbt run  --profiles-dir C:\Users\soura\.dbt