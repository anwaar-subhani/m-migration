application_name = "matchbook-dotnet48-sample"
environment      = "mb-dotnet48-sandbox"
instance_type    = "t3.micro"
platform_version = "64bit Windows Server 2022 v2.23.4 running IIS 10.0"
aws_region       = "us-east-1"
environment_type = "SingleInstance"
artifact_format  = "sample"

# --- Artifact substitution (do not rebuild the module) ---
# Proven 2026-09-17: publish_zip + substitution-test zip on the same environment,
# then restored to sample. See docs/engineering-validation.md.
#
# 1. Drop the zip in artifacts/incoming/
# 2. Uncomment one block, then: tofu apply
#
# Zipped publish output (web.config, bin/, .aspx at zip root):
# artifact_format      = "publish_zip"
# sample_app_artifact  = "../../../artifacts/incoming/private-api-publish.zip"
# web_config_path      = "../../../artifacts/incoming/web.config"
#
# Azure DevOps Web Deploy package (.deploy.cmd / parameters.xml):
# artifact_format      = "webdeploy"
# sample_app_artifact  = "../../../artifacts/incoming/private-api.webdeploy.zip"
#
# Redis is required for Matchbook session activation. A deploy with no backing
# services may only reach a health check; that is expected, not a platform failure.
# health_check_path = "/health"
# environment_type  = "LoadBalanced"
# app_environment_variables = {
#   RedisHost = "example.cache.amazonaws.com"
# }
