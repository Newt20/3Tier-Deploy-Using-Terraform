variable "project_name"      { type = string }
variable "db_subnet_ids"     { type = list(string) }
variable "database_sg_id"    { type = string }
variable "db_engine"         { type = string }
variable "db_engine_version" { type = string }
variable "db_instance_class" { type = string }
variable "db_name"           { type = string }
variable "db_username" {
  description = "Database administrator username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database administrator password"
  type        = string
  sensitive   = true
}
variable "db_port"           { type = number }
variable "allocated_storage" { type = number }
variable "multi_az"          { type = bool }
