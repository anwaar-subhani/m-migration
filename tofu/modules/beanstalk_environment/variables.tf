variable "application_name" {
  type        = string
  description = "Elastic Beanstalk application name."
}

variable "environment" {
  type        = string
  description = "Elastic Beanstalk environment name (environment_name). 4-40 chars, letters, numbers, hyphens."

  validation {
    condition     = length(var.environment) >= 4 && length(var.environment) <= 40
    error_message = "environment must be between 4 and 40 characters."
  }
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type. Prefer t3.medium for Windows IIS; use t3.micro only on Free Tier-restricted accounts."
  default     = "t3.micro"
}

variable "platform_version" {
  type        = string
  description = "Windows/IIS Elastic Beanstalk solution stack name. When null, the most recent stack matching platform_name_regex is used."
  default     = null
  nullable    = true
}

variable "platform_name_regex" {
  type        = string
  description = "Regex used to pick the most recent Windows/IIS solution stack when platform_version is null."
  default     = "^64bit Windows Server 2022 (.*) running IIS 10.0$"
}

variable "environment_type" {
  type        = string
  description = "SingleInstance (sandbox default) or LoadBalanced."
  default     = "SingleInstance"

  validation {
    condition     = contains(["SingleInstance", "LoadBalanced"], var.environment_type)
    error_message = "environment_type must be SingleInstance or LoadBalanced."
  }
}

variable "load_balancer_type" {
  type        = string
  description = "Load balancer type when environment_type is LoadBalanced."
  default     = "application"
}

variable "health_check_path" {
  type        = string
  description = "Application health check path. Used when the environment is load balanced. Matchbook Private API may only answer this path until Redis is wired."
  default     = "/"
}

variable "source_bundle_path" {
  type        = string
  description = "Local path to the application zip (sample_app_artifact). Point this at a different .NET 4.8 zip to substitute the sample without rebuilding the module."
}

variable "app_environment_variables" {
  type        = map(string)
  description = "Injected as Elastic Beanstalk environment properties (aws:elasticbeanstalk:application:environment). Use for Redis host, connection strings, and other Matchbook config without rebuilding the environment."
  default     = {}
}

variable "option_settings" {
  type = list(object({
    namespace = string
    name      = string
    value     = string
  }))
  description = "Extra Elastic Beanstalk option settings (IIS, app pool, rolling deploy, and so on). Empty for the sample app."
  default     = []
}

variable "root_volume_size" {
  type        = number
  description = "Root EBS volume size in GiB. Windows Server AMIs need ~30 GiB or more."
  default     = 35
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to created resources."
  default     = {}
}
