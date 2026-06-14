data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/src/lambda_function.py"
  output_path = "${path.module}/src/lambda_function.zip"
}

resource "aws_lambda_function" "rest_backend" {
  function_name    = "${var.project_name}-rest-backend"
  runtime          = "python3.13"
  handler          = "lambda_function.lambda_handler"
  role             = aws_iam_role.lambda.arn
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  tags = {
    Name    = "${var.project_name}-rest-backend"
    Project = var.project_name
  }
}

resource "aws_lambda_function" "http_backend" {
  function_name    = "${var.project_name}-http-backend"
  runtime          = "python3.13"
  handler          = "lambda_function.lambda_handler"
  role             = aws_iam_role.lambda.arn
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  tags = {
    Name    = "${var.project_name}-http-backend"
    Project = var.project_name
  }
}
