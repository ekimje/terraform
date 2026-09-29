# 퍼블릭 서브넷1에 Amazon Linux 2023 인스턴스 1대
# - AMI: AWS 공개 SSM 파라미터로 최신 AL2023 조회
# - 접속: ssh -i linux.pem ec2-user@<public_ip>
# - nginx: user_data로 첫 부팅 시 자동 설치 (http://<public_ip>)

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "linux" {
  ami                    = data.aws_ssm_parameter.al2023_ami.insecure_value
  instance_type          = var.linux_instance_type
  subnet_id              = aws_subnet.public_subnet1.id
  vpc_security_group_ids = [aws_security_group.linux_sg.id]
  key_name               = var.linux_key_name

  # IMDSv2만 허용
  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_type = "gp3"
    encrypted   = true
  }

  # 첫 부팅 시 한 번만 실행: 트러블슈팅 실습용 nginx 설치
  # 실행 로그: /var/log/cloud-init-output.log
  user_data = <<-EOF
    #!/bin/bash
    dnf install -y nginx
    systemctl enable --now nginx
  EOF

  # 새 AMI가 나올 때마다 인스턴스가 재생성되지 않도록 무시
  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name = "linux-ec2"
    OS   = "linux"
  }
}
