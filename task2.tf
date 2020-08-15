provider "aws" {
   region  = "ap-south-1"
   profile  = "abhimanyu"
}

#creating key pair
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



#creating security group
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

# Creating an aws instance by the use of key pair and security group

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

#creating efs 

resource "aws_efs_file_system" "efs_volume" {
  creation_token = "efs"
  depends_on=[aws_security_group.task2_securitygroup,
  aws_instance.myos]

  tags = {
    Name = "efs_volume"
  }
} 

# mount efs on subet in vpc
resource "aws_efs_mount_target" "mount" {
  depends_on =[aws_efs_file_system.efs_volume]
  file_system_id = aws_efs_file_system.efs_volume.id
  subnet_id      =aws_instance.myos.subnet_id
  security_groups= ["${aws_security_group.task2_securitygroup.id}"]
}


#mount efs on var/www/html



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

#creating s3 bucket

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

#putting image inside s3

resource "aws_s3_bucket_object" "object" {
  bucket           =  aws_s3_bucket.mybucket1.id
  key                 = "terraform_aws_logo_online.png"
  source            = "C:/Users/abhimanyu/Desktop/blog/devops/terraform_aws_logo_online.png"
  acl                  = "public-read"
  content_type = "image or png"
}

#creating cloudfront

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


