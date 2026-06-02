# Snowflake CI/CD with dbt & Terraform

> A production-style data engineering pipeline demonstrating end-to-end CI/CD for Snowflake, built with **dbt**, **Terraform**, **GitHub Actions**, and **SQLFluff** — deployed over a Healthcare domain (Doctors · Patients · Visits).

[![dbt](https://img.shields.io/badge/dbt-1.9.0-orange?logo=dbt)](https://docs.getdbt.com/)
[![Snowflake](https://img.shields.io/badge/Snowflake-Data%20Platform-29B5E8?logo=snowflake)](https://www.snowflake.com/)
[![Terraform](https://img.shields.io/badge/Terraform-IaC-7B42BC?logo=terraform)](https://www.terraform.io/)
[![SQLFluff](https://img.shields.io/badge/SQLFluff-4.2.1-green)](https://sqlfluff.com/)
[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-CI%2FCD-2088FF?logo=githubactions)](https://github.com/features/actions)

---

## What This Project Is

This repository is a **showcase of real-world CI/CD practices for a Snowflake + dbt data platform**. It goes beyond a simple dbt project — it demonstrates how a data engineering team would govern, automate, test, and deploy SQL transformations at scale, with full auditability and infrastructure-as-code.

The project uses a **Healthcare domain** (raw tables for doctors, patients, and clinic visits) as the transformation target — chosen for clarity, but the patterns are domain-agnostic.

**If you're evaluating this project, look for these pillars:**

- Automated CI/CD via GitHub Actions (PR checks + production deploys)
- Infrastructure managed as code via Terraform
- SQL quality enforcement via SQLFluff
- Multi-environment isolation (DEV / TEST / PROD)
- Role-based access control (RBAC) with least-privilege service accounts
- Custom audit logging into Snowflake for every deploy and every model run
- GCS-backed external stage for raw data ingestion
- Fully pinned, reproducible Python environment

---

## CI/CD Highlights

This is the core of the project. Below are the practices implemented that make this production-ready.

### 1. GitHub Actions Automated Workflows

The `.github/workflows/` directory contains GitHub Actions pipelines that fire on pull requests and merges to `prod`. The CI stage validates code quality and runs dbt in a `DEV` schema; the CD stage deploys to `PROD` on merge. No manual steps are required once a PR is approved.

### 2. SQL Linting with SQLFluff

Every SQL model is linted using **SQLFluff 4.2.1** with the `dbt` templater and `snowflake` dialect. The CI pipeline runs:

```bash
sqlfluff lint models --dialect snowflake --profiles-dir ~/.dbt
```

Failed lints block the PR merge. The `sqlfluff fix` command is also available locally for auto-remediation. This enforces consistent formatting, keyword casing, aliasing conventions, and clause ordering across the entire codebase — not just style, but correctness.

### 3. Multi-Environment Isolation (DEV / TEST / PROD)

Three schemas are provisioned inside the `MEDICAL` database:

| Schema | Purpose |
|---|---|
| `MEDICAL.RAW` | Raw ingestion from GCS external stage |
| `MEDICAL.DEV` | dbt development / CI runs (per PR) |
| `MEDICAL.TEST` | Optional QA layer |
| `MEDICAL.PROD` | Production-grade, pipeline-deployed models |

dbt targets are configured per environment so that CI runs never touch production data.

### 4. Terraform for Infrastructure-as-Code

Snowflake infrastructure is **not created manually**. The `terraform/` directory provisions:

- Databases and schemas
- Warehouses
- Roles and users
- Grants and permissions

A dedicated `TERRAFORM_ROLE` and `TERRAFORM_USER` handle infra changes, with appropriate account-level grants (`CREATE DATABASE`, `CREATE WAREHOUSE`, `CREATE ROLE`, `CREATE INTEGRATION`). The GitHub Actions CD workflow runs `terraform apply` as part of deployment — meaning infra and data transforms are deployed atomically.

### 5. Role-Based Access Control (RBAC) with Least Privilege

Two purpose-built roles enforce the principle of least privilege:

| Role | User | Permissions |
|---|---|---|
| `TRANSFORM` | `dbt_test_user` | Read RAW, write DEV/PROD, insert into AUDIT tables |
| `TERRAFORM_ROLE` | `TERRAFORM_USER` | Create infra objects at account level |

The dbt service user is configured as `TYPE = LEGACY_SERVICE` — it cannot log in interactively, reducing the attack surface of the CI/CD service account.

### 6. Custom Audit Logging into Snowflake

This is a standout feature. Rather than relying solely on GitHub Actions logs, every deployment is recorded directly into Snowflake:

**`MEDICAL.AUDIT.DEPLOYMENT_HISTORY_GITHUB_ACTION`**

Tracks each GitHub Actions run with:

| Column | Description |
|---|---|
| `GH_RUN_ID` | Primary key — the GitHub Actions run ID |
| `DEPLOYMENT_TIMESTAMP` | When the deploy happened |
| `BRANCH_NAME` | Which branch was deployed |
| `WORKFLOW_NAME` | Which workflow triggered it |
| `COMMIT_SHA` | Exact commit deployed |
| `DEPLOYMENT_STATUS` | success / failure |
| `TRIGGERED_BY` | Who triggered (user or automation) |
| `TRIGGER_EVENT` | push / pull_request / workflow_dispatch |
| `ERROR_MESSAGE` | Failure details if applicable |

**`MEDICAL.AUDIT.DEPLOYMENT_HISTORY_DBT_MODEL`**

Tracks each individual dbt model execution, linked back to the GitHub Actions run:

| Column | Description |
|---|---|
| `MODEL_EXECUTION_ID` | Auto-increment PK |
| `GH_RUN_ID` | FK to the GitHub Actions run |
| `DBT_MODEL_NAME` | Which dbt model ran |
| `QUERY_START_TIME` | Execution start |
| `QUERY_END_TIME` | Execution end |
| `DEPLOYMENT_STATUS` | Model-level status |

This two-table audit design gives you full traceability: from a GitHub commit → to a workflow run → to individual model execution.

### 7. GCS External Stage for Raw Data Ingestion

Raw data is not seeded from local CSVs. Instead, a Snowflake **STORAGE INTEGRATION** (`gcs_int`) is configured to connect to a GCS bucket (`gcs://snowflake_cicd`). A named stage (`medical_stage`) is created on top of it, and `COPY INTO` commands load:

- `raw_doctors` from `@medical_stage/raw_doctors/`
- `raw_patients` from `@medical_stage/raw_patients_initial/`
- `raw_visits` from `@medical_stage/raw_visits_initial/`

This is the cloud-native pattern for Snowflake data ingestion — no local file dependencies.

### 8. Fully Pinned Dependencies

The `requirements.txt` contains **83 pinned packages** (including transitive dependencies), ensuring that every CI run — regardless of when it runs — uses the exact same library versions. This prevents the classic "it worked last week" class of failures.

Key packages pinned:

```
dbt-core==1.11.11
dbt-snowflake==1.9.0
sqlfluff==4.2.1
sqlfluff-templater-dbt==4.2.1
snowflake-connector-python==3.18.0
boto3==1.43.16
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        GitHub Repository                        │
│                                                                 │
│   Developer → Feature Branch → Pull Request → prod branch       │
│                                                                 │
│   .github/workflows/                                            │
│     ├── ci.yml   ← triggers on PR    (lint + dbt run on DEV)   │
│     └── cd.yml   ← triggers on merge (terraform + dbt on PROD) │
└────────────────────────┬────────────────────────────────────────┘
                         │  GitHub Actions Runner
                         │
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
  ┌─────────────┐ ┌────────────┐ ┌──────────────┐
  │  SQLFluff   │ │  Terraform │ │     dbt      │
  │  (Lint SQL) │ │  (IaC)     │ │  (Transform) │
  └──────┬──────┘ └─────┬──────┘ └──────┬───────┘
         │              │               │
         └──────────────┼───────────────┘
                        ▼
         ┌──────────────────────────────┐
         │         Snowflake            │
         │                              │
         │  DATABASE: MEDICAL           │
         │  ├── SCHEMA: RAW             │◄── GCS External Stage
         │  │     ├── raw_doctors       │    (snowflake_cicd bucket)
         │  │     ├── raw_patients      │
         │  │     └── raw_visits        │
         │  │                           │
         │  ├── SCHEMA: DEV             │◄── CI runs (per PR)
         │  ├── SCHEMA: TEST            │◄── QA layer
         │  ├── SCHEMA: PROD            │◄── CD deploys
         │  │                           │
         │  └── SCHEMA: AUDIT           │
         │        ├── DEPLOYMENT_HISTORY_GITHUB_ACTION
         │        └── DEPLOYMENT_HISTORY_DBT_MODEL
         └──────────────────────────────┘
```

### Data Flow

```
GCS Bucket
    │
    │  COPY INTO (Snowflake External Stage)
    ▼
MEDICAL.RAW
 (raw_doctors, raw_patients, raw_visits)
    │
    │  dbt models
    ▼
MEDICAL.DEV / MEDICAL.PROD
 (staging → intermediate → marts)
    │
    │  dbt macros inject audit inserts
    ▼
MEDICAL.AUDIT
 (full deployment traceability)
```

---

## Repository Structure

```
snowflake_CI_CD_DBT/
├── .github/
│   └── workflows/           # GitHub Actions CI & CD pipelines
├── dbt_project/             # dbt models, macros, tests, configs
│   ├── models/
│   │   ├── staging/         # Clean raw source tables
│   │   ├── intermediate/    # Business logic joins
│   │   └── marts/           # Analytical layer (facts & dims)
│   ├── macros/              # Reusable Jinja macros (incl. audit logging)
│   ├── tests/               # Custom data quality tests
│   └── dbt_project.yml      # Project configuration
├── terraform/               # Snowflake IaC (databases, schemas, roles)
├── RAW_STAGE.sql            # One-time raw setup + audit table DDL
├── ROLE_AND_USER.sql        # RBAC setup for dbt + Terraform users
├── commands.sql             # Local developer quickref commands
└── requirements.txt         # 83 pinned Python dependencies
```

---

## Getting Started

### Prerequisites

- Python 3.9+
- A Snowflake account
- Terraform CLI
- A GCS bucket (for the external stage)
- GitHub repository with Actions enabled

### Step 1: Snowflake Setup

Run the setup scripts in order in your Snowflake account (as `ACCOUNTADMIN`):

```sql
-- 1. Create roles, users, databases, schemas, and grants
-- Execute: ROLE_AND_USER.sql

-- 2. Create raw tables, external stage, and audit tables
-- Execute: RAW_STAGE.sql
```

### Step 2: Configure GitHub Secrets

Add the following secrets to your GitHub repository (`Settings → Secrets → Actions`):

| Secret | Description |
|---|---|
| `SNOWFLAKE_ACCOUNT` | Your Snowflake account identifier |
| `SNOWFLAKE_USER` | `dbt_test_user` |
| `SNOWFLAKE_PASSWORD` | Password for the dbt service user |
| `SNOWFLAKE_ROLE` | `TRANSFORM` |
| `SNOWFLAKE_DATABASE` | `MEDICAL` |
| `SNOWFLAKE_WAREHOUSE` | `COMPUTE_WH` |
| `TF_VAR_snowflake_password` | Terraform user password |

### Step 3: Python Environment

```bash
python -m venv venv
source venv/bin/activate        # macOS/Linux
# venv\Scripts\activate         # Windows

pip install -r requirements.txt
```

### Step 4: dbt Profile

Create `~/.dbt/profiles.yml`:

```yaml
dbt_project:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
      user: dbt_test_user
      password: "{{ env_var('SNOWFLAKE_PASSWORD') }}"
      role: TRANSFORM
      database: MEDICAL
      warehouse: COMPUTE_WH
      schema: DEV
      threads: 4
    prod:
      type: snowflake
      account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
      user: dbt_test_user
      password: "{{ env_var('SNOWFLAKE_PASSWORD') }}"
      role: TRANSFORM
      database: MEDICAL
      warehouse: COMPUTE_WH
      schema: PROD
      threads: 4
```

### Step 5: Provision Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### Step 6: Local Development

```bash
# Lint all models
sqlfluff lint models --dialect snowflake --profiles-dir ~/.dbt

# Auto-fix linting issues
sqlfluff fix models --dialect snowflake --profiles-dir ~/.dbt

# Run all dbt models
dbt run --profiles-dir ~/.dbt

# Run a specific model
dbt run --select fact_visits --profiles-dir ~/.dbt

# Run tests
dbt test --profiles-dir ~/.dbt
```

---

## CI/CD Pipeline Flow

```
Developer opens a Pull Request
        │
        ▼
┌───────────────────────────────────┐
│          CI Pipeline              │
│  1. Install dependencies          │
│  2. SQLFluff lint (blocks on fail)│
│  3. dbt run → MEDICAL.DEV        │
│  4. dbt test                      │
│  5. Write run to AUDIT tables     │
└────────────┬──────────────────────┘
             │  PR passes all checks
             ▼
     Code Review & Approval
             │
             ▼
     Merge to `prod` branch
             │
             ▼
┌───────────────────────────────────┐
│          CD Pipeline              │
│  1. Terraform plan + apply        │
│  2. dbt run → MEDICAL.PROD       │
│  3. dbt test                      │
│  4. Write deployment to AUDIT     │
└───────────────────────────────────┘
```

---

## Tech Stack

| Tool | Version | Role |
|---|---|---|
| **Snowflake** | — | Cloud data warehouse |
| **dbt-core** | 1.11.11 | SQL transformation framework |
| **dbt-snowflake** | 1.9.0 | Snowflake adapter for dbt |
| **Terraform** | — | Infrastructure as Code |
| **SQLFluff** | 4.2.1 | SQL linter and auto-fixer |
| **GitHub Actions** | — | CI/CD automation |
| **Google Cloud Storage** | — | External stage for raw data |
| **Python** | 3.9+ | Runtime for dbt & tooling |

---

## Key Design Decisions

**Why a custom audit table instead of just GitHub logs?**
GitHub Actions logs are ephemeral and not queryable. Storing deployment history in Snowflake means you can join deployment metadata with your data to answer questions like "which models changed in the last 5 deploys?" or "how long does each model take on average?"

**Why Terraform AND manual SQL setup scripts?**
The SQL scripts (`ROLE_AND_USER.sql`, `RAW_STAGE.sql`) serve as the one-time bootstrap for a new Snowflake account. Terraform manages ongoing infrastructure changes idempotently. This is a deliberate separation: bootstrap once, then Terraform owns state.

**Why `LEGACY_SERVICE` user type?**
Snowflake's `LEGACY_SERVICE` user type prevents interactive console logins for the CI/CD service account. This reduces the risk of compromised credentials being used to access the Snowflake UI, while still allowing programmatic access.

---

## Author

**Sourabh Singh Rana**
[github.com/SourabhSinghRana](https://github.com/SourabhSinghRana)
