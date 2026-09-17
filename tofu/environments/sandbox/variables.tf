variable "aws_region" {
  type        = string
  description = "AWS region for the sandbox environment."
  default     = "us-east-1"
}

variable "aws_profile" {
  type        = string
  description = "Optional named AWS CLI profile. Leave null to use the default credential chain."
  default     = null
  nullable    = true
}

variable "application_name" {
  type        = string
  description = "Elastic Beanstalk application name."
}

variable "environment" {
  type        = string
  description = "Elastic Beanstalk environment name."
}

variable "environment_name" {
  type        = string
  description = "Optional alias for environment. If set, this is the Beanstalk environment name."
  default     = null
  nullable    = true
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type. Sandbox account is Free Tier-restricted, so t3.micro is required here."
  default     = "t3.micro"
}

variable "platform_version" {
  type        = string
  description = "Windows/IIS solution stack name. Null uses platform_name_regex."
  default     = null
  nullable    = true
}

variable "platform_name_regex" {
  type        = string
  description = "Regex for the Windows/IIS solution stack when platform_version is unset."
  default     = "^64bit Windows Server 2022 (.*) running IIS 10.0$"
}

variable "environment_type" {
  type        = string
  description = "SingleInstance or LoadBalanced."
  default     = "SingleInstance"
}

variable "source_bundle_path" {
  type        = string
  description = "Application zip (publish output or Web Deploy package). Null uses sample-app."
  default     = null
  nullable    = true
}

variable "sample_app_artifact" {
  type        = string
  description = "Path to the deployable zip. Alias of source_bundle_path. Null with artifact_format=sample zips sample-app/."
  default     = null
  nullable    = true
}

variable "artifact_format" {
  type        = string
  description = "sample zips sample-app. publish_zip wraps a Matchbook publish output with the proven IIS custom deploy. webdeploy passes a Web Deploy package through unchanged."
  default     = "sample"

  validation {
    condition     = contains(["sample", "publish_zip", "webdeploy"], var.artifact_format)
    error_message = "artifact_format must be sample, publish_zip, or webdeploy."
  }
}

variable "web_config_path" {
  type        = string
  description = "Optional sidecar web.config to overlay onto a publish_zip (the file requested from Matchbook alongside the artifact)."
  default     = null
  nullable    = true
}

variable "health_check_path" {
  type        = string
  description = "ALB health check path when environment_type is LoadBalanced. Expect a health endpoint if Redis is not yet wired."
  default     = "/"
}

variable "app_environment_variables" {
  type        = map(string)
  description = "Config injection for Matchbook (Redis, connection strings). Does not rebuild the Beanstalk environment."
  default     = {}
}

variable "option_settings" {
  type = list(object({
    namespace = string
    name      = string
    value     = string
  }))
  description = "Extra Elastic Beanstalk option settings without editing the module."
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Extra tags merged onto the sandbox defaults (Project, Environment, ManagedBy)."
  default     = {}
}
