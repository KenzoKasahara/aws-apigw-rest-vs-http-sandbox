resource "aws_apigatewayv2_api" "http" {
  name          = "${var.project_name}-http"
  protocol_type = "HTTP"

  tags = {
    Name    = "${var.project_name}-http"
    Project = var.project_name
  }
}

resource "aws_apigatewayv2_integration" "http_lambda" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.http_backend.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "http_default" {
  api_id             = aws_apigatewayv2_api.http.id
  route_key          = "$default"
  target             = "integrations/${aws_apigatewayv2_integration.http_lambda.id}"
  authorization_type = "NONE" # PoC only — 本番では JWT or Lambda authorizer に変更
}

resource "aws_apigatewayv2_stage" "http" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true

  tags = {
    Name    = "${var.project_name}-http-default"
    Project = var.project_name
  }
}

resource "aws_lambda_permission" "http" {
  statement_id  = "AllowHttpAPI"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.http_backend.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}
