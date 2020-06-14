#know your ip

#curl https://checkip.amazonaws.com

#attribute for groupids 
#aws ec2 describe-security-groups --group-names httpsecuritygroup --query "SecurityGroups[0].GroupId" --output > id.txt

provider "aws"{
  region  = "ap-south-1"
  profile = "default"
}

resource "aws_security_group" "httpsecuritygroup" {
  name        = "httpsecuritygroup"
  vpc_id      = "vpc-1e958876"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}


resource "aws_instance" "myec2" {
  ami             = "ami-07a8c73a650069cf3"
  instance_type   = "t2.micro"
  security_groups  = [ "httpsecuritygroup" ]
  key_name        = "aws_terra_key"

  tags = {
    Name = "aws_terra_ec2"
  }
}

resource "null_resource" "nullexec1"{ 
  connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("C:/Users/nisha/Desktop/terraform/project/project/aws_terra_key.pem")
      host        = aws_instance.myec2.public_ip
    }

  provisioner "remote-exec" {
    inline = [
    "sudo yum install httpd php -y",
    "sudo systemctl restart httpd",
    "sudo systemctl enable httpd",
    "sudo yum install git -y",
    ]
  }
  depends_on = [ aws_instance.myec2 ]
}

resource "aws_ebs_volume" "my_pd" {
  availability_zone = aws_instance.myec2.availability_zone
  size              = 1

  tags = {
    Name = "my_pd"
  }

  depends_on = [ aws_instance.myec2 ]  

}

resource "aws_volume_attachment" "ebs_att" {
  device_name  = "/dev/sdh"
  volume_id    = aws_ebs_volume.my_pd.id
  instance_id  = aws_instance.myec2.id
  force_detach = true
  depends_on = [ aws_ebs_volume.my_pd ]
}

resource "null_resource" "nullexec2"{
  provisioner "remote-exec"{
    inline = [
    "sudo mkfs.ext4 /dev/xvdh",
    "sudo mount /dev/xvdh /var/www/html",
    "sudo rm -rf /var/www/html/* ",
    "sudo git clone https://github.com/SSJNM/php_code.git /var/www/html"]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("C:/Users/nisha/Desktop/terraform/project/project/aws_terra_key.pem")
      host        = aws_instance.myec2.public_ip
    }
  }
  depends_on = [ aws_volume_attachment.ebs_att ]  
}

# Creating the s3 bucket

data "aws_canonical_user_id" "current_user" {}

resource "aws_s3_bucket" "mybucket" {
  bucket = "ssjnm1"
  tags = {
    Name        = "ssjnm_bucket"
    Environment = "Dev"
  }
  grant {
    id          = "${data.aws_canonical_user_id.current_user.id}"
    type        = "CanonicalUser"
    permissions = ["FULL_CONTROL"]
  }

  grant {
    type        = "Group"
    permissions = ["READ", "WRITE"]
    uri         = "http://acs.amazonaws.com/groups/s3/LogDelivery"
  }
  force_destroy = true
}
#Public-access Control S3 
 resource "aws_s3_bucket_public_access_block" "example" {
  bucket = "${aws_s3_bucket.mybucket.id}"

  block_public_acls   = false
  block_public_policy = false
  
}




#Making CloudFront Origin access Identity
resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Some comment"
  depends_on = [ aws_s3_bucket.mybucket ]
}

#Updating IAM policies in bucket
data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.mybucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"]
    }
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = ["${aws_s3_bucket.mybucket.arn}"]

    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"]
    }
  }
  depends_on = [ aws_cloudfront_origin_access_identity.origin_access_identity ]
}

#Updating Bucket Policies
resource "aws_s3_bucket_policy" "example" {
  bucket = "${aws_s3_bucket.mybucket.id}"
  policy = "${data.aws_iam_policy_document.s3_policy.json}"
  depends_on = [ aws_cloudfront_origin_access_identity.origin_access_identity ]
}



#Creating CloudFront

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.mybucket.bucket_domain_name
    origin_id   = aws_s3_bucket.mybucket.id
    s3_origin_config {
      origin_access_identity = "${aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path}"
      }
  }
  enabled             = true
  default_root_object = "image1.jpg"
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST",   "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.mybucket.id
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "allow-all"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
  depends_on = [ aws_s3_bucket_policy.example ]
}

output "domain_name" {
 value = aws_cloudfront_distribution.s3_distribution.domain_name
}
