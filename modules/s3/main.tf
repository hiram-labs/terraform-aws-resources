###########
# s3 bucket
###########
resource "aws_s3_bucket" "website_bucket" {
  bucket        = "${var.project_name}-website-bucket"
  force_destroy = true

  tags = {
    Name = "${var.project_name}-website-bucket"
  }
}
resource "aws_s3_bucket_ownership_controls" "website_bucket_oc" {
  bucket = aws_s3_bucket.website_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
resource "aws_s3_bucket_public_access_block" "website_bucket_pab" {
  bucket = aws_s3_bucket.website_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
resource "aws_s3_bucket_acl" "website_bucket_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.website_bucket_oc,
    aws_s3_bucket_public_access_block.website_bucket_pab,
  ]

  bucket = aws_s3_bucket.website_bucket.id
  acl    = "public-read"
}
resource "aws_s3_bucket_policy" "website_policy" {
  depends_on = [
    aws_s3_bucket_ownership_controls.website_bucket_oc,
    aws_s3_bucket_public_access_block.website_bucket_pab,
  ]

  bucket = aws_s3_bucket.website_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "s3:GetObject"
        Effect    = "Allow"
        Resource  = "${aws_s3_bucket.website_bucket.arn}/*"
        Principal = "*"
      }
    ]
  })
}
resource "aws_s3_bucket_website_configuration" "website_bucket_conf" {
  bucket = aws_s3_bucket.website_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }

  routing_rules = <<EOF
[{
    "Condition": {
        "KeyPrefixEquals": "docs/"
    },
    "Redirect": {
        "ReplaceKeyPrefixWith": ""
    }
}]
EOF
}
