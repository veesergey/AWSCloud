terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.30.0"
    }
  }
}



provider "vault" {
  address = "https://327d-98-62-197-204.ngrok.io"
  add_address_to_env = "true"
}

data "vault_generic_secret" "aws_keys"{
  path = "secret/aws"
}

// Secret Engine, Issues the temporary AWS access key and secret key.
// Encrypted permanent keys are pulled from Vault and used to generate temporary keys.
resource "vault_aws_secret_backend" "aws" {
  access_key = data.vault_generic_secret.aws_keys.data["aws_access_key"]
  secret_key = data.vault_generic_secret.aws_keys.data["aws_secret_key"]
  path = "aws-path"
  default_lease_ttl_seconds = "600"
  max_lease_ttl_seconds     = "600"
}

// Reads the AWS Credentials for the EC2_Creator Role
data "vault_aws_access_credentials" "creds" {
  backend = "aws-path" //path to aws_secret_backend
  role    = vault_aws_secret_backend_role.EC2_Creator.name
}
// The IAM User Role that actually creates the EC2 instance
resource "vault_aws_secret_backend_role" "EC2_Creator" {
  backend = "aws-path"
  name    = "EC2Creator-role"
  credential_type = "iam_user"
  policy_document = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:*", "ec2:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

output "awsDynamicAccessKey" {
  value = data.vault_aws_access_credentials.creds.access_key
}
output "awsDynamicSecretKey" {
  value = data.vault_aws_access_credentials.creds.secret_key
}

provider "aws" {
  access_key = data.vault_generic_secret.aws_keys.data["aws_access_key"]
  secret_key = data.vault_generic_secret.aws_keys.data["aws_secret_key"]
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
