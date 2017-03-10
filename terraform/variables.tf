variable "account_id" {
  default = "482506117024"
}

variable "region" {
  default = {
    default = "eu-west-1"
    sqs     = "us-east-2"
  }
}
