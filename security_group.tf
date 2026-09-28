# 퍼블릭 서브넷의 실습용 인스턴스에 붙이는 보안 그룹
# - 관리 접속(SSH/RDP): 내 IP(var.my_ip)에서만 허용
# - 웹(HTTP): 인터넷 전체 허용

resource "aws_security_group" "linux_sg" {
  name        = "linux-sg"
  description = "Linux: SSH from my IP, HTTP from anywhere"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "linux-sg"
  }
}

resource "aws_security_group" "windows_sg" {
  name        = "windows-sg"
  description = "Windows: RDP from my IP, HTTP from anywhere"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "RDP"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "windows-sg"
  }
}