provider "aws"{
  region = "ap-south-1"
  profile = "myprofile"
}

# Generates RSA Keypair
resource "tls_private_key" "key" {
  algorithm   = "RSA"
}
# Upload public key to create keypair on AWS
resource "aws_key_pair" "generatedkey" {
  key_name   = "key3"
  public_key = tls_private_key.key.public_key_openssh
  

  depends_on = [
    tls_private_key.key
  ]

}
# Save Private key locally
resource "local_file" "key-file" {
  content  = tls_private_key.key.private_key_pem
  filename = "key3.pem"


  depends_on = [
    tls_private_key.key
  ]
}
#create vpc
resource "aws_vpc" "myvpc" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = "true"
  enable_dns_support = "true"
  tags = {
    Name = "myvpca3"
  }
}
#public subnet
resource "aws_subnet" "subnet1a" {
  depends_on = [ aws_vpc.myvpc ]
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "public1a"
  }
}
#private subnet
resource "aws_subnet" "subnet1b" {
  depends_on = [ aws_vpc.myvpc ]
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "192.168.2.0/24"
  availability_zone = "ap-south-1b"
  tags = {
    Name = "private1b"
  }
}
#security group allowing ssh and http
resource "aws_security_group" "sg1" {
  depends_on = [ aws_vpc.myvpc ]
  name        = "sg1-public"
  description = "Allow inbound traffic ssh and http"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description = "allow ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    
  }
  ingress {
    description = "allow http"
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
    Name = "allow_ssh_httpd"
  }
}
#security group allowing port 3306 for sql
resource "aws_security_group" "sg2" {
  depends_on = [ aws_vpc.myvpc ]
  name        = "sg2-private"
  description = "Allow inbound traffic mysql from public subnet security group"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description = "allow ssh"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = ["${aws_security_group.sg1.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_mysql"
  }
}
#internet gateway
resource "aws_internet_gateway" "myigw" {
  depends_on = [ aws_vpc.myvpc ]
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "igwa3"
  }
}
#route table
resource "aws_route_table" "route-table" {
  depends_on = [ aws_internet_gateway.myigw ]
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myigw.id
  }

  tags = {
    Name = "route-table"
  }
}
#association
resource "aws_route_table_association" "route-table-association" {
  depends_on = [ aws_route_table.route-table ]
  subnet_id      = aws_subnet.subnet1a.id
  route_table_id = aws_route_table.route-table.id
}
#mysql instance
resource "aws_instance" "mysql" {
  depends_on = [ aws_security_group.sg2,aws_subnet.subnet1b ]
  
  ami = "ami-02c07047ecb7f00f1"
  instance_type = "t2.micro"
  
  vpc_security_group_ids = [ aws_security_group.sg2.id ]
  subnet_id = aws_subnet.subnet1b.id
  
  tags = {
    Name = "mysql"
  }
}
#wordpress instance
resource "aws_instance" "wp" {
  depends_on = [ aws_security_group.sg1,aws_subnet.subnet1a,aws_instance.mysql ]
  
  ami = "ami-07a26cd5ac1d6ff66"
  instance_type = "t2.micro"
  
  vpc_security_group_ids = [ aws_security_group.sg1.id ]
  subnet_id = aws_subnet.subnet1a.id
  associate_public_ip_address = "true"
  
  key_name = "key3"
    
  tags = {
    Name = "wordpress"
  }
}