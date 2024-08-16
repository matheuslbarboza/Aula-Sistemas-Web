provider "aws" {
  region = "us-west-2"  # Substitua pela sua região
}

# Define o Load Balancer
resource "aws_elb" "main" {
  name               = "pizza-service-lb"
  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]

  listener {
    instance_port     = 80
    instance_protocol = "HTTP"
    port              = 80
    protocol          = "HTTP"
  }

  health_check {
    target              = "HTTP:80/"
    interval            = 30
    timeout             = 5
    healthy_threshold    = 2
    unhealthy_threshold  = 2
  }

  tags = {
    Name = "pizza-service-lb"
  }
}

# Define o API Gateway
resource "aws_api_gateway_rest_api" "api" {
  name = "pizza-service-api"
}

# Define o Cache (Elasticache)
resource "aws_elasticache_cluster" "cache" {
  cluster_id           = "pizza-cache"
  engine               = "redis"
  node_type            = "cache.t2.micro"
  number_of_nodes      = 1
  parameter_group_name = "default.redis3.2"
}

# Define o Bucket S3 para o Order Store
resource "aws_s3_bucket" "order_store" {
  bucket = "pizza-order-store"
}

# Define o DynamoDB para o Order Database
resource "aws_dynamodb_table" "order_db" {
  name           = "OrderDatabase"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "OrderID"

  attribute {
    name = "OrderID"
    type = "S"
  }
}

# Define as funções Lambda
resource "aws_lambda_function" "order_service" {
  function_name = "order-service"
  s3_bucket     = aws_s3_bucket.order_store.bucket
  s3_key        = "lambda/order_service.zip"
  handler       = "index.handler"
  runtime       = "nodejs14.x"
}

resource "aws_lambda_function" "payment_service" {
  function_name = "payment-service"
  s3_bucket     = aws_s3_bucket.order_store.bucket
  s3_key        = "lambda/payment_service.zip"
  handler       = "index.handler"
  runtime       = "nodejs14.x"
}

resource "aws_lambda_function" "notification_service" {
  function_name = "notification-service"
  s3_bucket     = aws_s3_bucket.order_store.bucket
  s3_key        = "lambda/notification_service.zip"
  handler       = "index.handler"
  runtime       = "nodejs14.x"
}

resource "aws_lambda_function" "delivery_service" {
  function_name = "delivery-service"
  s3_bucket     = aws_s3_bucket.order_store.bucket
  s3_key        = "lambda/delivery_service.zip"
  handler       = "index.handler"
  runtime       = "nodejs14.x"
}

# Define as permissões do Lambda para acessar o DynamoDB e S3
resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name   = "lambda_dynamodb_policy"
  role   = aws_iam_role.lambda_execution_role.id
  policy  = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.order_db.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_s3_policy" {
  name   = "lambda_s3_policy"
  role   = aws_iam_role.lambda_execution_role.id
  policy  = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.order_store.arn}/*"
      }
    ]
  })
}

resource "aws_lambda_permission" "allow_api_gateway" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.order_service.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# Criação do API Gateway
resource "aws_api_gateway_resource" "order_resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "order"
}

resource "aws_api_gateway_method" "order_post" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.order_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "order_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.order_resource.id
  http_method = aws_api_gateway_method.order_post.http_method
  type        = "AWS_PROXY"
  integration_http_method = "POST"
  uri         = aws_lambda_function.order_service.invoke_arn
}

output "elb_dns_name" {
  value = aws_elb.main.dns_name
}

output "api_gateway_url" {
  value = "${aws_api_gateway_rest_api.api.endpoint}/${aws_api_gateway_resource.order_resource.path_part}"
}
