output "endpoint_url" {
  description = "HTTP URL of the sample application."
  value       = module.beanstalk.endpoint_url
}

output "cname" {
  description = "Public CNAME of the environment."
  value       = module.beanstalk.cname
}

output "environment_id" {
  description = "Elastic Beanstalk environment ID."
  value       = module.beanstalk.environment_id
}

output "platform_version" {
  description = "Windows/IIS solution stack in use."
  value       = module.beanstalk.platform_version
}

output "version_label" {
  description = "Deployed application version."
  value       = module.beanstalk.version_label
}

output "artifact_format" {
  description = "How the source bundle was prepared: sample, publish_zip, or webdeploy."
  value       = var.artifact_format
}

output "environment_name" {
  description = "Elastic Beanstalk environment name."
  value       = local.environment_name
}
