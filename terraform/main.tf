
# S3 BUCKET FOR IMAGE UPLOAD


# This bucket stores the original images uploaded by users
resource "aws_s3_bucket" "image_upload_bucket" {

  # Bucket name comes from variables.tf
  bucket = var.upload_bucket_name

  tags = {
    Name        = "ImageUploadBucket"
    Environment = "Dev"
  }
}

#############################################
# ENABLE VERSIONING FOR UPLOAD BUCKET
#############################################

# Versioning keeps multiple versions of the same file
# Useful for recovery and auditing
resource "aws_s3_bucket_versioning" "versioning" {

  bucket = aws_s3_bucket.image_upload_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

#############################################
# BLOCK PUBLIC ACCESS (SECURITY BEST PRACTICE)
#############################################

resource "aws_s3_bucket_public_access_block" "upload_bucket_block" {

  bucket = aws_s3_bucket.image_upload_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#############################################
# S3 BUCKET FOR OPTIMIZED IMAGES
#############################################

# This bucket stores resized images processed by Lambda
resource "aws_s3_bucket" "optimized_bucket" {

  bucket = "nityam-serverless-optimized-images-001"

  tags = {
    Name        = "OptimizedImageBucket"
    Environment = "Dev"
  }
}

#############################################
# BLOCK PUBLIC ACCESS FOR OPTIMIZED BUCKET
#############################################

resource "aws_s3_bucket_public_access_block" "optimized_bucket_block" {

  bucket = aws_s3_bucket.optimized_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#############################################
# IAM ROLE FOR LAMBDA FUNCTION
#############################################

# This role allows Lambda to access AWS services
resource "aws_iam_role" "lambda_role" {

  name = "image-processing-lambda-role"

  # Trust policy allows Lambda service to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"

      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

#############################################
# ATTACH BASIC LAMBDA EXECUTION POLICY
#############################################

# This policy allows Lambda to write logs to CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_basic_policy" {

  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

#############################################
# ATTACH S3 FULL ACCESS POLICY
#############################################

# Lambda needs access to download and upload images
# (For production use least privilege instead)
resource "aws_iam_role_policy_attachment" "lambda_s3_policy" {

  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

#############################################
# LAMBDA FUNCTION FOR IMAGE PROCESSING
#############################################

# This Lambda resizes images when uploaded to S3
resource "aws_lambda_function" "image_processor" {

  function_name = "image-processing-function"

  runtime = "python3.9"

  # IAM role assigned to Lambda
  role = aws_iam_role.lambda_role.arn

  # Python handler function
  handler = "lambda_function.lambda_handler"

  # Location of zipped Lambda code
  filename = "../lambda/image_processor/image_processor.zip"

  # Ensures Terraform updates Lambda when code changes
  source_code_hash = filebase64sha256("../lambda/image_processor/image_processor.zip")

  # Increase timeout for image processing
  timeout = 30
}

#############################################
# ALLOW S3 TO TRIGGER LAMBDA
#############################################

resource "aws_lambda_permission" "allow_s3" {

  statement_id = "AllowExecutionFromS3"

  action = "lambda:InvokeFunction"

  # Lambda function name
  function_name = aws_lambda_function.image_processor.function_name

  # S3 service is allowed to invoke Lambda
  principal = "s3.amazonaws.com"

  # Restrict trigger to our upload bucket
  source_arn = aws_s3_bucket.image_upload_bucket.arn
}

#############################################
# S3 EVENT NOTIFICATION
#############################################

# When an image is uploaded to S3, trigger Lambda
resource "aws_s3_bucket_notification" "bucket_notification" {

  bucket = aws_s3_bucket.image_upload_bucket.id

  lambda_function {

    lambda_function_arn = aws_lambda_function.image_processor.arn

    # Trigger on any object creation
    events = ["s3:ObjectCreated:*"]
  }

  # Ensure Lambda permission is created first
  depends_on = [aws_lambda_permission.allow_s3]
}
ubuntu@ip-172-31-38-177:~/serverless-image-processing/terraform$ 
