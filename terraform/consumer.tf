resource "aws_iam_role" "consumer" {
  name = "git2s3-consumer"

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

resource "aws_iam_role_policy" "consumer_sqs" {
  name = "SQS"
  role = "${aws_iam_role.consumer.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sqs:ReceiveMessage"
      ],
      "Resource": [
        "${aws_sqs_queue.git2s3.arn}"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "invoke_worker" {
  name = "invoke_worker"
  role = "${aws_iam_role.consumer.id}"

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
        "${aws_lambda_function.worker.arn}"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "consumer_basic_execution" {
  role       = "${aws_iam_role.consumer.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "consumer" {
  type        = "zip"
  source_file = "${path.module}/../src/consumer/index.js"
  output_path = "${path.module}/.terraform/archives/consumer.zip"
}

resource "aws_lambda_function" "consumer" {
  filename         = "${data.archive_file.consumer.output_path}"
  function_name    = "git2s3-consumer"
  handler          = "index.handler"
  role             = "${aws_iam_role.consumer.arn}"
  description      = "Consumes SQS asset upload messages and invokes git2s3-workers to process the uploads"
  memory_size      = "128"
  runtime          = "nodejs4.3"
  timeout          = "30"
  source_code_hash = "${data.archive_file.consumer.output_base64sha256}"

  environment {
    variables = {
      AWS_SQS_REGION = "${var.region["sqs"]}"
      QUEUE_URL      = "https://sqs.${var.region["sqs"]}.amazonaws.com/${var.account_id}/${aws_sqs_queue.git2s3.name}"
    }
  }
}

resource "aws_lambda_permission" "cloudwatch" {
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.consumer.function_name}"
  principal     = "events.amazonaws.com"
  statement_id  = "AllowExecutionFromCloudwatchEvent"
  source_arn    = "${aws_cloudwatch_event_rule.consumer.arn}"
}

resource "aws_cloudwatch_event_rule" "consumer" {
  name                = "git2s3"
  description         = "Invoke the git2s3-consumer Lambda function to process git2s3 asset upload messages from SQS"
  schedule_expression = "rate(1 minute)"
  is_enabled          = true
}

resource "aws_cloudwatch_event_target" "consumer" {
  rule = "${aws_cloudwatch_event_rule.consumer.name}"
  arn  = "${aws_lambda_function.consumer.arn}"
}
