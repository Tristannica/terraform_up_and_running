provider "aws" {
    region = "us-east-2"
}

# SINGLE INSTANCE
resource "aws_instance" "tf-example" {
    ami = "ami-0fb653ca2d3203ac1"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.instance.id]
}

# ASG LAUNCH TEMPLATE
resource "aws_launch_template" "tf-example" {
    name_prefix = "tf-example-"
    image_id = "ami-0fb653ca2d3203ac1"
    instance_type = "t2.micro"
   
    vpc_security_group_ids = [aws_security_group.instance.id]

    user_data = filebase64("${path.module}/user_data.sh")

    lifecycle {
      create_before_destroy = true
    }
}

# Auto Scaling Group (ASG) using Launch Template
resource "aws_autoscaling_group" "tf-example" {
    vpc_zone_identifier  = data.aws_subnets.default.ids

    min_size = 2
    max_size = 10

    launch_template {
      id        = aws_launch_template.tf-example.id
      version   = "$Latest"
    }

    tag {
      key                 = "Name"
      value               = "terraform-asg-example"
      propagate_at_launch = true
    }
}

resource "aws_security_group" "instance" {
  name = "terraform-example-instance"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

variable "server_port" {
  description   = "The port the server will use for HTTP requests"
  type          = number
}

data "aws_vpc" "default" {
    default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# output "public_ip" {
#   value         = aws_instance.tf-example.public_ip
#   description   = "The public IP address of the instance"
# }