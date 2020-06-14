


#Now lets add the GitHub photos
  
resource "aws_s3_bucket_object" "mybucket" {
  bucket = "ssjnm1"
  key    = "image1.jpg"
  acl    = "public-read"
  source = "C:/Users/nisha/Desktop/terraform/project/project/php_code/image1.jpg"
  etag = "${filemd5("C:/Users/nisha/Desktop/terraform/project/project/php_code/image1.jpg")}"
}

resource "null_resource" "nullexec4" {
  provisioner "remote-exec"{
    inline = [
    "cat /var/www/html/index.php | tr 'image1url' '${aws_cloudfront_distribution.s3_distribution.domain_name}' > /var/www/html/index.php" ,
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("C:/Users/nisha/Desktop/terraform/project/project/aws_terra_key.pem")
      host        = aws_instance.myec2.public_ip
    }
  }
  depends_on = [ aws_s3_bucket_object.mybucket ]
}

output "IPAddress"{
  value = aws_instance.myec2.public_ip
}

resource "null_resource" "ip"{
  provisioner "local-exec"{
    command = "microsoftedge ${aws_instance.myec2.public_ip}"
  }
  depends_on = [ null_resource.nullexec4 ]
}