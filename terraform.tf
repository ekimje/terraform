terraform {
  # backend "s3"의 use_lockfile은 1.10 이상에서 지원
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.66" # 6.66 이상 7.0 미만
    }
  }
}
