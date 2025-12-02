output "state_bucket_name" {
  value = aws_s3_bucket.tf_state.bucket
}

output "artifact_bucket_name" {
  value = aws_s3_bucket.artifacts.bucket
}

output "lock_table_name" {
  value = aws_dynamodb_table.locks.name
}

