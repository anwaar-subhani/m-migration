output "application_name" {
  description = "Elastic Beanstalk application name."
  value       = aws_elastic_beanstalk_application.this.name
}

output "environment_id" {
  description = "Elastic Beanstalk environment ID."
  value       = aws_elastic_beanstalk_environment.this.id
}

output "environment" {
  description = "Elastic Beanstalk environment name."
  value       = aws_elastic_beanstalk_environment.this.name
}

output "cname" {
  description = "Public CNAME of the environment."
  value       = aws_elastic_beanstalk_environment.this.cname
}

output "endpoint_url" {
  description = "HTTP URL for the environment CNAME."
  value       = "http://${aws_elastic_beanstalk_environment.this.cname}"
}

output "platform_version" {
  description = "Windows/IIS solution stack actually applied to the environment."
  value       = aws_elastic_beanstalk_environment.this.solution_stack_name
}

output "version_label" {
  description = "Deployed application version label."
  value       = aws_elastic_beanstalk_application_version.this.name
}

output "versions_bucket" {
  description = "S3 bucket that stores application versions."
  value       = aws_s3_bucket.versions.id
}
