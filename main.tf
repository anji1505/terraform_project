# configured aws provider with proper credentials
provider "aws" {
  region    = var.region
  profile   = var.profile
}


# create default vpc if one does not exit
resource "aws_default_vpc" "default_vpc" {

  tags    = {
    Name  = "default vpc"
  }
}


# use data source to get all avalablility zones in region
data "aws_availability_zones" "available_zones" {}


# create default subnet if one does not exit
resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.available_zones.names[0]

  tags   = {
    Name = "default subnet"
  }
}
# create security group for the ec2 instance
resource "aws_security_group" "web_sg" {
  name        = "ec2 security group"
  description = "allow access on ports 80,8080 and 22"
  vpc_id      = aws_default_vpc.default_vpc.id

  # allow access on port 80
  ingress {
    description      = "http proxy access"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  # allow access on port 8080
  ingress {
    description      = "jenkins port"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  # allow access on port 22
  ingress {
    description      = "ssh access"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = -1
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags   = {
    Name = "tracrat-dev-security_group"
  }
}
# launch the ec2 instance and install website
resource "aws_instance" "web_instance" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id              = aws_default_subnet.default_az1.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
tags = {
  Name = var.tag
}

}
# an empty resource block
resource "null_resource" "name" {

  # ssh into the ec2 instance
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.private_key_file)
    host        = aws_instance.web_instance.public_ip
  }

  # copy the install_tools.sh file from your computer to the ec2 instance
  provisioner "file" {
    source      = var.source_file
    destination = var.destination
  }

  # set permissions and run the install_tools.sh file
  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/install_tools.sh",
      "sh /tmp/install_tools.sh",
    ]
  }

  # wait for ec2 to be created
  depends_on = [aws_instance.web_instance]
}


# print the url of the jenkins server
output "website_url" {
  value     = join ("", ["http://", aws_instance.web_instance.public_dns, ":", "8080"])
}
