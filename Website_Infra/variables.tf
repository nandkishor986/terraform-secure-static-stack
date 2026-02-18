variable "bucket_prefix" {
  description = "Prefix for the S3 Bucket Name"
  type = string
}

variable "aws_region" {
  description = "The AWS region to create resources in."
  type        = string
}

variable "domain_name" {
  description = "The domain name for the website"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]\\.[a-zA-Z]{2,}$", var.domain_name))
    error_message = "Domain name must be a valid FQDN (e.g., example.com)."
  }
}

variable "acm_certificate_validation_timeout" {
  description = "Timeout for ACM certificate validation"
  type        = string
}

variable "route53_alias_evaluate_target_health" {
  description = "Whether to evaluate target health for Route53 alias records"
  type        = bool
}

variable "enable_ipv6" {
  description = "Enable IPv6 for CloudFront distribution"
  type        = bool
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "production"
    ManagedBy   = "terraform"
    Project     = "static-website"
  }
}