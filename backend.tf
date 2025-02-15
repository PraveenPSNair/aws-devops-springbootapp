terraform {
  backend "s3" {
    bucket         = "terraformprojectfiles"
    key            = "terraform.tfstate"  # Path to store state file in S3
    region         = "ap-south-1"
    encrypt        = true                 # Enable encryption
    }
}
