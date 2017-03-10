data "terraform_remote_state" "github_signature_verifier" {
  backend = "s3"

  config {
    bucket = "ctm-terraform-state"
    key    = "github-signature-verifier/terraform.tfstate"
    region = "eu-west-1"
  }
}
