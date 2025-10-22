resource "aws_instance" "ubuntu_server" {
  ami                         = "ami-0360c520857e3138f"  # Ubuntu 24 AMI
  instance_type               = var.instance_type
  subnet_id                   = local.default_subnet_id
  vpc_security_group_ids      = [aws_security_group.ubuntu_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/install.sh", {})
}
