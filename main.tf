terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
# Configure the AWS Provider
provider "aws" {
  region  = "us-west-2"
  access_key = var.AWS_ACCESS_KEY_ID
  secret_key = var.AWS_SECRET_ACCESS_KEY
}

# 1. Create VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "prod-vpc"
  }
}

# 2. Create Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.prod-vpc.id
}

# 3. Create Custom Route Table
resource "aws_route_table" "prod_route_table" {
  vpc_id =  aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }
}

# 4. Create Subnet
resource "aws_subnet" "subnet-1" {
  vpc_id            = aws_vpc.prod-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-west-2a"  # specify your availability zone
}

# 5. Associate Subnet with Route Table
resource "aws_route_table_association" "my_route_table_association" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod_route_table.id
}

# 6. Create Security Group to allow port 22, 80
resource "aws_security_group" "my_sg" {
  vpc_id = aws_vpc.prod-vpc.id

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
    from_port   = 443
    to_port     = 443
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

# 7. Create Network Interface with an IP in the Subnet
resource "aws_network_interface" "my_eni" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]  # specify your private IP
  security_groups = [aws_security_group.my_sg.id]
}

# 8. Assign an Elastic IP to the Network Interface
resource "aws_eip" "my_eip" {
  domain                       = "vpc"
  network_interface         = aws_network_interface.my_eni.id
  associate_with_private_ip = "10.0.1.50"
}

# 9. Create Ubuntu Server and install/enable apache2
resource "aws_instance" "my_ubuntu" {
  ami           = "ami-0aff18ec83b712f05"  # specify the Ubuntu AMI ID for your region
  instance_type = "t2.micro"
  key_name      = "arts-key"  # specify your key pair name

  network_interface {
    network_interface_id = aws_network_interface.my_eni.id
    device_index         = 0
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update
              sudo apt-get install -y apache2
              sudo systemctl enable apache2
              sudo systemctl start apache2
              sudo bash -c 'echo Arts very 1st TF Web Server > /var/www/html/index.html'
            EOF

  tags = {
    Name = "Arts_UbuntuInstance"
  }
}
