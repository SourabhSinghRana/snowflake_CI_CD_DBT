# Snowflake CI/CD with dbt & Terraform

A production-grade CI/CD pipeline for data transformation on Snowflake using **dbt (Data Build Tool)**, **Terraform** for infrastructure provisioning, and **GitHub Actions** for automated deployment. The project models a **Medical domain** dataset covering doctors, patients, and visit records.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Tech Stack](#tech-stack)
- [Repository Structure](#repository-structure)
- [Snowflake Setup](#snowflake-setup)
  - [Roles & Users](#roles--users)
  - [Raw Data & Staging](#raw-data--staging)
  - [Audit Tables](#audit-tables)
- [Terraform Infrastructure](#terraform-infrastructure)
- [dbt Project](#dbt-project)
- [CI/CD Pipeline (GitHub Actions)](#cicd-pipeline-github-actions)
- [Local Development](#local-development)
- [Required GitHub Secrets](#required-github-secrets)

---

## Architecture Overview

```
GCS Bucket (raw_doctors, raw_patients, raw_visits CSVs)
        │
        ▼
Snowflake External Stage (GCS Integration)
        │
        ▼
MEDICAL.RAW  ──►  dbt Models  ──►  MEDICAL.DEV / MEDICAL.PROD
                                          │
                                          ▼
                                  MEDICAL.AUDIT (deployment history)
                                          ▲
                                          │
                               GitHub Actions CI/CD
```

---

## Tech Stack

| Tool | Purpose |
|---|---|
| **Snowflake** | Cloud data warehouse |
| **dbt-snowflake** (`1.9.0`) | Data transformation & modelling |
| **Terraform** | Snowflake infrastructure as code |
| **GitHub Actions** | CI/CD automation |
| **SQLFluff** (`4.2.1`) | SQL linting & formatting |
| **Google Cloud Storage** | External raw data stage |
| **Python** | Runtime for dbt & linting |

---

## Repository Structure

```
snowflake_CI_CD_DBT/
├── .github/
│   └── workflows/          # GitHub Actions CI/CD workflow definitions
├── dbt_project/            # dbt models, tests, macros, and config
├── terraform/              # Terraform IaC for Snowflake resource provisioning
├── RAW_STAGE.sql           # DDL for raw tables, GCS stage, and audit tables
├── ROLE_AND_USER.sql       # Snowflake role, user, and permission setup
├── commands.sql            # Handy local dev commands (venv, dbt, sqlfluff)
├── requirements.txt        # Python dependencies
└── .gitignore
```

---

## Snowflake Setup

### Roles & Users

Run `ROLE_AND_USER.sql` as `ACCOUNTADMIN` to bootstrap the necessary Snowflake principals:

- **`TRANSFORM` role** — used by dbt for all data transformation work
- **`dbt_test_user`** — service account assigned the `TRANSFORM` role; configured as `LEGACY_SERVICE` type
- **`TERRAFORM_ROLE` / `TERRAFORM_USER`** — dedicated principal for Terraform with `CREATE DATABASE`, `CREATE WAREHOUSE`, `CREATE ROLE`, and `CREATE INTEGRATION` privileges

```sql
-- Quick bootstrap (run as ACCOUNTADMIN)
USE ROLE ACCOUNTADMIN;
-- then execute ROLE_AND_USER.sql
```

The `MEDICAL` database is created with the following schemas:

| Schema | Purpose |
|---|---|
| `RAW` | Raw ingested data from GCS |
| `DEV` | Development environment for dbt |
| `PROD` | Production environment for dbt |
| `TEST` | CI/PR testing environment |
| `AUDIT` | Deployment history and lineage tracking |

---

### Raw Data & Staging

Run `RAW_STAGE.sql` to create the raw tables, configure the GCS external stage, and load initial data:

```sql
-- Raw tables
MEDICAL.RAW.raw_doctors   -- doctor_id, doctor_name, specialty, updated_at
MEDICAL.RAW.raw_patients  -- patient_id, first/last name, insurance_provider, city, updated_at
MEDICAL.RAW.raw_visits    -- visit_id, patient_id, doctor_id, visit_date, diagnosis_code, billed_amount

-- GCS External Stage
CREATE OR REPLACE STORAGE INTEGRATION gcs_int
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'GCS'
  STORAGE_ALLOWED_LOCATIONS = ('gcs://snowflake_cicd');

-- Load data
COPY INTO raw_doctors FROM @medical_stage/raw_doctors/raw_doctors.csv FILE_FORMAT = (TYPE='CSV' SKIP_HEADER=1);
```

---

### Audit Tables

Two audit tables track every deployment end-to-end:

- **`MEDICAL.AUDIT.DEPLOYMENT_HISTORY_GITHUB_ACTION`** — captures GitHub Actions run metadata (run ID, branch, commit SHA, status, trigger event)
- **`MEDICAL.AUDIT.DEPLOYMENT_HISTORY_DBT_MODEL`** — captures per-model execution details (model name, start/end time, status), linked to the GitHub run via `GH_RUN_ID`

---

## Terraform Infrastructure

The `terraform/` directory provisions Snowflake resources as code. It uses the `TERRAFORM_USER` / `TERRAFORM_ROLE` created in the setup step.

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

> **Note:** Store sensitive values (account, username, password) in a `terraform.tfvars` file — never commit secrets to source control.

---

## dbt Project

The `dbt_project/` directory contains the full dbt project targeting the `MEDICAL` database.

**Profiles** are expected at `~/.dbt/profiles.yml`. A typical Snowflake profile looks like:

```yaml
medical:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: <your_account>
      user: dbt_test_user
      password: <password>
      role: TRANSFORM
      database: MEDICAL
      warehouse: COMPUTE_WH
      schema: DEV
      threads: 4
```

**Useful local dbt commands:**

```bash
# Run all models
dbt run --profiles-dir ~/.dbt

# Run a specific model
dbt run --select fact_visits --profiles-dir ~/.dbt

# Run dbt tests
dbt test --profiles-dir ~/.dbt
```

**SQL linting with SQLFluff:**

```bash
# Lint all models
sqlfluff lint models --dialect snowflake --profiles-dir ~/.dbt

# Auto-fix lint issues
sqlfluff fix models --dialect snowflake --profiles-dir ~/.dbt
```

---

## CI/CD Pipeline (GitHub Actions)

Workflows in `.github/workflows/` automate the full test-and-deploy lifecycle:

| Trigger | Action |
|---|---|
| Pull Request opened/updated | SQLFluff linting, `dbt run` against `TEST` schema, write audit records |
| Push / merge to `prod` branch | `dbt run` against `PROD` schema, write audit records |

Each run logs metadata into `MEDICAL.AUDIT.DEPLOYMENT_HISTORY_GITHUB_ACTION` and per-model results into `MEDICAL.AUDIT.DEPLOYMENT_HISTORY_DBT_MODEL`.

---

## Local Development

```bash
# 1. Create and activate a virtual environment
python -m venv venv
echo "venv/" >> .gitignore
source venv/bin/activate        # Linux/Mac
# or: venv\Scripts\activate     # Windows

# 2. Install dependencies
pip install -r requirements.txt

# 3. Create the dbt profiles directory (Windows example)
mkdir %userprofile%\.dbt
# Place your profiles.yml inside ~/.dbt/

# 4. Verify dbt connection
dbt debug --profiles-dir ~/.dbt
```

---

## Required GitHub Secrets

Add the following secrets to your GitHub repository (`Settings → Secrets and variables → Actions`):

| Secret | Description |
|---|---|
| `SNOWFLAKE_ACCOUNT` | Your Snowflake account identifier |
| `SNOWFLAKE_USER` | Service account username (`dbt_test_user`) |
| `SNOWFLAKE_PASSWORD` | Service account password |
| `SNOWFLAKE_ROLE` | `TRANSFORM` |
| `SNOWFLAKE_WAREHOUSE` | `COMPUTE_WH` |
| `SNOWFLAKE_DATABASE` | `MEDICAL` |
| `GCS_KEY` / `GCP_CREDENTIALS` | GCP service account key for GCS stage access (if applicable) |

---

## License

This project is for educational and demonstration purposes.
