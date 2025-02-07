variable "output_bucket_name" {
  description = "The name of the S3 bucket for Lambda output."
  default     = "mbm-aws-activity-athena-logs-from-lambda"
}

variable "glue_database" {
  description = "The name of the Glue database."
  default     = "mbm_database_awsactivities"
}

variable "glue_table" {
  description = "The name of the Glue table."
  default     = "mbm_athena_table_awsactivities"
}

