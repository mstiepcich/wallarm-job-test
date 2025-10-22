output "instance_public_ip" {
  value       = aws_instance.ubuntu_server.public_ip
  description = "Public IP of the Ubuntu server"
}

output "ssh_command" {
  value       = "ssh -i \"Your key location\" ubuntu@${aws_instance.ubuntu_server.public_ip}"
  description = "SSH command to connect to the server"
}
