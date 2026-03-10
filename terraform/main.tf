resource "aws_s3_bucket" "image_upload_bucket" {
  bucket = var.upload_bucket_name

  tags = {
    Name        = "ImageUploadBucket"
    Environment = "Dev"
  }
}
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.image_upload_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}