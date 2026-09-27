terraform {
    backend "s3" {
        bucket = "my-terraform-state-bucket"
        key = "aws-lab/terraform.tfstate"
        region = "ap-northeast-2"
        use_lockfile = true
    }
}