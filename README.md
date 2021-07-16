# Terraform architecture to put the media files into AWS CloudFront

![N|Solid](https://media-exp3.licdn.com/dms/image/C5612AQEqwmOxJM4mHA/article-cover_image-shrink_720_1280/0/1592150656813?e=1631750400&v=beta&t=yx1pboxCB4ZVPF_-KA3qSSldT3DB_EWCVWgqzhwa6O0)

## Project Description
This project focuses on launching an instance in Amazon AWS Cloud and inside this instance we will be deploying the code sent by developer and as also this code refers to images sent by some developers so using terraform we will deploy the images to an S3 bucket and expose it to all the edge locations using CloudFront .

#### Task Description:-
- Creating the key pairs and downloading the code uploaded by Developers
- Launch the Instance
- In this EC2 instance use the key and security group which we have created in step 1.
- Launch one Volume (EBS) and mount that volume into /var/www/html
- Developer have uploded the code into github repo also the repo has some images.
- Copy the github repo code into /var/www/html
- Create S3 bucket, and copy/deploy the images from github repo into the s3 bucket and change the permission to public readable.
- Create a Cloudfront using s3 bucket(which contains images) and use the Cloudfront URL to update code present in /var/www/html

##### Pre-requisites:
1) AWS CLI software Version 2
2) Terraform CLI (Windows)


**Important Note: Developer should be informed to store every image url of the code in the form of "https://imageurl/image1.jpg", "https://imageurl/image2.jpg" and so on**

#### Step 1: Creating the key pairs and downloading the code uploaded by Developers

The following code I have used to create key pairs (Private/Public) for doing connection to the EC2 instance that is gonna be built by the upcoming code.

In this code I have used "C:/Users/nisha/Desktop/terraform/project/ " as the working directory and so I have redirected the output of key creation command by using null resource and AWS CLI

```sh
resource "null_resource" "key_create"{
  provisioner "local-exec" {
   command = "aws ec2 create-key-pair --key-name aws_terra_key --query KeyMaterial --output text > C:/Users/nisha/Desktop/terraform/project/project/aws_terra_key.pem" 
  }
}
```

Similarly , Let us now download our code from developer to the working directory using null resource and AWS CLI.

```sh
resource "null_resource" "image_file"{
  provisioner "local-exec" {
   command = "git clone https://github.com/SSJNM/php_code.git C:/Users/nisha/Desktop/terraform/project/project/php_code" 
  }
```

We will keep these two things **Keys** and **Code null Resource** to some other location inorder to avoid No File Error thrown by main.tf file.
So we will keep these codes in prerequisites folder as pre.tf file. Therefore, the Setup Should look like this 👇

![N|Solid](https://media-exp3.licdn.com/dms/image/C5612AQE5dTSd3P0zOw/article-inline_image-shrink_1500_2232/0/1592154991805?e=1631750400&v=beta&t=wj8OnrK_96d2L4FcQ-Q2QzjrH2yB8kPzJLSOE4F-rWY)

 Now Run the terraform init command to download the required Plugin To perform the Assigned Task to terraform
 
 ![N|Solid](https://media-exp3.licdn.com/dms/image/C5612AQFzn_MUrDbL5A/article-inline_image-shrink_1500_2232/0/1592155202009?e=1631750400&v=beta&t=ZYmfnLX6e8ytdO1XhpEbjFu3rt3TU72YdG2BnfKWQjg)
 
 After the terraform init command shows Success Message, we will be using terraform validate command to check the errors in the code format

![N|Solid](https://media-exp3.licdn.com/dms/image/C5612AQGmCgK0UWDfyg/article-inline_image-shrink_1500_2232/0/1592155451873?e=1631750400&v=beta&t=bN4rsGjjhfMUM9MviW7Eyk7XWxAOzypVLlITjaioA0Q)

Finally run terraform apply command to run the code to get the key and code (here php_code) in the working directory as below 

![N|Solid](https://media-exp3.licdn.com/dms/image/C5612AQFOITvDMswHhw/article-inline_image-shrink_1500_2232/0/1592155467332?e=1631750400&v=beta&t=m57xq8I3iMd6Orxh7jPz9TGuBPzKebBq17CBFeA-HSI)

#### Step 2: Launch the Instance

We are into the second step and its time to setup our Instance in AWS Cloud. So starting with the  creation of security groups as a firewall for my EC2 instance.


```sh
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
```
Here, I have exposed the port no. 22 for ssh and port no. 80 for exposing http services that will be going to run inside a particular instance.

Starting the EC2 instance using an AMI image for AWS2 and with instance type t2.micro (free) and using our create key-pair and security group

```sh
resource "aws_instance" "myec2" {
  ami             = "ami-07a8c73a650069cf3"
  instance_type   = "t2.micro"
  security_groups  = [ "httpsecuritygroup" ]
  key_name        = "aws_terra_key"


  tags = {
    Name = "aws_terra_ec2"
  }
}
```
Downloading Some important softwares like git , http and php to start the http server inside the instance

```sh
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
```

Now we will be using an extra EBS volume of 1 GB to be mounted on our instance to store the codes given by developer in the directory /var/www/html

*It is important to make EBS in the same availability zone as that of instance

```sh
resource "aws_ebs_volume" "my_pd" {
  availability_zone = aws_instance.myec2.availability_zone
  size              = 1


  tags = {
    Name = "my_pd"
  }


  depends_on = [ aws_instance.myec2 ]  


}
```

Now we will be Attaching the EBS storage by making use of instance ID

```sh
resource "aws_volume_attachment" "ebs_att" {
  device_name  = "/dev/sdh"
  volume_id    = aws_ebs_volume.my_pd.id
  instance_id  = aws_instance.myec2.id
  force_detach = true
  depends_on = [ aws_ebs_volume.my_pd ]
}
```

Here will be using remote execution to login into the launched instance and here we will be formatting the device as /dev/xvdh and mount it to /var/www/html

*It is very important to be noted that due to some internal virtual machine technique on AWS the name of disk is changed from /dev/xvdh from /dev/sdh

```sh
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
```

#### Step 3: Creating the s3 bucket

Generating and Giving the Cannonical ID to get the terraform full control over the S3 storage

So, Creating the S3 bucket and giving the Public Access to EveryBody So, that they can acl can be allowed public-read access

*It is important to ON the force_detach feature otherwise it won't be possible to remove the S3 once Formed



```sh
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
```

By making Use of CloudFront Origin access Identity, we will be able to update The bucket policies so that CloudFront will have access to the Bucket So that objects can be publicised

```sh
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
```

#### Step 4: Creating CloudFront

Finally Creating the CloudFront to make use of all edge Locations for extraction out the BIG SIZED files as a temporary cache

*Origin Id is the Id of the service to be Allowed exposure to edge Location. Here it is the id of S3 Bucket


```sh
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

```

The output of this part should Look like This 👇

![N|Solid](https://media-exp3.licdn.com/dms/image/C5612AQGQfhFiSvLFXQ/article-inline_image-shrink_1500_2232/0/1592158285919?e=1631750400&v=beta&t=NmWGiWvJxEBjVBXfSihFx9KHv2E7SFQgHB2jGtfZryA)

The following code will automatically trigger the browser to launch the server site as a client

```sh
output "IPAddress"{
  value = "${aws_instance.myec2.public_ip}"
}


resource "null_resource" "ip"{
  provisioner "local-exec"{
    command = "microsoftedge ${aws_instance.myec2.public_ip}"
  }
  depends_on = [ null_resource.nullexec4 ]
}
```

![N|Solid](https://media-exp3.licdn.com/dms/image/C5612AQG2qc6xkxsA4g/article-inline_image-shrink_1500_2232/0/1592158620695?e=1631750400&v=beta&t=g8QodJpWd5VZNw_pdILSKto0sTXNN444lHZ6TbSkYYY)

#### Step 5: Updating the CloudFront URL with the native image URLs 

Lastly Its time to upload the image files by Developer on the bucket to be used in CloudFront

**Here is Some manual task , I have to update the aws instance myself so I will be focussing and getting over this Problem**

```sh
resource "aws_s3_bucket_object" "mybucket" {
  bucket = "ssjnm1"
  key    = "image1.jpg"
  acl    = "public-read"
  source = "C:/Users/nisha/Desktop/terraform/project/project/php_code/image1.jpg"
  etag = "${filemd5("C:/Users/nisha/Desktop/terraform/project/project/php_code/image1.jpg")}"
}
```

And the Final OutPut is Here ...........

![N|Solid](https://media-exp3.licdn.com/dms/image/C5612AQEd8w06fPPIpw/article-inline_image-shrink_1500_2232/0/1592158634831?e=1631750400&v=beta&t=GTyRbLKTH7Ujpt9i47fnDBeLsrWUE9OXMlyAasXgyqM)

Hope you all have Liked the project. Thankyou Vimal Sir for assigning this task 😃
