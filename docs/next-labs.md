# 다음 실습에 추가하면 좋을 것들

지금의 VPC 네트워크 위에 EC2를 올리고 **Ansible로 설정 관리**를 실습하거나, 다른 AWS 실습으로 넓혀갈 때 추가하면 좋은 항목입니다. 필요한 순서대로 정리했습니다.

> 이 문서의 코드는 **예시**입니다. 기존 `.tf` 파일은 건드리지 않았으니, 쓸 때 새 파일(`sg.tf`, `ec2.tf` 등)로 추가하세요.

---

## 0. 먼저 알아둘 것: Windows에서 Ansible 쓰기

- **Ansible 제어 노드(명령을 내리는 쪽)는 Windows에서 직접 실행되지 않습니다.** WSL(Ubuntu)을 설치해서 그 안에서 실행하세요.
  ```powershell
  wsl --install -d Ubuntu
  ```
  ```bash
  # WSL 안에서
  sudo apt update && sudo apt install -y pipx
  pipx install --include-deps ansible
  pipx inject ansible boto3 botocore   # AWS 동적 인벤토리용
  ansible-galaxy collection install amazon.aws
  ```
- **관리 대상(EC2)** 은 Linux와 Windows 모두 가능합니다.
  - Linux: SSH(22)로 접속하고, 대상 서버에 Python이 필요합니다. Amazon Linux와 Ubuntu에는 기본으로 설치되어 있습니다.
  - Windows: WinRM(5986)이나 SSH로 접속하고, 제어 노드에 `pywinrm`이 필요합니다. 처음이라면 **Linux로 먼저 실습**하는 것을 권장합니다.
- WSL에서 AWS 인증은 Windows 쪽 설정을 그대로 가져다 쓸 수 있습니다.
  ```bash
  mkdir -p ~/.aws && cp /mnt/c/Users/blue2/.aws/{config,credentials} ~/.aws/
  ```

---

## 1. Terraform 쪽에 추가할 것 (Ansible 실습 전 필수)

### 1-1. `outputs.tf`: 만든 리소스의 ID와 IP를 밖으로 꺼내기
Ansible 인벤토리나 다른 Terraform 프로젝트가 이 값을 가져다 씁니다.
```hcl
output "vpc_id"             { value = aws_vpc.main.id }
output "public_subnet_ids"  { value = [aws_subnet.subnet1.id, aws_subnet.subnet2.id] }
output "private_subnet_ids" { value = [aws_subnet.private_subnet1.id, aws_subnet.private_subnet2.id] }
output "nat_public_ip"      { value = aws_eip.nat_eip.public_ip }
```
확인: `terraform output`, 스크립트용: `terraform output -json`

### 1-2. VPC에 DNS 호스트네임 켜기
직접 만든 VPC는 기본값이 꺼져 있어서 EC2에 `ec2-x-x-x-x.ap-northeast-2.compute.amazonaws.com` 같은 퍼블릭 DNS 이름이 붙지 않습니다. 인벤토리에서 호스트 이름을 쓰려면 켜두는 게 좋습니다.
```hcl
# vpc.tf의 aws_vpc.main 안에 추가
enable_dns_support   = true
enable_dns_hostnames = true
```

### 1-3. `variables.tf`: 반복되는 값을 변수로
```hcl
variable "region"        { default = "ap-northeast-2" }
variable "my_ip"         { description = "SSH 허용할 내 공인 IP (예: 1.2.3.4/32)" }
variable "instance_type" { default = "t3.micro" }
variable "os"            { default = "linux" }   # "linux" | "windows"
```
값은 `terraform.tfvars`에 적습니다. `.gitignore`에 `*.tfvars`가 이미 있어서 내 IP 같은 값이 GitHub에 올라가지 않습니다.
- 내 공인 IP 확인: `curl ifconfig.me`

### 1-4. 공통 태그: provider의 `default_tags`
모든 리소스에 자동으로 태그를 붙입니다. 나중에 비용 확인이나 Ansible 그룹 나누기에 쓰입니다.
```hcl
provider "aws" {
  region = "ap-northeast-2"
  default_tags {
    tags = {
      Project   = "aws-lab"
      ManagedBy = "terraform"
    }
  }
}
```

### 1-5. `sg.tf`: 보안 그룹
```hcl
# 배스천(점프 서버): 내 IP에서만 SSH 허용
resource "aws_security_group" "bastion" {
  name   = "bastion-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 프라이빗 서버: 배스천에서 오는 SSH만 허용
resource "aws_security_group" "private" {
  name   = "private-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]   # IP 대신 SG를 참조
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```
- Windows 서버라면 22 대신 RDP 3389와 WinRM 5986을 엽니다.
- `0.0.0.0/0`에 22번을 열면 몇 분 안에 무차별 대입 공격이 들어옵니다. 꼭 내 IP(`/32`)로 제한하세요.

### 1-6. 키 페어
```hcl
resource "aws_key_pair" "lab" {
  key_name   = "aws-lab"
  public_key = file("~/.ssh/aws-lab.pub")   # 공개키만 AWS에 올림
}
```
키 생성: `ssh-keygen -t ed25519 -f ~/.ssh/aws-lab`
- **개인키(`aws-lab`, `*.pem`)는 절대 커밋하지 마세요.** `.gitignore`에 `*.pem`, `*.key`를 추가해 두면 안전합니다.

### 1-7. `ec2.tf`: AMI 조회 + 인스턴스
```hcl
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.subnet1.id          # 퍼블릭
  vpc_security_group_ids = [aws_security_group.bastion.id]
  key_name               = aws_key_pair.lab.key_name
  tags = { Name = "bastion", Role = "bastion" }
}

resource "aws_instance" "web" {
  count                  = 2
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = count.index == 0 ? aws_subnet.private_subnet1.id : aws_subnet.private_subnet2.id
  vpc_security_group_ids = [aws_security_group.private.id]
  key_name               = aws_key_pair.lab.key_name
  tags = { Name = "web-${count.index + 1}", Role = "web" }
}
```
- **`Role` 태그가 중요합니다.** Ansible 동적 인벤토리가 이 태그로 `web`, `db` 같은 그룹을 자동으로 만듭니다.
- 프라이빗 서버에는 퍼블릭 IP가 없으므로 배스천을 거쳐 접속합니다(아래 2-2).

---

## 2. Ansible 실습 구성

### 2-1. 인벤토리: 두 가지 방법

**방법 A: 동적 인벤토리 (권장)**
AWS API로 실행 중인 EC2를 직접 조회합니다. 서버가 늘거나 줄어도 파일을 고칠 필요가 없습니다.
```yaml
# ansible/inventory/aws_ec2.yml  (파일 이름이 aws_ec2.yml로 끝나야 인식됨)
plugin: amazon.aws.aws_ec2
regions:
  - ap-northeast-2
filters:
  tag:Project: aws-lab
  instance-state-name: running
keyed_groups:
  - key: tags.Role        # Role=web → 그룹 "role_web"
    prefix: role
hostnames:
  - private-ip-address
compose:
  ansible_host: private_ip_address
```
확인: `ansible-inventory -i ansible/inventory/aws_ec2.yml --graph`

**방법 B: Terraform이 인벤토리 파일을 직접 생성**
```hcl
resource "local_file" "inventory" {
  filename = "${path.module}/ansible/inventory/hosts.ini"
  content  = <<-EOT
    [bastion]
    ${aws_instance.bastion.public_ip}

    [web]
    %{for ip in aws_instance.web[*].private_ip~}
    ${ip}
    %{endfor~}
  EOT
}
```
동작 원리를 이해하기 쉽지만, `apply`할 때마다 파일이 다시 만들어집니다.

### 2-2. 배스천을 거쳐 프라이빗 서버에 접속
```yaml
# ansible/group_vars/role_web.yml
ansible_user: ec2-user
ansible_ssh_private_key_file: ~/.ssh/aws-lab
ansible_ssh_common_args: >-
  -o ProxyJump=ec2-user@<배스천 퍼블릭 IP>
  -o StrictHostKeyChecking=accept-new
```
연결 테스트: `ansible role_web -m ping`

### 2-3. 추천 폴더 구조
```
aws-lab/
├─ *.tf                  # 인프라 (Terraform)
├─ docs/
└─ ansible/
   ├─ ansible.cfg
   ├─ inventory/aws_ec2.yml
   ├─ group_vars/
   ├─ playbooks/
   │  ├─ site.yml
   │  └─ web.yml         # 예: nginx 설치
   └─ roles/
```
```ini
# ansible/ansible.cfg
[defaults]
inventory         = inventory/aws_ec2.yml
host_key_checking = False
remote_user       = ec2-user
```

### 2-4. 첫 플레이북 예시
```yaml
# ansible/playbooks/web.yml
- hosts: role_web
  become: true
  tasks:
    - name: nginx 설치
      ansible.builtin.dnf:
        name: nginx
        state: present
    - name: nginx 시작
      ansible.builtin.service:
        name: nginx
        state: started
        enabled: true
```
프라이빗 서버의 `dnf install`은 **NAT Gateway를 통해** 인터넷에 나갑니다. 지금 만든 NAT 구성이 여기서 실제로 쓰입니다.

### 2-5. SSH 없이 접속하기: SSM Session Manager (선택)
포트 22를 아예 열지 않고 AWS Systems Manager를 통해 접속하는 방법입니다. 배스천이 필요 없어집니다.
- EC2에 `AmazonSSMManagedInstanceCore` 정책이 붙은 IAM 역할(instance profile)을 연결합니다.
- Ansible에서는 `ansible_connection: amazon.aws.aws_ssm`을 쓰고, 파일 전송용 S3 버킷을 지정합니다.
- 실무에서 많이 쓰는 방식이라 SSH 방식을 해본 뒤에 도전해 보세요.

---

## 3. 다른 실습으로 확장할 때

| 실습 | 지금 네트워크에서 쓰는 부분 | 추가할 리소스 |
|---|---|---|
| 웹 서버 이중화 | 퍼블릭 subnet1·2에 ALB, 프라이빗에 EC2 | `aws_lb`, `aws_lb_target_group`, `aws_lb_listener` |
| 오토 스케일링 | 프라이빗 subnet1·2 | `aws_launch_template`, `aws_autoscaling_group` |
| RDS (MySQL 등) | 프라이빗 subnet1·2 (서로 다른 AZ 2개 필요 → 이미 충족) | `aws_db_subnet_group`, `aws_db_instance`, DB용 SG(3306) |
| NAT 비용 줄이기 | private_rt | `aws_vpc_endpoint` (S3 Gateway 엔드포인트는 **무료**) |
| 트래픽 분석 | VPC | `aws_flow_log` + CloudWatch Logs |
| EKS (쿠버네티스) | 서브넷 4개 모두 | 서브넷에 `kubernetes.io/role/elb` 태그, `aws_eks_cluster` |
| 코드 재사용 | 전체 | `modules/vpc`로 묶고 `module "vpc" { ... }`로 호출 |
| 환경 분리 (dev/prod) | backend | backend `key`를 환경별로 나누거나 `terraform workspace` |

---

## 4. 비용 관리 팁

- **실습이 끝나면 `terraform destroy`.** 지금 구성에서 요금이 나가는 것은 NAT Gateway와 EIP입니다.
- NAT을 필요할 때만 켜려면 변수로 on/off할 수 있습니다.
  ```hcl
  variable "enable_nat" { default = false }

  resource "aws_nat_gateway" "nat_gw" {
    count = var.enable_nat ? 1 : 0
    ...
  }
  ```
  `count`를 쓰면 참조가 `aws_nat_gateway.nat_gw[0].id`로 바뀌니 참조하는 곳도 함께 고쳐야 합니다.
- EC2는 `t3.micro` / `t2.micro`(프리 티어 대상)로 실습하세요. Windows는 라이선스 비용이 추가되고 메모리를 더 씁니다.
- AWS Budgets로 월 $10 같은 알림을 걸어두면 지우는 걸 잊었을 때 메일이 옵니다.

---

## 5. 체크리스트

- [ ] WSL + Ansible 설치
- [ ] `outputs.tf` 추가
- [ ] VPC `enable_dns_hostnames = true`
- [ ] `variables.tf` + `terraform.tfvars` (내 IP)
- [ ] `.gitignore`에 `*.pem`, `*.key` 추가
- [ ] `sg.tf` (배스천 / 프라이빗)
- [ ] 키 페어 생성 + `aws_key_pair`
- [ ] `ec2.tf` (배스천 1대 + web 2대, `Role` 태그)
- [ ] Ansible 동적 인벤토리 → `ansible role_web -m ping`
- [ ] nginx 플레이북 실행
- [ ] `terraform destroy`
