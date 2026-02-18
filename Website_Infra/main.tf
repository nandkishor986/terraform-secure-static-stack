# S3 bucket for static website hosting: 

resource "aws_s3_bucket" "mywebsite" {
  bucket_prefix = var.bucket_prefix
}

# Make S3 Bucket Private:  

resource "aws_s3_bucket_public_access_block" "mywebsite" {
  bucket = aws_s3_bucket.mywebsite.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Origin Access Control for CloudFront (Recommended over OAI): 

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "oac-${var.bucket_prefix}"
  description                       = "OAC for static website"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Bucket Policy for S3 Bucket: 

resource "aws_s3_bucket_policy" "mywebsite" {
  bucket = aws_s3_bucket.mywebsite.id

  depends_on = [ aws_s3_bucket_public_access_block.mywebsite ]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.mywebsite.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.s3_distribution.arn
          }
        }
      }
    ]
  })
}

# Upload website files to S3: 

resource "aws_s3_object" "website_files" {
  for_each = fileset("${path.module}/www", "**/*")

  bucket = aws_s3_bucket.mywebsite.id
  key    = each.value
  source = "${path.module}/www/${each.value}"
  etag   = filemd5("${path.module}/www/${each.value}")
  content_type = lookup({
    "html" = "text/html",
    "css"  = "text/css",
    "js"   = "application/javascript",
    "json" = "application/json",
    "png"  = "image/png",
    "jpg"  = "image/jpeg",
    "jpeg" = "image/jpeg",
    "gif"  = "image/gif",
    "svg"  = "image/svg+xml",
    "ico"  = "image/x-icon",
    "txt"  = "text/plain"
  }, split(".", each.value)[length(split(".", each.value)) - 1], "application/octet-stream")
}

# Route53 Hosted Zone for domain management: 

resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Name = "main-zone"
  }
}

# Route53 A record pointing to CloudFront distribution: 

resource "aws_route53_record" "website" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = var.route53_alias_evaluate_target_health
  }
}

# Route53 AAAA record (IPv6) pointing to CloudFront distribution: 

resource "aws_route53_record" "website_ipv6" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = var.route53_alias_evaluate_target_health
  }
}

# Route53 A record for www subdomain: 

resource "aws_route53_record" "website_www" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = var.route53_alias_evaluate_target_health
  }
}

# Route53 AAAA record for www subdomain (IPv6): 

resource "aws_route53_record" "website_www_ipv6" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = var.route53_alias_evaluate_target_health
  }
}

# ACM Certificate for CloudFront (must be in us-east-1 region): 

resource "aws_acm_certificate" "mywebsite" {
  provider                  = aws.us_east_1
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "website-certificate"
  }
}

# Route53 record for ACM certificate validation: 

resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.mywebsite.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id
}


# Wait for certificate validation: 

resource "aws_acm_certificate_validation" "mywebsite" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.mywebsite.arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation : record.fqdn]

  timeouts {
    create = var.acm_certificate_validation_timeout
  }

  depends_on = [aws_route53_record.acm_validation]
}


# CloudFront Distribution for S3 Origin with HTTPS: 

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.mywebsite.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.mywebsite.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  enabled             = true
  is_ipv6_enabled     = var.enable_ipv6
  default_root_object = "index.html"

  aliases = [
    var.domain_name,
    "www.${var.domain_name}"
  ]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.mywebsite.id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
  }

  ordered_cache_behavior {
    path_pattern     = "/static/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.mywebsite.id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.mywebsite.arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }

  custom_error_response {
    error_code            = 404
    error_caching_min_ttl = 300
    response_code         = 404
    response_page_path    = "/404.html"
  }

  custom_error_response {
    error_code            = 403
    error_caching_min_ttl = 300
    response_code         = 403
    response_page_path    = "/index.html"
  }

  http_version = "http2and3"

  depends_on = [aws_acm_certificate_validation.mywebsite]

  tags = {
    Name = "website-distribution"
  }
}