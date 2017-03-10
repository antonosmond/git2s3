resource "aws_api_gateway_rest_api" "git2s3" {
  name        = "git2s3"
  description = "Receive GitHub release hooks and upload the release assets to S3"
}

resource "aws_api_gateway_resource" "git2s3" {
  rest_api_id = "${aws_api_gateway_rest_api.git2s3.id}"
  parent_id   = "${aws_api_gateway_rest_api.git2s3.root_resource_id}"
  path_part   = "git2s3"
}

resource "aws_api_gateway_method" "post" {
  rest_api_id   = "${aws_api_gateway_rest_api.git2s3.id}"
  resource_id   = "${aws_api_gateway_resource.git2s3.id}"
  http_method   = "POST"
  authorization = "NONE"

  request_parameters = {
    "method.request.header.X-Hub-Signature" = true
  }
}

resource "aws_api_gateway_integration" "git2s3" {
  rest_api_id             = "${aws_api_gateway_rest_api.git2s3.id}"
  resource_id             = "${aws_api_gateway_resource.git2s3.id}"
  http_method             = "${aws_api_gateway_method.post.http_method}"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.region["default"]}:lambda:path/2015-03-31/functions/${aws_lambda_function.producer.arn}/invocations"
}

resource "aws_api_gateway_deployment" "git2s3" {
  depends_on = [
    "aws_api_gateway_method.post",
    "aws_api_gateway_integration.git2s3",
  ]

  rest_api_id = "${aws_api_gateway_rest_api.git2s3.id}"
  stage_name  = "prod"
}
