resource "aws_vpc" "myvpc" {
  cidr_block = var.cidr

  tags = {
    Name = "my-vpc"
  }
}

resource "aws_subnet" "sub1" {
  vpc_id = aws_vpc.myvpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1"
  }
}

resource "aws_subnet" "sub2" {
  vpc_id = aws_vpc.myvpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-2"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "my-igw"
  }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "rt1" {
  subnet_id = aws_subnet.sub1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "rt2" {
  subnet_id = aws_subnet.sub2.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "albsg" {
    name = "alb-sg"
    vpc_id = aws_vpc.myvpc.id

    ingress {
        description = "HTTP"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = -1
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "alb-sg"
    }
}

resource "aws_security_group" "instancesg" {
    name = "instance-sg"
    vpc_id = aws_vpc.myvpc.id

    ingress {
      description = "HTTP"
      from_port = 80
      to_port = 80
      protocol = "tcp"
      security_groups = [aws_security_group.albsg.id]
    }

    ingress {
      description = "SSH"
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = [var.myip]
    }

    egress {
      from_port = 0
      to_port = 0
      protocol = -1
      cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
      Name = "instance-sg"
    }
}

resource "aws_instance" "instance1" {
    ami = "ami-0ecb62995f68bb549"
    instance_type = "t3.micro"
    vpc_security_group_ids = [aws_security_group.instancesg.id]
    subnet_id = aws_subnet.sub1.id

    key_name = "terraform-aws"

    user_data = file("${path.module}/user_data1.sh")

    tags = {
      Name = "web-server-1"
    }
}

resource "aws_instance" "instance2" {
    ami = "ami-0ecb62995f68bb549"
    instance_type = "t3.micro"
    vpc_security_group_ids = [aws_security_group.instancesg.id]
    subnet_id = aws_subnet.sub2.id

    key_name = "terraform-aws"

    user_data = file("${path.module}/user_data2.sh")

    tags = {
      Name = "web-server-2"
    }
}

resource "aws_alb" "myalb" {
    name = "myalb"
    internal = false
    load_balancer_type = "application"
    security_groups = [aws_security_group.albsg.id]
    subnets = [aws_subnet.sub1.id, aws_subnet.sub2.id]

    tags = {
      Name = "my-alb"
    }
}

resource "aws_alb_target_group" "tg" {
    name = "mytg"
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.myvpc.id

    health_check {
      path = "/"
      port = "traffic-port"
    }

    tags = {
      Name = "mytg"
    }
}

resource "aws_lb_target_group_attachment" "attach1" {
    target_group_arn = aws_alb_target_group.tg.arn
    target_id = aws_instance.instance1.id
    port = 80
}

resource "aws_lb_target_group_attachment" "attach2" {
    target_group_arn = aws_alb_target_group.tg.arn
    target_id = aws_instance.instance2.id
    port = 80
}

resource "aws_lb_listener" "listener" {
    load_balancer_arn = aws_alb.myalb.arn
    port = 80
    protocol = "HTTP"

    default_action {
      target_group_arn = aws_alb_target_group.tg.arn
      type = "forward"
    }
}

output "loadbalancer" {
    value = aws_alb.myalb.dns_name
}