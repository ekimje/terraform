# 리소스 설명서

이 저장소의 Terraform 코드가 만드는 리소스 블록마다 **왜 필요한지**와 **무엇을 참조하고 무엇에게 참조되는지**를 정리한 문서입니다.

- 리전: `ap-northeast-2` (서울)
- 생성되는 리소스: 16개 (`terraform plan` 기준 add 16)
- 버전: Terraform v1.16.4, AWS provider v6.66.0 (`terraform.tf`에서 `~> 6.66`으로 고정)

---

## 1. 전체 구조

```
인터넷
  │
IGW (aws_internet_gateway.igw)
  │
VPC main 10.0.0.0/16
  │
  ├─ [public_rt]  0.0.0.0/0 → IGW
  │    ├─ public_subnet1   10.0.1.0/24  ap-northeast-2a  ← NAT GW + EIP 위치
  │    └─ public_subnet2   10.0.2.0/24  ap-northeast-2b
  │
  └─ [private_rt] 0.0.0.0/0 → NAT GW
       ├─ private_subnet1  10.0.3.0/24  ap-northeast-2a
       └─ private_subnet2  10.0.4.0/24  ap-northeast-2b
```

트래픽 흐름:
- **퍼블릭 서브넷 → 인터넷:** subnet → `public_rt` → IGW → 인터넷
- **프라이빗 서브넷 → 인터넷(나가기만):** private subnet → `private_rt` → NAT GW(public_subnet1 안) → `public_rt` → IGW → 인터넷
- **인터넷 → 프라이빗 서브넷:** 불가능. NAT은 안에서 밖으로 나가는 연결만 허용합니다.

---

## 2. 참조 문법 기초

Terraform에서 다른 리소스 값을 가져오는 형식은 다음과 같습니다.

```
<리소스 타입>.<내가 붙인 이름>.<속성>
aws_vpc      .main           .id
```

| 종류 | 형식 | 예시 |
|---|---|---|
| 리소스 | `타입.이름.속성` | `aws_vpc.main.id` |
| 데이터 소스 | `data.타입.이름.속성` | `data.aws_caller_identity.me.account_id` |
| 변수 | `var.이름` | `var.region` (아직 없음) |
| 로컬 값 | `local.이름` | `local.common_tags` (아직 없음) |

- **참조가 곧 생성 순서입니다.** `aws_subnet.public_subnet1`이 `aws_vpc.main.id`를 참조하면 Terraform은 VPC를 먼저 만들고 서브넷을 나중에 만듭니다. `depends_on`을 따로 쓰지 않아도 됩니다.
- **파일은 구분되지 않습니다.** 같은 폴더의 `.tf` 파일은 모두 하나로 합쳐서 읽힙니다. 그래서 `nat.tf`에서 `vpc.tf`의 `aws_subnet.public_subnet1`을 바로 쓸 수 있습니다. 파일 분리는 사람이 읽기 편하라고 하는 것입니다.
- **이름(`"main"`, `"public_subnet1"`)은 Terraform 안에서만 쓰는 이름입니다.** AWS 콘솔에 보이는 이름은 `tags.Name`입니다.

의존 관계 그래프:

```
aws_vpc.main
 ├─ aws_subnet.public_subnet1 ──┬─ aws_nat_gateway.nat_gw ◄── aws_eip.nat_eip
 ├─ aws_subnet.public_subnet2   │        │
 ├─ aws_subnet.private_subnet1  │        └─ aws_route.private_route
 ├─ aws_subnet.private_subnet2  │                 │
 ├─ aws_internet_gateway.igw ───┼─ aws_route.public_route
 ├─ aws_route_table.public_rt ──┴─ public_rt_assoc1 / public_rt_assoc2
 └─ aws_route_table.private_rt ─── private_rt_assoc1 / private_rt_assoc2
```

직접 그려보려면 `terraform graph`를 실행하세요.

---

## 3. 파일별 설명

### backend.tf

#### `terraform { backend "s3" { ... } }`
- **왜 필요한가:** Terraform은 실제로 만든 리소스의 ID 목록(state)을 기억해야 다음 `plan`에서 비교할 수 있습니다. 이 state를 로컬 파일 대신 S3 버킷 `jy-tfstate-0927`에 저장합니다. PC가 바뀌거나 다른 사람과 같이 작업해도 같은 state를 쓸 수 있습니다.
- `use_lockfile = true`: 두 사람이 동시에 `apply`하지 못하도록 S3에 잠금 파일을 만듭니다. 예전 방식인 DynamoDB 잠금 테이블이 필요 없습니다.
- **참조:** 없습니다. backend 블록에는 변수나 다른 리소스 값을 쓸 수 없습니다(`terraform init` 시점에 먼저 읽히기 때문).
- **주의:** 이 버킷은 Terraform 코드로 만든 게 아니라 미리 만들어 둔 것입니다. `terraform destroy`를 해도 버킷은 지워지지 않고, 지워지면 안 됩니다.

### terraform.tf

#### `terraform { required_version / required_providers }`
- **왜 필요한가:** 코드를 실행할 Terraform과 AWS provider 버전 범위를 고정합니다. 다른 PC에서 `terraform init`을 해도 호환되지 않는 버전(예: AWS provider 7.x)이 설치되지 않습니다.
  - `required_version = ">= 1.10.0"`: backend의 `use_lockfile`이 1.10부터 지원되기 때문입니다.
  - `version = "~> 6.66"`: 6.66 이상 7.0 미만만 허용합니다. 메이저 버전이 바뀌면 `vpc = true` → `domain = "vpc"`처럼 문법이 바뀔 수 있어서 막아 둡니다.
- **`.terraform.lock.hcl`과의 관계:** `required_providers`는 허용 **범위**이고, lock 파일은 실제로 설치된 **정확한 버전**(현재 6.66.0)과 해시를 기록합니다. lock 파일도 git에 커밋해야 모두 같은 버전을 씁니다. 범위 안에서 올리려면 `terraform init -upgrade`를 실행합니다.
- **참조:** 없음. backend와 마찬가지로 변수를 쓸 수 없습니다.

### moved.tf

#### `moved { from = ... to = ... }`
- **왜 필요한가:** `aws_subnet.subnet1/subnet2`를 `public_subnet1/public_subnet2`로 이름을 바꿨습니다. Terraform은 이름으로 리소스를 구분하기 때문에, 그냥 바꾸면 "옛 서브넷 삭제 + 새 서브넷 생성"으로 인식합니다. 그러면 그 안의 NAT Gateway까지 다시 만들어집니다. `moved` 블록은 "같은 리소스인데 이름만 바뀌었다"고 알려줘서 state 주소만 옮깁니다.
- **결과:** 실제 apply에서 `0 added, 2 changed(태그), 0 destroyed`로 처리됐습니다.
- **정리:** 모든 state에 반영된 뒤에는 지워도 됩니다. 이 state를 쓰는 곳이 한 군데뿐이라면 당분간 두었다가 지우면 됩니다.

### main.tf

#### `provider "aws"`
- **왜 필요한가:** 어떤 클라우드의 어느 리전에 만들지 정합니다. 여기서 정한 리전(`ap-northeast-2`)이 모든 리소스에 적용됩니다.
- **참조:** 리소스들이 암묵적으로 사용합니다. 직접 참조하는 코드는 없습니다.

#### `data "aws_caller_identity" "me"` / `output "account_id"` (현재 주석 처리)
- **용도:** 인증된 AWS 계정 ID를 조회해서 출력하는 연결 확인용입니다. 리소스를 만들지 않고 **조회만** 합니다.
- 필요할 때 주석을 풀면 `terraform output account_id`로 계정 ID를 볼 수 있습니다.

### vpc.tf

#### `aws_vpc.main`
- **왜 필요한가:** 모든 네트워크 리소스가 들어갈 격리된 사설 네트워크입니다. `10.0.0.0/16`은 10.0.0.0 ~ 10.0.255.255, 약 65,000개 주소입니다.
- **참조:** 없음 (가장 먼저 만들어지는 리소스)
- **참조되는 곳:** 서브넷 4개, IGW, 라우트 테이블 2개가 모두 `aws_vpc.main.id`를 씁니다.

#### `aws_subnet.public_subnet1` / `aws_subnet.public_subnet2` (퍼블릭)
- **왜 필요한가:** VPC를 더 작게 나눈 구역입니다. EC2 같은 리소스는 VPC가 아니라 서브넷 안에 만들어집니다.
  - 2a, 2b 두 가용 영역(AZ)에 하나씩 둔 이유: 한 데이터센터에 장애가 나도 다른 쪽이 살아 있게 하기 위해서입니다. ALB, RDS 등은 서로 다른 AZ의 서브넷 2개 이상을 요구합니다.
  - `map_public_ip_on_launch = true`: 이 서브넷에 만든 인스턴스에 퍼블릭 IP를 자동으로 붙입니다.
- **"퍼블릭"이 되는 조건:** 서브넷 자체에는 퍼블릭/프라이빗 설정이 없습니다. **IGW로 가는 라우트 테이블이 연결되어 있으면 퍼블릭**입니다. 여기서는 `route.tf`의 association이 그 역할을 합니다.
- **참조:** `aws_vpc.main.id`
- **참조되는 곳:** `public_rt_assoc1/2`, `aws_nat_gateway.nat_gw`(public_subnet1만)

#### `aws_subnet.private_subnet1` / `aws_subnet.private_subnet2` (프라이빗)
- **왜 필요한가:** 인터넷에서 직접 접근하면 안 되는 서버(DB, 내부 애플리케이션)를 두는 곳입니다. 퍼블릭 IP를 붙이지 않고, IGW 대신 NAT으로 가는 라우트 테이블에 연결됩니다.
- **참조:** `aws_vpc.main.id`
- **참조되는 곳:** `private_rt_assoc1/2`

### IGW.tf

#### `aws_internet_gateway.igw`
- **왜 필요한가:** VPC와 인터넷을 잇는 출입구입니다. VPC당 하나만 붙일 수 있습니다. IGW가 있어도 **라우트 테이블에 경로가 없으면 아무 서브넷도 사용하지 못합니다.**
- **참조:** `aws_vpc.main.id`
- **참조되는 곳:** `aws_route.public_route`

### route.tf

#### `aws_route_table.public_rt`
- **왜 필요한가:** 서브넷에서 나가는 트래픽을 어디로 보낼지 정하는 표입니다. 만들 때 VPC 내부 통신 경로(`10.0.0.0/16 → local`)는 자동으로 들어갑니다.
- **참조:** `aws_vpc.main.id`
- **참조되는 곳:** `aws_route.public_route`, `public_rt_assoc1/2`

#### `aws_route.public_route`
- **왜 필요한가:** "VPC 밖으로 가는 모든 트래픽(`0.0.0.0/0`)은 IGW로 보내라"는 경로 한 줄입니다. 이 줄이 있어야 퍼블릭 서브넷이 실제로 인터넷에 연결됩니다.
- **참조:** `aws_route_table.public_rt.id`, `aws_internet_gateway.igw.id`
- **참고:** 라우트 테이블 안에 `route { }` 블록으로 적는 방식도 있습니다. 두 방식을 한 테이블에 섞어 쓰면 서로 덮어쓰니 한 가지만 쓰세요. 지금 코드는 별도 `aws_route` 방식으로 통일되어 있습니다.

#### `aws_route_table_association.public_rt_assoc1` / `public_rt_assoc2`
- **왜 필요한가:** 라우트 테이블을 만든다고 서브넷에 자동으로 적용되지 않습니다. 연결하지 않은 서브넷은 VPC의 기본(main) 라우트 테이블을 쓰는데, 거기엔 IGW 경로가 없습니다.
- **참조:** `aws_subnet.public_subnet1.id` 또는 `aws_subnet.public_subnet2.id`, `aws_route_table.public_rt.id`

### nat.tf

#### `aws_eip.nat_eip`
- **왜 필요한가:** NAT Gateway가 인터넷에 나갈 때 쓸 고정 공인 IP입니다. 프라이빗 서브넷의 서버들이 밖으로 나갈 때 외부에서는 모두 이 IP로 보입니다. 외부 API에 IP 화이트리스트를 등록할 때 유용합니다.
- `domain = "vpc"`: VPC용 EIP라는 뜻입니다. 고정값이며 VPC 이름을 넣는 자리가 아닙니다. (provider v5부터 예전의 `vpc = true` 대신 사용)
- `lifecycle { create_before_destroy = true }`: 교체가 필요할 때 새 EIP를 먼저 만든 뒤 기존 것을 지웁니다.
- **참조:** 없음
- **참조되는 곳:** `aws_nat_gateway.nat_gw`

#### `aws_nat_gateway.nat_gw`
- **왜 필요한가:** 프라이빗 서브넷의 서버가 패키지 설치(`dnf install`, `apt update`)나 외부 API 호출처럼 **밖으로 나가는** 연결만 할 수 있게 해줍니다. 밖에서 안으로 들어오는 연결은 막습니다.
- **퍼블릭 서브넷(public_subnet1)에 두는 이유:** NAT 자신은 IGW를 통해 인터넷에 나가야 하기 때문입니다.
- **참조:** `aws_eip.nat_eip.id`, `aws_subnet.public_subnet1.id`
- **참조되는 곳:** `aws_route.private_route`
- **비용 주의:** 켜져 있기만 해도 시간당 요금(서울 약 $0.059, 월 약 $43)과 데이터 처리 요금이 나갑니다. 실습 후 `terraform destroy`를 잊지 마세요.
- **구조상 한계:** NAT이 2a에만 있습니다. 2a AZ에 장애가 나면 private_subnet2(2b)도 인터넷에 나가지 못합니다. 실습에서는 비용 때문에 1개로 충분하고, 운영 환경에서는 AZ마다 NAT을 하나씩 둡니다.

#### `aws_route_table.private_rt`
- **왜 필요한가:** 프라이빗 서브넷 전용 라우트 테이블입니다. 퍼블릭과 다른 목적지(IGW가 아니라 NAT)로 보내야 하므로 따로 만듭니다.
- **참조:** `aws_vpc.main.id`
- **참조되는 곳:** `aws_route.private_route`, `private_rt_assoc1/2`

#### `aws_route.private_route`
- **왜 필요한가:** "VPC 밖으로 가는 모든 트래픽은 NAT Gateway로 보내라"는 경로입니다.
- **참조:** `aws_route_table.private_rt.id`, `aws_nat_gateway.nat_gw.id`

#### `aws_route_table_association.private_rt_assoc1` / `private_rt_assoc2`
- **왜 필요한가:** 프라이빗 서브넷 두 개를 `private_rt`에 연결합니다.
- **참조:** `aws_subnet.private_subnet1.id` 또는 `aws_subnet.private_subnet2.id`, `aws_route_table.private_rt.id`

---

## 4. 리소스 요약표

| # | 파일 | 리소스 주소 | 참조하는 것 | 과금 |
|---|---|---|---|---|
| 1 | vpc.tf | `aws_vpc.main` | - | 무료 |
| 2 | vpc.tf | `aws_subnet.public_subnet1` | vpc | 무료 |
| 3 | vpc.tf | `aws_subnet.public_subnet2` | vpc | 무료 |
| 4 | vpc.tf | `aws_subnet.private_subnet1` | vpc | 무료 |
| 5 | vpc.tf | `aws_subnet.private_subnet2` | vpc | 무료 |
| 6 | IGW.tf | `aws_internet_gateway.igw` | vpc | 무료 |
| 7 | route.tf | `aws_route_table.public_rt` | vpc | 무료 |
| 8 | route.tf | `aws_route.public_route` | public_rt, igw | 무료 |
| 9 | route.tf | `aws_route_table_association.public_rt_assoc1` | public_subnet1, public_rt | 무료 |
| 10 | route.tf | `aws_route_table_association.public_rt_assoc2` | public_subnet2, public_rt | 무료 |
| 11 | nat.tf | `aws_eip.nat_eip` | - | **유료** (퍼블릭 IPv4 시간당 과금) |
| 12 | nat.tf | `aws_nat_gateway.nat_gw` | eip, public_subnet1 | **유료** |
| 13 | nat.tf | `aws_route_table.private_rt` | vpc | 무료 |
| 14 | nat.tf | `aws_route.private_route` | private_rt, nat_gw | 무료 |
| 15 | nat.tf | `aws_route_table_association.private_rt_assoc1` | private_subnet1, private_rt | 무료 |
| 16 | nat.tf | `aws_route_table_association.private_rt_assoc2` | private_subnet2, private_rt | 무료 |

state에 실제로 들어간 목록은 `terraform state list`, 특정 리소스의 값은 `terraform state show aws_vpc.main`으로 확인합니다.
