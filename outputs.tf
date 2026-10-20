output "linux_public_ip" {
  value = aws_instance.linux.public_ip
}

output "linux_ssh_command" {
  value = "ssh -i ${var.linux_key_name}.pem ec2-user@${aws_instance.linux.public_ip}"
}

output "windows_public_ip" {
  value = one(aws_instance.windows[*].public_ip)
}

# 비밀번호를 state에 남기지 않도록 복호화는 로컬에서 AWS CLI로 수행
output "windows_password_command" {
  value = var.enable_windows ? "aws ec2 get-password-data --instance-id ${aws_instance.windows[0].id} --priv-launch-key windows.pem --query PasswordData --output text" : null
}

output "monitoring_public_ip" {
  value = aws_instance.monitoring.public_ip
}

output "monitoring_ssh_command" {
  value = "ssh -i ${var.linux_key_name}.pem ec2-user@${aws_instance.monitoring.public_ip}"
}

output "grafana_url" {
  value = "http://${aws_instance.monitoring.public_ip}:3000"
}

output "prometheus_url" {
  value = "http://${aws_instance.monitoring.public_ip}:9090"
}