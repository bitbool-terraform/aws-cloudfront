variable "aliases" {}

variable "origins" { default = {} }

variable "default_request_policy" { default = "UserAgentRefererHeaders" }
variable "default_cache_policy"   { default = "CachingDisabled" }
variable "default_function_association" { default = null}

variable "cache_behaviors" {}

variable "cloudfront_name" {}

variable "request_policies" {}

variable "cache_policies" {}

variable "certificate_arn" {}

variable "price_class" { default = "PriceClass_100" }

variable "create_vpc_origin" { default = false }
variable "vpc_origin" { default = {} }

variable "default_origin_id" {}

variable "web_acl_id" { default = null }

variable "allowed_methods" { default = ["GET", "HEAD", "POST", "PUT", "OPTIONS", "DELETE", "PATCH"] }