terraform {
  backend "s3" {
    bucket       = "jy-tfstate-0927"
    key          = "aws-lab/terraform.tfstate"
    region       = "ap-northeast-2"
    use_lockfile = true
  }
}