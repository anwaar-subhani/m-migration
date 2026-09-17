data "aws_elastic_beanstalk_solution_stack" "selected" {
  most_recent = true
  name_regex  = var.platform_name_regex
}

locals {
  solution_stack_name = coalesce(var.platform_version, data.aws_elastic_beanstalk_solution_stack.selected.name)
  version_label       = "app-${substr(filesha256(var.source_bundle_path), 0, 12)}"
  # Prefix elasticbeanstalk- so AWSElasticBeanstalkWebTier's s3:Get* on elasticbeanstalk-* matches.
  versions_bucket     = "elasticbeanstalk-${var.application_name}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "versions" {
  bucket        = local.versions_bucket
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket_public_access_block" "versions" {
  bucket                  = aws_s3_bucket.versions.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "versions" {
  bucket = aws_s3_bucket.versions.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "versions" {
  bucket = aws_s3_bucket.versions.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_object" "source_bundle" {
  bucket                 = aws_s3_bucket.versions.id
  key                    = "${var.application_name}/${local.version_label}.zip"
  source                 = var.source_bundle_path
  etag                   = filemd5(var.source_bundle_path)
  server_side_encryption = "AES256"
  tags                   = var.tags

  depends_on = [aws_s3_bucket_public_access_block.versions]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elastic_beanstalk_application" "this" {
  name        = var.application_name
  description = "Windows IIS application managed by OpenTofu."
  tags        = var.tags
}

resource "aws_elastic_beanstalk_application_version" "this" {
  name        = local.version_label
  application = aws_elastic_beanstalk_application.this.name
  bucket      = aws_s3_bucket.versions.id
  key         = aws_s3_object.source_bundle.key
  tags        = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elastic_beanstalk_environment" "this" {
  name                   = var.environment
  application            = aws_elastic_beanstalk_application.this.name
  solution_stack_name    = local.solution_stack_name
  tier                   = "WebServer"
  wait_for_ready_timeout = "45m"
  version_label          = aws_elastic_beanstalk_application_version.this.name
  tags                   = var.tags

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = var.instance_type
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.ec2.name
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "DisableIMDSv1"
    value     = "true"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "RootVolumeSize"
    value     = tostring(var.root_volume_size)
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "RootVolumeType"
    value     = "gp3"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = var.environment_type
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = aws_iam_role.service.name
  }

  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "SystemType"
    value     = "enhanced"
  }

  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "Timeout"
    value     = "600"
  }

  dynamic "setting" {
    for_each = var.environment_type == "LoadBalanced" ? [1] : []
    content {
      namespace = "aws:elasticbeanstalk:environment"
      name      = "LoadBalancerType"
      value     = var.load_balancer_type
    }
  }

  dynamic "setting" {
    for_each = var.environment_type == "LoadBalanced" ? [1] : []
    content {
      namespace = "aws:elasticbeanstalk:environment:process:default"
      name      = "HealthCheckPath"
      value     = var.health_check_path
    }
  }

  dynamic "setting" {
    for_each = var.app_environment_variables
    content {
      namespace = "aws:elasticbeanstalk:application:environment"
      name      = setting.key
      value     = setting.value
    }
  }

  dynamic "setting" {
    for_each = var.option_settings
    content {
      namespace = setting.value.namespace
      name      = setting.value.name
      value     = setting.value.value
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.ec2_web_tier,
    aws_iam_role_policy_attachment.ec2_ssm,
    aws_iam_role_policy_attachment.service_health,
    aws_iam_role_policy_attachment.service_managed_updates,
    aws_s3_bucket_public_access_block.versions,
  ]
}
