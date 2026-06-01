# Snowflake CI/CD with dbt & Terraform

A production-grade CI/CD pipeline for a **healthcare data platform** built on Snowflake, using **dbt** for data transformation and **Terraform** for infrastructure-as-code. GitHub Actions automates linting, testing, and deployment across `dev` and `prod` environments — with full audit logging back into Snowflake.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Tech Stack](#tech-stack)
- [Repository Structure](#repository-structure)
- [Snowflake Setup](#snowflake-setup)
  - [Roles & Users](#roles--users)
  - [Raw Stage & Source Tables](#raw-stage--source-tables)
  - [Audit Tables](#audit-tables)
- [dbt Project](#dbt-project)
- [Terraform Infrastructure](#terraform-infrastructure)
- [CI/CD Workflows](#cicd-workflows)
- [Local Development](#local-development)
- [GitHub Secrets Required](#github-secrets-required)
- [Branch Strategy](#branch-strategy)

---

## Architecture Overview

```
GCS Bucket (raw_doctors, raw_patients, raw_visits)
        │
        ▼
  Snowflake RAW Schema  ──── External Stage (GCS Integration)
        │
        ▼
   dbt Transformations
  (dev / prod schemas)
        │
        ▼
   Audit Logging
  (DEPLOYMENT_HISTORY_GITHUB_ACTION + DEPLOYMENT_HISTORY_DBT_MODEL)
        │
  GitHub Actions CI/CD
  ┌─────────────┐    ┌──────────────────┐
  │  PR opened  │───▶│  dbt lint + test │  (CI — runs on dev schema)
  └─────────────┘    └──────────────────┘
  ┌─────────────┐    ┌──────────────────┐
  │ Merge → prod│───▶│  dbt run (prod)  │  (CD — deploys to prod schema)
  └─────────────┘    └──────────────────┘
                        + Terraform apply
```

---

## Tech Stack

| Tool | Purpose |
|---|---|
| **Snowflake** | Cloud data warehouse (MEDICAL database) |
| **dbt Core 1.11** | Data transformation and modeling |
| **dbt-snowflake 1.9** | Snowflake adapter for dbt |
| **Terraform** | Infrastructure-as-code for Snowflake provisioning |
| **GitHub Actions** | CI/CD automation |
| **SQLFluff 4.2** | SQL linting with dbt-templater |
| **Google Cloud Storage** | Raw data landing zone (external stage) |

---

## Repository Structure

```
snowflake_CI_CD_DBT/
├── .github/
│   └── workflows/          # GitHub Actions CI/CD pipeline definitions
├── dbt_project/            # dbt Core project (models, tests, macros)
├── terraform/              # Terraform configs for Snowflake infrastructure
├── RAW_STAGE.sql           # Snowflake setup: raw tables, GCS stage, audit tables
├── ROLE_AND_USER.sql       # Snowflake RBAC: roles, users, permissions
├── commands.sql            # Local dev commands reference (venv, dbt, SQLFluff)
├── requirements.txt        # Python dependencies (pinned)
└── .gitignore
```

---

## Snowflake Setup

Run these scripts **once** using `ACCOUNTADMIN` to bootstrap the environment. They are not applied via Terraform or dbt — they are manual setup scripts.

### Roles & Users

**File:** `ROLE_AND_USER.sql`

Creates two service accounts:

**`dbt_test_user`** — Used by dbt and GitHub Actions to run transformations:
- Role: `TRANSFORM`
- Warehouse: `COMPUTE_WH`
- Permissions: Full access to `MEDICAL` database (RAW, DEV, PROD, TEST schemas) and INSERT on audit tables

**`TERRAFORM_USER`** — Used by Terraform to provision Snowflake infrastructure:
- Role: `TERRAFORM_ROLE`
- Permissions: `CREATE DATABASE`, `CREATE WAREHOUSE`, `CREATE ROLE`, `CREATE INTEGRATION` on account

```sql
-- Run as ACCOUNTADMIN
USE ROLE ACCOUNTADMIN;
-- See ROLE_AND_USER.sql for complete setup
```

### Raw Stage & Source Tables

**File:** `RAW_STAGE.sql`

Sets up the `MEDICAL.RAW` schema with three source tables and a GCS external stage:

| Table | Description |
|---|---|
| `raw_doctors` | Doctor ID, name, specialty, updated timestamp |
| `raw_patients` | Patient ID, name, insurance provider, city, updated timestamp |
| `raw_visits` | Visit ID, patient/doctor IDs, diagnosis code, billed amount |

Data is loaded from GCS via a storage integration and `COPY INTO` commands:

```sql
-- GCS integration (run once)
CREATE OR REPLACE STORAGE INTEGRATION gcs_int
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'GCS'
  STORAGE_ALLOWED_LOCATIONS = ('gcs://snowflake_cicd');

-- Stage
CREATE OR REPLACE STAGE medical_stage
  URL='gcs://snowflake_cicd/'
  STORAGE_INTEGRATION = gcs_int;
```

### Audit Tables

Also created in `RAW_STAGE.sql` under `MEDICAL.AUDIT`:

| Table | Description |
|---|---|
| `DEPLOYMENT_HISTORY_GITHUB_ACTION` | One record per GitHub Actions run — branch, commit SHA, status, trigger event |
| `DEPLOYMENT_HISTORY_DBT_MODEL` | One record per dbt model execution — model name, start/end time, status |

These tables are populated automatically by the CI/CD workflows, providing full deployment observability inside Snowflake.

---

## dbt Project

**Directory:** `dbt_project/`

The dbt project transforms raw medical data through layered models targeting different Snowflake schemas based on the active environment:

| dbt Target | Snowflake Schema |
|---|---|
| `dev` | `MEDICAL.DEV` |
| `prod` | `MEDICAL.PROD` |

**Key dbt concepts used:**
- Source definitions pointing to `MEDICAL.RAW`
- Staged/intermediate and mart models
- `dbt test` for data quality checks
- SQLFluff linting with the dbt-Snowflake templater

**Profiles** (stored locally at `~/.dbt/profiles.yml`, not committed):

```yaml
dbt_project:
  outputs:
    dev:
      type: snowflake
      account: <your_account>
      user: dbt_test_user
      password: <password>
      role: TRANSFORM
      database: MEDICAL
      schema: DEV
      warehouse: COMPUTE_WH
      threads: 1
    prod:
      ...same, schema: PROD
```

---

## Terraform Infrastructure

**Directory:** `terraform/`

Terraform provisions and manages Snowflake infrastructure declaratively, ensuring environments are reproducible and version-controlled. The `TERRAFORM_USER` service account is used for all Terraform operations.

Typical resources managed:
- Warehouses
- Databases and schemas
- Roles and grants
- Storage integrations

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

---

## CI/CD Workflows

**Directory:** `.github/workflows/`

### Continuous Integration (CI) — Pull Requests

Triggered on every pull request targeting `prod`:

1. Checkout code
2. Install Python dependencies (`requirements.txt`)
3. Configure dbt profile using GitHub Secrets
4. Run `sqlfluff lint` on all models (`--dialect snowflake`)
5. Run `dbt deps` and `dbt run` against the `dev` schema
6. Run `dbt `
7. Log result to `MEDICAL.AUDIT.DEPLOYMENT_HISTORY_GITHUB_ACTION`

If any step fails, the PR is blocked from merging.

### Continuous Deployment (CD) — Merge to `prod`

Triggered on push/merge to the `prod` branch:

1. Run Terraform (`terraform init` + `terraform apply`) to apply any infra changes
2. Run `dbt run --target prod` to deploy models to `MEDICAL.PROD`
3. Log each model execution to `MEDICAL.AUDIT.DEPLOYMENT_HISTORY_DBT_MODEL`
4. Update `MEDICAL.AUDIT.DEPLOYMENT_HISTORY_GITHUB_ACTION` with final status

---

## Local Development

```bash
# 1. Create and activate virtual environment
python -m venv venv
echo "venv/" >> .gitignore
venv\Scripts\activate          # Windows
# source venv/bin/activate     # macOS/Linux

# 2. Install dependencies
pip install -r requirements.txt

# 3. Create dbt profile directory and configure profiles.yml
mkdir %userprofile%\.dbt       # Windows
# mkdir ~/.dbt                 # macOS/Linux
# Edit ~/.dbt/profiles.yml with your Snowflake credentials

# 4. Lint SQL models
sqlfluff lint models --dialect snowflake --profiles-dir ~/.dbt

# 5. Fix lint issues automatically
sqlfluff fix models --dialect snowflake --profiles-dir ~/.dbt

# 6. Run all dbt models
dbt run --profiles-dir ~/.dbt

# 7. Run a specific model
dbt run --select fact_visits --profiles-dir ~/.dbt
```

---

## GitHub Secrets Required

Configure these in **Settings → Secrets and variables → Actions**:

| Secret | Description |
|---|---|
| `SNOWFLAKE_ACCOUNT` | Snowflake account identifier (e.g. `abc123.us-east-1`) |
| `SNOWFLAKE_USER` | `dbt__user` |
| `SNOWFLAKE_PASSWORD` | Password for `dbt_test_user` |
| `SNOWFLAKE_ROLE` | `TRANSFORM` |
| `SNOWFLAKE_WAREHOUSE` | `COMPUTE_WH` |
| `SNOWFLAKE_DATABASE` | `MEDICAL` |
| `TF_VAR_snowflake_account` | Snowflake account for Terraform |
| `TF_VAR_snowflake_user` | `TERRAFORM_USER` |
| `TF_VAR_snowflake_password` | Password for `TERRAFORM_USER` |

---

## Branch Strategy

| Branch | Purpose |
|---|---|
| `prod` | Production — protected, deploys to `MEDICAL.PROD` |
| `dev` | Active development, runs against `MEDICAL.DEV` |
| `feature/*` | Feature branches — open PRs to trigger CI |

Pull requests to `prod` must pass CI (lint + dbt tests) before merging. Merging to `prod` automatically triggers the CD pipeline.
