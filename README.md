
# You Can Launch Your  Application On AWS Using EFS  Service In One Single Click !!
## What we are going to do?

### We are going to launch an application on AWS using EFS services (network file storage ) in one single click through terraform code.




# Here the step by step process which is easy to understand.

Step 1: Create a Security group that allows the port 80.</br>

Step 2: Create a keypair

Step 3: Launch EC2 Instance using keypair and security group which we have created in step 1 and step 2.

Step 4: Developer has uploaded the code into GitHub repository also the repository has some images.

Step 5: Launch one Volume using the EFS service and attach it in our VPC, then mount that volume into /var/www/html.Copy the GitHub repo code into  /var/www/html.

Step 6: Create an S3 bucket, and copy/deploy the images from GitHub repo into the S3 bucket and change the permission to public readable.

Step 7: Create a Cloudfront using an S3 bucket(which contains images) and use the Cloudfront URL to update in code in /var/www/html.

### LET'S GET STARTED!!</br>
First of all, We have to know what is the Amazon Elastic File System (EFS) service.</br>
Amazon Elastic File System (Amazon EFS) provides a simple, scalable, fully managed elastic NFS file system for use with AWS Cloud services and on-premises resources.


 It is built to scale on-demand to petabytes without disrupting applications, growing and shrinking automatically as you add and remove files, eliminating the need to provision and manage capacity to accommodate growth.



Now for the launching of application in a single click we have terraform with us so you have to know something about terraform 
Terraform is a tool for building, changing, and versioning infrastructure safely and efficiently. Terraform can manage existing and popular service providers as well as custom in-house solutions.
Configuration files describe to Terraform the components needed to run a single application or your entire datacenter. Terraform generates an execution plan describing what it will do to reach the desired state, and then executes it to build the described infrastructure. 

As the configuration changes, Terraform is able to determine what changed and create incremental execution plans which can be applied.

So First, We create an IAM user in AWS account.

Configure our cmd to work as remote for AWS. After installing awscli and setting up the path variable, open the command prompt and type the below command. 

aws configure --profile abhimanyu
AWS configure

Now start terraform code  

Verify the provider as AWS with profile and region
provider “aws” {
region = “ap-south-1”
profile = “abhimanyu”
}

Step-1: Create a security group that allows port 22 for ssh login and port 80 for HTTP protocol. For this, We have a terraform resource called "aws_security_group". So using this resource we create a security group.

resource "aws_security_group" "task2_securitygroup" {
  name        = "task2_securitygroup"
  description = "Allow http and ssh traffic"

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

ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}





 step 2: Create a key pair and save it to use for the instance login. In the future, we are going to login to the instance so we need a keypair which we can use to login to the instance. For this, we have a terraform resource "tls_private_key".


 resource  "tls_private_key" "task2_key"{

  algorithm  = "RSA"

}



 resource "local_file"  "mykey_file"{
   content  = tls_private_key.task2_key.private_key_pem
   filename = "mykey.pem"
}
 resource "aws_key_pair" "mygenerate_key"{
   key_name = "mykey"
   public_key = tls_private_key.task2_key.public_key_openssh
}



Step 3: In this step, we are going to launch an EC2 instance by the use of key pair and security group which we created in steps 1 and 2.  After launching, login to the instance via ssh . The remote exec provisioner automatically downloads the httpd and git after login.



variable "ami_id" {

  default = "ami-052c08d70def0ac62"

}



resource  "aws_instance" "myos" {
  ami           = var .ami_id
  instance_type = "t2.micro"
  key_name = aws_key_pair.mygenerate_key.key_name 
  security_groups = [aws_security_group.task2_securitygroup.name]
  vpc_security_group_ids = [aws_security_group.task2_securitygroup.id]
  connection {
       type             = "ssh"
       user             = "ec2-user"
       private_key = tls_private_key.task2_key.private_key_pem
       port             = 22
       host             = aws_instance.myos.public_ip
}

    provisioner  "remote-exec" {
                    inline = [
                                "sudo yum install httpd -y",
                                "sudo systemctl start httpd",
                                "sudo systemctl enable httpd",
                                "sudo yum install git -y",
                                "sudo yum install php -y",
                                "sudo yum install amazon-efs-utils -y",
                                "sudo yum install nfs-utils -y"
]
}
    tags = {
           Name = "task2 myos"
    }
}


Step 4: Developer has uploaded the code into GitHub repository also the repository has some images.



Step 5:
5.1 Now we create  EFS. So for creating EFS we have a resource named as "aws_efs_file_system".
resource "aws_efs_file_system" "efs_volume" {
  creation_token = "efs"
  depends_on=[aws_security_group.task2_securitygroup,
  aws_instance.myos]

  tags = {
    Name = "efs_volume"
  }
}


5.2: After EFS created we need to attach it to subnet of VPC . We don't have our own VPC So I am going with default VPC. The resource available for attachment  "aws_efs_mount_target"
Note :-To access your file system, you must create mount targets in same VPC in which you launch your instance. 
resource "aws_efs_mount_target" "mount" {
  depends_on =[aws_efs_file_system.efs_volume]
  file_system_id = aws_efs_file_system.efs_volume.id
  subnet_id      =aws_instance.myos.subnet_id
  security_groups= ["${aws_security_group.task2_securitygroup.id}"]
}
5.3: Now we mount efs to the var/www/html of our instance because this is the folder/file were our all website data present. And last copy the GitHub repo code into /var/www/html.For this terraform have a resource called "null_resource" and a provisionerr remote execution.
resource "null_resource" "null_volume_attach" {
          depends_on =[ aws_efs_mount_target.mount,
          aws_efs_file_system.efs_volume, aws_instance.myos ]

             
connection {
       type             = "ssh"
       user             = "ec2-user"
       private_key = tls_private_key.task2_key.private_key_pem
       port             = 22
       host             = aws_instance.myos.public_ip
}

    provisioner  "remote-exec" {
                    inline = [
                               
                                "sudo chmod ugo+rw /etc/fstab",
                                "sudo echo '${aws_efs_file_system.efs_volume.id}:/ /var/www/html efs tls,_netdev' >> sudo /etc/fstab",
                                "sudo mount -t nfs4 ${aws_efs_mount_target.mount.dns_name}:/ /var/www/html/",
                                "sudo rm -rf /var/www/html/*",
                                "sudo git clone https://github.com/abhimanyuk479810/cloud_computing.git  /var/www/html/",
                                "sudo setenforce 0"
                               
]
}
}
Step 6:
6.1 Create an S3 bucket by using the "aws_s3_bucket" resource.
resource "aws_s3_bucket" "mybucket1" {
  bucket = "abhimanyu0413"
  acl    = "public-read"

  tags = {
    Name        = "taskbucket"
  }
}  

locals {

s3_origin_id = "myS3origin"
}


6.2: Now Copy/deploy the images from GitHub repo into the S3 bucket and change the permission to public readable.

resource "aws_s3_bucket_object" "object" {
  bucket           =  aws_s3_bucket.mybucket1.id
  key                 = "terraform_aws_logo_online.png"
  source            = "https://raw.githubusercontent.com/abhimanyuk479810/cloud_computing/master/terraform_aws_logo_online.p"
  acl                  = "public-read"
  content_type = "image or png"
}



Step 7: Create a Cloudfront using an S3 bucket(which contains images) and use the Cloudfront URL to update in code in /var/www/html. For cloudfront we have a resource called "aws_cloudfront_distribution"
resource "aws_cloudfront_distribution" "s3_dist" {
  origin {
        domain_name =  aws_s3_bucket.mybucket1.bucket_regional_domain_name
         origin_id        =  local.s3_origin_id

         custom_origin_config  {
                   http_port                         =  80
                   https_port                       =  80
                   origin_protocol_policy   = "match-viewer"
                   origin_ssl_protocols       = [ "TLSv1" , "TLSv1.1" , "TLSv1.2" ]
    }
  }

   enabled =  true

 default_cache_behavior {
           
    allowed_methods  = [ "DELETE","GET","HEAD","OPTIONS","PATCH","POST","PUT" ]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

     viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
   
  }


  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

    viewer_certificate  {
            cloudfront_default_certificate = true
  }
}

resource  "null_resource"  "image" {
depends_on = [
       aws_instance.myos,
       aws_efs_mount_target.mount,
       aws_cloudfront_distribution.s3_dist
]

 connection {
         type              =  "ssh"
         user              = "ec2-user"
         private_key  = tls_private_key.task2_key.private_key_pem
         host              =  aws_instance.myos.public_ip
       }

provisioner "remote-exec" {
    inline = [
   
   
      " echo  < 'img noSrc ='https://${aws_cloudfront_distribution.s3_dist.domain_name}/terraform_aws_logo_online.png'>' | sudo tee -a  /var/www/html/index.html"
        ]
      }
}

output "myosip"  {
            value = aws_instance.myos.public_ip
}


Save all the code in one file having the extension ".tf " and run the following command

terraform init
terraform validate
terraform apply -auto-approve




Now you can see in a single click, the whole application launched successfully using EFS service.



If you want to destroy the whole setup, this is also easy for this we have to run a command.
terraform destroy -auto-approve



All file, code and image I uploaded on Github - Click here

That’s all thanks for reading, feel free to give the feedback.
