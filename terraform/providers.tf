provider "aws" {
  region              = "${var.region["default"]}"
  allowed_account_ids = ["${var.account_id}"]
}

provider "aws" {
  alias               = "sqs"
  region              = "${var.region["sqs"]}"
  allowed_account_ids = ["${var.account_id}"]
}
