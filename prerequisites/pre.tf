provider "aws" {
  region  = "ap-south-1"
  profile = "default"
}


#Lets create a key to cloud

resource "null_resource" "key_create"{
  provisioner "local-exec" {
   command = "aws ec2 create-key-pair --key-name aws_terra_key --query KeyMaterial --output text > C:/Users/nisha/Desktop/terraform/project/project/aws_terra_key.pem" 
  }
}

#Now lets download image from Github

resource "null_resource" "image_file"{
  provisioner "local-exec" {
   command = "git clone https://github.com/SSJNM/php_code.git C:/Users/nisha/Desktop/terraform/project/project/php_code" 
  }
}
