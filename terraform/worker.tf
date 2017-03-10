resource "aws_s3_bucket" "releases" {
  bucket = "ctm-releases"
}

resource "aws_iam_role" "worker" {
  name = "git2s3-worker"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "worker_ssm" {
  name = "SSM"
  role = "${aws_iam_role.worker.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameters"
      ],
      "Resource": [
        "arn:aws:ssm:${var.region["default"]}:${var.account_id}:parameter/GitHubWebhookAccessToken"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "worker_s3" {
  name = "S3"
  role = "${aws_iam_role.worker.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:AbortMultipartUpload",
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:PutObjectTagging",
        "s3:PutObjectVersionAcl",
        "s3:PutObjectVersionTagging"
      ],
      "Resource": [
        "arn:aws:s3:::ctm-releases/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "worker_sqs" {
  name = "SQS"
  role = "${aws_iam_role.worker.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sqs:DeleteMessage"
      ],
      "Resource": [
        "${aws_sqs_queue.git2s3.arn}"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "worker_basic_execution" {
  role       = "${aws_iam_role.worker.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "null_resource" "npm_install" {
  provisioner "local-exec" {
    command = "cd ${path.module}/../src/worker && npm install --production"
  }
}

data "archive_file" "worker" {
  depends_on  = ["null_resource.npm_install"]
  type        = "zip"
  source_dir  = "${path.module}/../src/worker"
  output_path = "${path.module}/.terraform/archives/worker.zip"
}

resource "aws_lambda_function" "worker" {
  filename         = "${data.archive_file.worker.output_path}"
  function_name    = "git2s3-worker"
  handler          = "index.handler"
  role             = "${aws_iam_role.worker.arn}"
  description      = "Consumes SQS asset upload messages and invokes git2s3-workers to process the uploads"
  memory_size      = "128"
  runtime          = "nodejs4.3"
  timeout          = "30"
  source_code_hash = "${data.archive_file.worker.output_base64sha256}"

  environment {
    variables = {
      AWS_SQS_REGION = "${var.region["sqs"]}"
      QUEUE_URL      = "https://sqs.${var.region["sqs"]}.amazonaws.com/${var.account_id}/${aws_sqs_queue.git2s3.name}"
    }
  }
}
