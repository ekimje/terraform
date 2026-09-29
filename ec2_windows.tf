# 퍼블릭 서브넷2에 Windows Server 2022 인스턴스 1대
# - AMI: AWS 공개 SSM 파라미터로 최신 Windows Server 2022 조회
# - 접속: RDP(Administrator). 비밀번호는 키 페어 개인키로 복호화 (outputs.tf 참고)
#   부팅 후 비밀번호가 생성되기까지 약 4~5분 걸림

# 공개키만 AWS에 등록. 개인키(windows.pem)는 로컬에서 ssh-keygen으로 생성해 보관
#   ssh-keygen -t rsa -b 4096 -m PEM -N "" -f windows.pem
#   (Windows 비밀번호 복호화는 PEM 형식 RSA 키만 지원)
resource "aws_key_pair" "windows" {
  key_name   = "windows-lab"
  public_key = file("${path.module}/keys/windows.pub")
}

data "aws_ssm_parameter" "windows2022_ami" {
  name = "/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base"
}

resource "aws_instance" "windows" {
  ami                    = data.aws_ssm_parameter.windows2022_ami.insecure_value
  instance_type          = var.windows_instance_type
  subnet_id              = aws_subnet.public_subnet2.id
  vpc_security_group_ids = [aws_security_group.windows_sg.id]
  key_name               = aws_key_pair.windows.key_name

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
