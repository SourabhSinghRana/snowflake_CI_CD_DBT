# ==========================================
# 1. GENERATE KEYS FOR DBT USER
# ==========================================
# Generate encrypted private key (requires a passphrase)
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out snowflake_dbt_key.p8 -v2 aes-256-cbc

# Generate public key
openssl rsa -in snowflake_dbt_key.p8 -pubout -out snowflake_dbt_key.pub

# ==========================================
# 2. GENERATE KEYS FOR CI/CD USER
# ==========================================
# Generate encrypted private key (requires a passphrase)
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out snowflake_cicd_key.p8 -v2 aes-256-cbc

# Generate public key
openssl rsa -in snowflake_cicd_key.p8 -pubout -out snowflake_cicd_key.pub