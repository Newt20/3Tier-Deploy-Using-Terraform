variable "project_name"       { type = string }
variable "ami_id"             { type = string }
variable "instance_type"      { type = string }
variable "key_name"           { type = string }
variable "root_volume_size"   { type = number }
variable "public_subnet_ids"  { type = list(string) }
variable "private_subnet_ids" { type = list(string) }
variable "public_sg_id"       { type = string }
variable "private_sg_id"      { type = string }
variable "db_endpoint"        { type = string }
variable "db_name"            { 
  type = string
  default = "nt-db"  
}
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

variable "db_port"            { type = number }
variable "backend_private_ip" {
    type = string  
    default  = "" 
}

variable "db_subnet_ids"     { type = list(string) }
variable "database_sg_id"    { type = string }
variable "db_instance_class" { type = string }
variable "allocated_storage" { type = number }