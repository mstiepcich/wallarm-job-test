resource "aws_instance" "ubuntu_server" {
  ami                         = "ami-0360c520857e3138f"  # Tu AMI
  instance_type               = var.instance_type
  subnet_id                   = local.default_subnet_id
  vpc_security_group_ids      = [aws_security_group.ubuntu_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  tags = {
    Name = "ubuntu-server"
  }
  
  user_data = <<-EOF
              #!/bin/bash
              set -e
              apt-get update -y
              apt-get upgrade -y
              apt-get install -y ca-certificates curl gnupg lsb-release
              mkdir -p /etc/apt/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
              echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
              apt-get update -y
              apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
              usermod -aG docker ubuntu
              apt-get install -y nginx
              systemctl enable nginx
              systemctl start nginx
              EOF
}