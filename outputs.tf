output "linux_public_ip" {
  value = aws_instance.linux.public_ip
}

output "linux_ssh_command" {
  value = "ssh -i ${var.linux_key_name}.pem ec2-user@${aws_instance.linux.public_ip}"
}

output "windows_public_ip" {
  value = aws_instance.windows.public_ip
}

# 비밀번호를 state에 남기지 않도록 복호화는 로컬에서 AWS CLI로 수행
output "windows_password_command" {
  value = "aws ec2 get-password-data --instance-id ${aws_instance.windows.id} --priv-launch-key ${var.windows_key_name}.pem --query PasswordData --output text"
}
