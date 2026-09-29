# 퍼블릭 서브넷2에 Windows Server 2022 인스턴스 1대
# - AMI: AWS 공개 SSM 파라미터로 최신 Windows Server 2022 조회
# - 접속: RDP(Administrator). 비밀번호는 키 페어 개인키로 복호화 (outputs.tf 참고)
#   부팅 후 비밀번호가 생성되기까지 약 4~5분 걸림

data "aws_ssm_parameter" "windows2022_ami" {
  name = "/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base"
}

resource "aws_instance" "windows" {
  ami                    = data.aws_ssm_parameter.windows2022_ami.insecure_value
  instance_type          = var.windows_instance_type
  subnet_id              = aws_subnet.public_subnet2.id
  vpc_security_group_ids = [aws_security_group.windows_sg.id]
  key_name               = var.windows_key_name

  # IMDSv2만 허용
  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_type = "gp3"
    encrypted   = true
  }

  # 새 AMI가 나올 때마다 인스턴스가 재생성되지 않도록 무시
  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name = "windows-ec2"
    OS   = "windows"
  }
}
