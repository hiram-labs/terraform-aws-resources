###############################################################
# S3 Bucket for Static Website Hosting                        #
#                                                             #
# This S3 bucket is designed to host a static website.        #
# It is configured to allow public read access so that        #
# users can access website content over the internet.         #
# The configuration includes access control, security,        #
# and website-specific settings like index and error pages.   #
###############################################################
resource "aws_s3_bucket" "website_bucket" {
  bucket        = "${var.project_name}-website-bucket"
  force_destroy = true

  tags = {
    Name = "${var.project_name}-website-bucket"
  }
}

###############################################################
# S3 Bucket Ownership Controls                                #
#                                                             #
# Ensures that the bucket owner has full control over         #
# all uploaded objects, even if they are uploaded by          #
# another AWS account.                                        #
###############################################################
resource "aws_s3_bucket_ownership_controls" "website_bucket_oc" {
  bucket = aws_s3_bucket.website_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

###############################################################
# Public Access Block Configuration                           #
#                                                             #
# Disables strict public access restrictions, allowing        #
# objects in the bucket to be publicly accessible. This is    #
# necessary for website hosting but should be used with       #
# caution in production environments.                         #
###############################################################
resource "aws_s3_bucket_public_access_block" "website_bucket_pab" {
  bucket = aws_s3_bucket.website_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

###############################################################
# S3 Bucket ACL (Access Control List)                         #
#                                                             #
# Explicitly grants public read access to objects in the      #
# bucket, ensuring the website content can be accessed        #
# by users over the internet.                                 #
###############################################################
resource "aws_s3_bucket_acl" "website_bucket_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.website_bucket_oc,
    aws_s3_bucket_public_access_block.website_bucket_pab,
  ]

  bucket = aws_s3_bucket.website_bucket.id
  acl    = "public-read"
}

###############################################################
# S3 Bucket Policy for Public Access                          #
#                                                             #
# Defines an S3 bucket policy that allows any user to         #
# retrieve objects (read access) from the bucket. This is     #
# essential for hosting a public website where users can      #
# access content without authentication.                      #
###############################################################
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

###############################################################
# S3 Website Configuration                                    #
#                                                             #
# Configures the S3 bucket to function as a static website,   #
# specifying the index and error pages. Additionally,         #
# defines routing rules for URL redirection.                  #
###############################################################
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
