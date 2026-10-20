resource "aws_instance" "monitoring" {
  ami                    = data.aws_ssm_parameter.al2023_ami.insecure_value
  instance_type          = var.monitoring_instance_type
  subnet_id              = aws_subnet.public_subnet1.id
  vpc_security_group_ids = [aws_security_group.monitoring_sg.id]
  key_name               = var.linux_key_name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = <<-EOF
        #!/bin/bash
        set -e

        # Docker 설치, 실행
        dnf install -y docker
        systemctl enable --now docker
        usermod -aG docker ec2-user          # sudo 없이 docker 명령 쓰기

        # Docker Compose 플러그인 (AL2023 저장소에 없어서 직접 받음)
        mkdir -p /usr/local/lib/docker/cli-plugins
        curl -sSL https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-x86_64 \
        -o /usr/local/lib/docker/cli-plugins/docker-compose
        chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    EOF

  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name = "monitoring-ec2"
  }

}