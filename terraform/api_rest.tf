resource "aws_api_gateway_rest_api" "rest" {
  name = "${var.project_name}-rest"

  tags = {
    Name    = "${var.project_name}-rest"
    Project = var.project_name
  }
}

resource "aws_api_gateway_resource" "rest_proxy" {
  rest_api_id = aws_api_gateway_rest_api.rest.id
  parent_id   = aws_api_gateway_rest_api.rest.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "rest_any" {
  rest_api_id   = aws_api_gateway_rest_api.rest.id
  resource_id   = aws_api_gateway_resource.rest_proxy.id
  http_method   = "ANY"
  authorization = "NONE" # PoC only — 本番では IAM or Lambda authorizer に変更
}

resource "aws_api_gateway_integration" "rest_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.rest.id
  resource_id             = aws_api_gateway_resource.rest_proxy.id
  http_method             = aws_api_gateway_method.rest_any.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.rest_backend.invoke_arn
}

resource "aws_api_gateway_deployment" "rest" {
  rest_api_id = aws_api_gateway_rest_api.rest.id
  depends_on  = [aws_api_gateway_integration.rest_lambda]
}

resource "aws_api_gateway_stage" "rest" {
  rest_api_id   = aws_api_gateway_rest_api.rest.id
  deployment_id = aws_api_gateway_deployment.rest.id
  stage_name    = "dev"

  tags = {
    Name    = "${var.project_name}-rest-dev"
    Project = var.project_name
  }
}

resource "aws_lambda_permission" "rest" {
  statement_id  = "AllowRestAPI"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rest_backend.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.rest.execution_arn}/*/*"
}
