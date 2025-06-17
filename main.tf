terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

locals{
  custom_origin_config_defaults = {
    custom_origin_config = {
      http_port = 80
      https_port = 443
      origin_protocol_policy = "match-viewer"#"http-only"  
      origin_ssl_protocols = ["TLSv1.2"]
    }
  }
}

module "cloudfront" {
  source = "terraform-aws-modules/cloudfront/aws"

  aliases = var.aliases
  comment = var.cloudfront_name

  web_acl_id = var.web_acl_id

  tags = {"Name" = var.cloudfront_name}

  enabled = true
  http_version        = "http2and3"
  is_ipv6_enabled     = true
  price_class         = var.price_class  #(200 for middle east)
  retain_on_delete    = false
  wait_for_deployment = false

  create_monitoring_subscription = true
  create_origin_access_control   = false

  default_cache_behavior = {
    target_origin_id       = var.default_origin_id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods  = ["GET", "HEAD", "POST", "PUT", "OPTIONS", "DELETE", "PATCH"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    
    cache_policy_id            = var.cache_policies[var.default_cache_policy]
    origin_request_policy_id   = var.request_policies[var.default_request_policy]

    min_ttl                = 0
    # default_ttl            = 3600
    # max_ttl                = 86400
    compress               = true
    use_forwarded_values   = false

    function_association = var.default_function_association
  }
  
  ordered_cache_behavior = [ 
    for bK,bV in var.cache_behaviors: {
      path_pattern     = bV.path
      compress = true
      allowed_methods  = lookup(bV,"allowed_methods",["GET", "HEAD", "POST", "PUT", "OPTIONS", "DELETE", "PATCH"])
      cached_methods   = lookup(bV,"cached_methods",["GET", "HEAD", "OPTIONS"])
      target_origin_id = lookup(bV,"origin",var.default_origin_id)

      origin_request_policy_id = var.request_policies[lookup(bV,"origin_request_policy",var.default_request_policy)]
      cache_policy_id          = var.cache_policies[lookup(bV,"cache_policy",var.default_cache_policy)]      

      min_ttl                = 0
      # default_ttl            = 3600
      # max_ttl                = 86400
      compress               = true
      viewer_protocol_policy = lookup(bV,"viewer_protocol_policy","redirect-to-https")
      use_forwarded_values   = false

    }
  ]

  create_vpc_origin = var.create_vpc_origin
  vpc_origin = { for vpcoK, vpcoV in var.vpc_origin : vpcoK => merge(
        {
          http_port              = 80
          https_port             = 443
          origin_protocol_policy = "https-only"
          origin_ssl_protocols = {
            items    = ["TLSv1.2"]
            quantity = 1
          }
        },
        vpcoV)
      } 


  origin = merge({
      for oK,oV in var.origins: oK => merge( { "origin_id" = oK }, oV ) if length(keys(lookup(oV, "vpc_origin_config", {}))) > 0
    },{
      for oK,oV in var.origins: oK => merge( local.custom_origin_config_defaults, { "origin_id" = oK }, oV) if lookup(oV,"vpc_origin_config",false) == false
    })

  viewer_certificate = {
    acm_certificate_arn = var.certificate_arn
    ssl_support_method  = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  # logging_config = {
  #   bucket = module.log_bucket.s3_bucket_bucket_domain_name
  #   prefix = "cloudfront"
  # }

}


data "aws_cloudfront_log_delivery_canonical_user_id" "cloudfront" {}
data "aws_canonical_user_id" "current" {}

# module "log_bucket" {
#   source  = "terraform-aws-modules/s3-bucket/aws"
#   version = "~> 4.0"

#   bucket = format("aws-cloudfront-logs-%s",var.cloudfront_name)

#   control_object_ownership = true
#   object_ownership         = "ObjectWriter"

#   grant = [{
#     type       = "CanonicalUser"
#     permission = "FULL_CONTROL"
#     id         = data.aws_canonical_user_id.current.id
#     }, {
#     type       = "CanonicalUser"
#     permission = "FULL_CONTROL"
#     id         = data.aws_cloudfront_log_delivery_canonical_user_id.cloudfront.id
#     # Ref. https://github.com/terraform-providers/terraform-provider-aws/issues/12512
#     # Ref. https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/AccessLogs.html
#   }]
#   force_destroy = false
# }
