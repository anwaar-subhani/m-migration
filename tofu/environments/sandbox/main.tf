locals {
  sample_app_dir     = "${path.module}/../../../sample-app"
  wrap_output_path   = "${path.module}/.build/matchbook-bundle.zip"
  environment_name   = coalesce(var.environment_name, var.environment)
  configured_artifact = try(coalesce(var.sample_app_artifact, var.source_bundle_path), null)
  tags = merge({
    Project     = var.application_name
    Environment = "sandbox"
    ManagedBy   = "opentofu"
  }, var.tags)
}

data "archive_file" "sample_app" {
  count       = var.artifact_format == "sample" ? 1 : 0
  type        = "zip"
  source_dir  = local.sample_app_dir
  output_path = "${path.module}/.build/sample-app.zip"
}

data "external" "wrap_publish" {
  count   = var.artifact_format == "publish_zip" ? 1 : 0
  program = ["python3", "${path.module}/../../../scripts/prepare_beanstalk_bundle.py"]

  query = {
    format     = "publish_zip"
    input      = coalesce(local.configured_artifact, "")
    sample_app = abspath(local.sample_app_dir)
    output     = abspath(local.wrap_output_path)
    web_config = var.web_config_path != null ? var.web_config_path : ""
  }
}

locals {
  source_bundle_path = (
    var.artifact_format == "sample" ? data.archive_file.sample_app[0].output_path :
    var.artifact_format == "publish_zip" ? data.external.wrap_publish[0].result.path :
    local.configured_artifact
  )
}

check "matchbook_artifact_present" {
  assert {
    condition     = var.artifact_format == "sample" || (local.configured_artifact != null && local.configured_artifact != "")
    error_message = "Set sample_app_artifact (or source_bundle_path) to the application zip when artifact_format is publish_zip or webdeploy."
  }
}

resource "terraform_data" "require_artifact" {
  count = var.artifact_format == "sample" ? 0 : 1

  input = local.configured_artifact

  lifecycle {
    precondition {
      condition     = local.configured_artifact != null && local.configured_artifact != ""
      error_message = "Set sample_app_artifact (or source_bundle_path) to the application zip when artifact_format is publish_zip or webdeploy."
    }
  }
}

module "beanstalk" {
  source = "../../modules/beanstalk_environment"

  application_name          = var.application_name
  environment               = local.environment_name
  instance_type             = var.instance_type
  platform_version          = var.platform_version
  platform_name_regex       = var.platform_name_regex
  environment_type          = var.environment_type
  health_check_path         = var.health_check_path
  source_bundle_path        = local.source_bundle_path
  app_environment_variables = var.app_environment_variables
  option_settings           = var.option_settings
  tags                      = local.tags
}
