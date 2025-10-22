variable "aws_region" {
  type    = string
  default = "us-east-1"
  description = "Región AWS donde se desplegará la instancia"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
  description = "Tipo de instancia EC2"
}

variable "key_name" {
  type        = string
  default     = "mariano.stiepcich"
  description = "Nombre del par de llaves EC2 ya creado en AWS"
}