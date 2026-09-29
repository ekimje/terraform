variable "my_ip" {
  description = "SSH/RDP 접속을 허용할 내 공인 IP (CIDR, 예: 1.2.3.4/32). 값은 terraform.tfvars에 설정"
  type        = string

  validation {
    condition     = can(cidrhost(var.my_ip, 0)) && endswith(var.my_ip, "/32")
    error_message = "my_ip는 x.x.x.x/32 형식이어야 합니다."
  }
}

variable "linux_instance_type" {
  description = "Linux EC2 인스턴스 타입"
  type        = string
  default     = "t3.micro"
}

variable "windows_instance_type" {
  description = "Windows EC2 인스턴스 타입 (t3.micro는 메모리 1GB라 매우 느림)"
  type        = string
  default     = "t3.small"
}

variable "linux_key_name" {
  description = "Linux EC2에 붙일 기존 키 페어 이름 (AWS 콘솔에서 만든 키)"
  type        = string
  default     = "linux"
}

variable "windows_key_name" {
  description = "Windows EC2에 붙일 기존 키 페어 이름. 비밀번호 복호화에 RSA 개인키(.pem)가 필요"
  type        = string
  default     = "windows"
}
