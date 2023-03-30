# Definindo o provedor AWS
provider "aws" {
  region = "us-east-1"
}

# Criando uma tabela DynamoDB
resource "aws_dynamodb_table" "table" {
  name           = "Items"
  billing_mode   = "PAY_PER_REQUEST"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "price"
    type = "N"
  }

  key_schema {
    attribute_name = "id"
    key_type       = "HASH"
  }

  tags = {
    Name = "Table"
  }
}

# Criando uma função Lambda
resource "aws_lambda_function" "function" {
  filename         = "put_item_function.zip"
  function_name    = "put_item_function"
  role             = aws_iam_role.role.arn
  handler          = "put_item_function.handler"
  runtime          = "nodejs14.x"
  source_code_hash = filebase64sha256("put_item_function.zip")

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.table.name
    }
  }

  tags = {
    Name = "Function"
  }
}

# Criando uma política IAM para a função Lambda
resource "aws_iam_policy" "policy" {
  name   = "policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "dynamodb:PutItem"
        ]
        Resource = aws_dynamodb_table.table.arn
      }
    ]
  })
}

# Criando uma regra IAM para a função Lambda
resource "aws_iam_role" "role" {
  name = "role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "Role"
  }
}

# Anexando a política IAM à função Lambda
resource "aws_iam_role_policy_attachment" "policyattachment" {
  policy_arn = aws_iam_policy.policy.arn
  role       = aws_iam_role.role.name
}

# Configurando o API Gateway
resource "aws_api_gateway_rest_api" "api" {
  name        = "api"
  description = " API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name = "API"
  }
}

resource "aws_api_gateway_resource" "resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "resource"
}

resource "aws_api_gateway_method" "method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.resource.id
  http_method   = "POST"
  authorization = "AWS_IAM"
}

resource "aws_api_gateway_integration" "integration" {
  rest_api_id          = aws_api_gateway_rest_api.api.id
  resource_id          = aws_api_gateway_resource.resource.id
  http_method          = aws_api_gateway_method.method.http_method
  integration_http_method = "POST"
  type                 = "AWS_PROXY"
  uri                  = aws_lambda_function.function.invoke_arn
}

resource "aws_api_gateway_method_response" "methodresponse" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.resource.id
  http_method = aws_api_gateway_method.method.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "integrationresponse" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.resource.id
  http_method = aws_api_gateway_method.method.http_method
  status_code = aws_api_gateway_method_response.methodresponse.status_code
  response_templates = {
    "application/json" = ""
  }
}
