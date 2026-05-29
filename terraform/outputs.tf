output "database_name" {
  value = snowflake_database.medical_db.name
}

output "warehouse_name" {
  value = snowflake_warehouse.compute_wh.name
}

output "role_name" {
  value = snowflake_role.transform_role.name
}