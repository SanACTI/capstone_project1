################################### DATA ###############################################

data "aws_availability_zones" "available" {}

data "aws_ami" "aws_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

################################### RESOURCES ###############################################

# NETWORKING #
resource "aws_vpc" "vpc" {
  cidr_block           = var.network_address_space
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_subnet" "subnet" {
  count                   = var.subnet_count
  cidr_block              = cidrsubnet(var.network_address_space, 8, count.index)
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]
}

# ROUTING #
resource "aws_route_table" "rtb" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "rta_subnet" {
  count          = var.subnet_count
  subnet_id      = aws_subnet.subnet[count.index].id
  route_table_id = aws_route_table.rtb.id
}

# SECURITY GROUP #
resource "aws_security_group" "aws_sg" {
  name   = "mysecuritygroup"
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["223.186.153.90/32"]
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
}

# EC2 INSTANCES #
resource "aws_instance" "myinstance" {
  count                  = var.instance_count
  ami                    = data.aws_ami.aws_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.subnet[count.index % var.subnet_count].id
  vpc_security_group_ids = [aws_security_group.aws_sg.id]
  key_name               = var.key_name

  user_data = file("${path.module}/userdata.sh")

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "Terraform-${count.index + 1}"
  }

  connection {
    type        = "ssh"
    host        = coalesce(self.public_ip, self.private_ip)
    user        = var.instance_username
    private_key = file(var.private_key_path)
  }
}

################################### OUTPUTS ###############################################

output "aws_host_ip" {
  value = aws_instance.myinstance[*].private_ip
}

output "aws_public_dns" {
  value = aws_instance.myinstance[*].public_dns
}
