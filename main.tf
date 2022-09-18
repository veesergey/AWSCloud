terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.30.0"
    }
    vault = {
      source = "hashicorp/vault"
      version = "3.8.2"
    }
  }
}

provider "vault" {
  address = "https://c797-98-62-197-204.ngrok.io"
  add_address_to_env = "true"
}

//The role is defined in vault, creates temporary credentials
data "vault_aws_access_credentials" "creds" {
  backend = "aws"
  role    = "aws-deploy"
  
}

provider "aws" {
  access_key = data.vault_aws_access_credentials.creds.access_key
  secret_key = data.vault_aws_access_credentials.creds.secret_key
  region     = "us-east-1"
}

# Specifies whats being created. In this case its a linux EC2 instance.
# It also adds a security group. Notice that the security group is added to the instance despite it being
# defined further down. Terraform automatically figures out the relationship in dependencies and will know
# that it must create the security group first, and then add it to the instance.

resource "aws_instance" "linux2" {
    ami = "ami-0a887e401f7654935"
    instance_type = "t2.micro"
    security_groups = ["allow_ssh_http"]
    tags = {
        Name = "Linux EC2"
    }
}

resource "aws_s3_bucket" "theBucket" {
   bucket = "veesergey-An-S3-Bucket"
   versioning {
      enabled = true
   }
   tags = {
     Name        = "VeesergeyBucket"
     Environment = "DEV"
     Purpose     = "Testing"
   }
}

resource "aws_s3_bucket_acl" "privateACL" {
  bucket = aws_s3_bucket.theBucket.id
  acl    = "private"
}

# This is the creation of the security group. There are two outbound rules that are being created.
# One rule allows all internet traffic connection, the other allows SSH connections
resource "aws_security_group" "ssh_http" {
    name = "allow_ssh_http"
    description = "Allows incoming SSH connection to port 22 and http for port 80."

  ingress {
      description = "Allows SSH connections (linux)"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allows Internet traffic connections"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

}
