# Website URL: 

output "website_url" {
  description = "Website URL"
  value       = "https://${var.domain_name}"
}

# CloudFront Distribution ID: 

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID for cache invalidation and monitoring"
  value       = aws_cloudfront_distribution.s3_distribution.id
}

# S3 Bucket Name: 

output "s3_bucket_name" {
  description = "S3 bucket name storing website files"
  value       = aws_s3_bucket.mywebsite.id
}

# ACM Certificate ARN: 

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate used by CloudFront"
  value       = aws_acm_certificate.mywebsite.arn
}

# Route53 Zone ID: 

output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = aws_route53_zone.main.zone_id
}

# Route53 Nameservers (CRITICAL - must be updated at domain registrar): 

output "route53_nameservers" {
  description = "Nameservers to update at your domain registrar"
  value       = aws_route53_zone.main.name_servers
}