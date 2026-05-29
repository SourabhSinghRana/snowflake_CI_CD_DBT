######################################
# DATABASE
######################################

resource "snowflake_database" "medical_db" {
  name = "MEDICAL"
}

######################################
# SCHEMA
######################################

resource "snowflake_schema" "raw_schema" {
  database = snowflake_database.medical_db.name
  name     = "RAW"
}

resource "snowflake_schema" "dev_schema" {
  database = snowflake_database.medical_db.name
  name     = "DEV"
}

resource "snowflake_schema" "prod_schema" {
  database = snowflake_database.medical_db.name
  name     = "PROD"
}

locals {
  schemas = [
    snowflake_schema.raw_schema.name,
    snowflake_schema.dev_schema.name,
    snowflake_schema.prod_schema.name
  ]
}

######################################
# WAREHOUSE
######################################

resource "snowflake_warehouse" "compute_wh" {
  name                = "COMPUTE_WH"
  warehouse_size      = "XSMALL"
  auto_suspend        = 60
  auto_resume         = true
  initially_suspended = true
}

######################################
# ROLE — Fix 1: snowflake_account_role (was deprecated snowflake_role)
######################################

resource "snowflake_account_role" "transform_role" {
  name = "TRANSFORM"
}

######################################
# USER
######################################

resource "snowflake_user" "dbt_test_user" {
  name              = "DBT_TEST_USER"
  password          = var.snowflake_password
  default_role      = snowflake_account_role.transform_role.name
  default_warehouse = snowflake_warehouse.compute_wh.name
  default_namespace = "MEDICAL.PROD"
}

######################################
# GRANTS
######################################

resource "snowflake_grant_account_role" "grant_role_to_user" {
  role_name = snowflake_account_role.transform_role.name
  user_name = snowflake_user.dbt_test_user.name
}

resource "snowflake_grant_privileges_to_account_role" "warehouse_usage" {
  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.transform_role.name

  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.compute_wh.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "database_usage" {
  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.transform_role.name

  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.medical_db.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "schema_usage" {
  for_each = toset(local.schemas)

  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.transform_role.name

  on_schema {
    schema_name = "${snowflake_database.medical_db.name}.${each.value}"
  }
}

resource "snowflake_grant_privileges_to_account_role" "table_access" {
  for_each = toset(local.schemas)

  privileges        = ["SELECT", "INSERT", "UPDATE", "DELETE"]
  account_role_name = snowflake_account_role.transform_role.name

  on_schema_object {
    all {
      object_type_plural = "TABLES"
      in_schema          = "${snowflake_database.medical_db.name}.${each.value}"
    }
  }
}

# Fix 2: Future tables grant — covers tables created after apply
resource "snowflake_grant_privileges_to_account_role" "future_table_access" {
  for_each = toset(local.schemas)

  privileges        = ["SELECT", "INSERT", "UPDATE", "DELETE"]
  account_role_name = snowflake_account_role.transform_role.name

  on_schema_object {
    future {
      object_type_plural = "TABLES"
      in_schema          = "${snowflake_database.medical_db.name}.${each.value}"
    }
  }
}

######################################
# STORAGE INTEGRATION
######################################

resource "snowflake_storage_integration" "gcs_int" {
  name             = "GCS_INT"
  type             = "EXTERNAL_STAGE"
  storage_provider = "GCS"
  enabled          = true

  storage_allowed_locations = [
    "gcs://snowflake_cicd"
  ]
}

######################################
# STAGE
######################################

resource "snowflake_stage" "medical_stage" {
  name                = "MEDICAL_STAGE"
  database            = snowflake_database.medical_db.name
  schema              = snowflake_schema.raw_schema.name
  url                 = "gcs://snowflake_cicd/"
  storage_integration = snowflake_storage_integration.gcs_int.name
}