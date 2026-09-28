variable "my_ip" {
  description = "SSH/RDP 접속을 허용할 내 공인 IP (CIDR, 예: 1.2.3.4/32). 값은 terraform.tfvars에 설정"
  type        = string

  validation {
    condition     = can(cidrhost(var.my_ip, 0)) && endswith(var.my_ip, "/32")
    error_message = "my_ip는 x.x.x.x/32 형식이어야 합니다."
  }
}
