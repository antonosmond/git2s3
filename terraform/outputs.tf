output "invoke_url" {
  value = "https://${aws_api_gateway_rest_api.git2s3.id}.execute-api.${var.region["default"]}.amazonaws.com/${aws_api_gateway_deployment.git2s3.stage_name}${aws_api_gateway_resource.git2s3.path}"
}
