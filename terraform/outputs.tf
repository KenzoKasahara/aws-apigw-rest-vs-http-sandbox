output "rest_api_url" {
  description = "REST API endpoint URL for latency measurement"
  value       = "${aws_api_gateway_stage.rest.invoke_url}/test"
}

output "http_api_url" {
  description = "HTTP API endpoint URL for latency measurement"
  value       = "${trimsuffix(aws_apigatewayv2_stage.http.invoke_url, "/")}/test"
}
