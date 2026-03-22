terraform {
  backend "s3" {
    bucket  = "baho-backup-bucket "
    key     = "terraform-state-file/ca-lic-plate"
    region  = "us-west-2"
    encrypt = false
  }
}