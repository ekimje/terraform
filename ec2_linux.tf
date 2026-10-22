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
  private_ip = "10.0.1.10"
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
    set -e

    # 1. nginx
    dnf install -y nginx

    # 2. nginx 상태 페이지 (exporter만 읽도록 127.0.0.1에서만 열기)
    cat > /etc/nginx/conf.d/stub_status.conf <<'CONF'
    server {
        listen 127.0.0.1:8080;
        location /stub_status {
            stub_status;
        }
    }
    CONF
    systemctl enable --now nginx

    # 3. node_exporter (서버 CPU/메모리/디스크 → 9100)
    NE_VER=1.8.2
    cd /tmp
    curl -sLO https://github.com/prometheus/node_exporter/releases/download/v$NE_VER/node_exporter-$NE_VER.linux-amd64.tar.gz
    tar xzf node_exporter-$NE_VER.linux-amd64.tar.gz
    cp node_exporter-$NE_VER.linux-amd64/node_exporter /usr/local/bin/
    useradd -rs /sbin/nologin node_exporter

    cat > /etc/systemd/system/node_exporter.service <<'UNIT'
    [Unit]
    Description=Node Exporter
    After=network-online.target

    [Service]
    User=node_exporter
    ExecStart=/usr/local/bin/node_exporter
    Restart=always

    [Install]
    WantedBy=multi-user.target
    UNIT

    # 4. nginx exporter (nginx 접속/요청 수 → 9113)
    NX_VER=1.3.0
    curl -sLO https://github.com/nginx/nginx-prometheus-exporter/releases/download/v$NX_VER/nginx-prometheus-exporter_$${NX_VER}_linux_amd64.tar.gz
    tar xzf nginx-prometheus-exporter_$${NX_VER}_linux_amd64.tar.gz
    cp nginx-prometheus-exporter /usr/local/bin/
    useradd -rs /sbin/nologin nginx_exporter

    cat > /etc/systemd/system/nginx_exporter.service <<'UNIT'
    [Unit]
    Description=NGINX Prometheus Exporter
    After=nginx.service

    [Service]
    User=nginx_exporter
    ExecStart=/usr/local/bin/nginx-prometheus-exporter --nginx.scrape-uri=http://127.0.0.1:8080/stub_status
    Restart=always

    [Install]
    WantedBy=multi-user.target
    UNIT

    systemctl daemon-reload
    systemctl enable --now node_exporter nginx_exporter
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
