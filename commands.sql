# Create the Python virtual environment
python -m venv venv

# Add the virtual environment to .gitignore
echo "venv/" >> .gitignore

# Activate the virtual environment (Windows)
venv\Scripts\activate

# Create the dbt profile directory
mkdir %userprofile%\.dbt

# Note: Your dbt profile (profiles.yml) needs to be present in this directory:
# C:\Users\soura\.dbt


# Create the dbt profile directory
mkdir %userprofile%\.dbt

# Note: Your dbt profile (profiles.yml) needs to be present in this directory:
# C:\Users\soura\.dbt


# Lint (check for errors) in Snowflake SQL models
sqlfluff lint models --dialect snowflake --profiles-dir C:\Users\soura\.dbt

# Automatically fix formatting issues in Snowflake SQL models
sqlfluff fix models --dialect snowflake --profiles-dir C:\Users\soura\.dbt


# Run a specific model (fact_visits)
dbt run --select fact_visits --profiles-dir C:\Users\soura\.dbt

# Run all models in the project
dbt run --profiles-dir C:\Users\soura\.dbt