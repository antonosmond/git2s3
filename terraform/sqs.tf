resource "aws_sqs_queue" "git2s3_dlq" {
  provider                    = "aws.sqs"
  name                        = "git2s3-dlq.fifo"
  message_retention_seconds   = 604800
  fifo_queue                  = true
  content_based_deduplication = true
}

resource "aws_sqs_queue" "git2s3" {
  provider                   = "aws.sqs"
  name                       = "git2s3.fifo"
  visibility_timeout_seconds = 420
  message_retention_seconds  = 86400

  redrive_policy = <<EOF
{
  "maxReceiveCount": 2,
  "deadLetterTargetArn": "${aws_sqs_queue.git2s3_dlq.arn}"
}
EOF

  fifo_queue                  = true
  content_based_deduplication = true
}
