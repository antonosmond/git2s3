resource "aws_iam_role" "producer" {
  name = "git2s3-producer"

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

resource "aws_iam_role_policy" "producer_sqs" {
  name = "SQS"
  role = "${aws_iam_role.producer.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sqs:SendMessage"
      ],
      "Resource": [
        "${aws_sqs_queue.git2s3.arn}"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "github_signature_verifier" {
  name = "GitHubSignatureVerifier"
  role = "${aws_iam_role.producer.name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "lambda:InvokeFunction"
      ],
      "Resource": [
        "${data.terraform_remote_state.github_signature_verifier.lambda_function_arn}"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "producer_basic_execution" {
  role       = "${aws_iam_role.producer.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "producer" {
  type        = "zip"
  source_file = "${path.module}/../src/producer/index.js"
  output_path = "${path.module}/.terraform/archives/producer.zip"
}

resource "aws_lambda_function" "producer" {
  filename         = "${data.archive_file.producer.output_path}"
  function_name    = "git2s3-producer"
  handler          = "index.handler"
  role             = "${aws_iam_role.producer.arn}"
  description      = "Receives requests from GitHub release hooks and produces SQS asset upload messages"
  memory_size      = "128"
  runtime          = "nodejs4.3"
  timeout          = "30"
  source_code_hash = "${data.archive_file.producer.output_base64sha256}"

  environment {
    variables = {
      AWS_SQS_REGION                     = "${var.region["sqs"]}"
      GITHUB_SIGNATURE_VERIFIER_FUNCTION = "${data.terraform_remote_state.github_signature_verifier.lambda_function_name}"
      QUEUE_URL                          = "https://sqs.${var.region["sqs"]}.amazonaws.com/${var.account_id}/${aws_sqs_queue.git2s3.name}"
    }
  }
}

resource "aws_lambda_permission" "api_gateway" {
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.producer.function_name}"
  principal     = "apigateway.amazonaws.com"
  statement_id  = "AllowExecutionFromAPIGateway"
  source_arn    = "arn:aws:execute-api:${var.region["default"]}:${var.account_id}:${aws_api_gateway_rest_api.git2s3.id}/${aws_api_gateway_deployment.git2s3.stage_name}/${aws_api_gateway_method.post.http_method}${aws_api_gateway_resource.git2s3.path}"
}
