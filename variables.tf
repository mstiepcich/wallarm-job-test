variable "aws_region" {
  type    = string
  description = "AWS region where the instance will be deployed"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
  description = "EC2 instance type"
}

variable "key_name" {
  type        = string
  description = "Name for the already created EC2 key pair in AWS"
}

variable "wallarm_api_token" {
  type        = string
  description = "WALLARM_API_TOKEN"
}

variable "wallarm_api_host" {
  type        = string
  description = "WALLARM_API_HOST"
}
variable "wallarm_mode" {
  type        = string
  description = "WALLARM_MODE (off, monitoring, safe_blocking or block)"
}
