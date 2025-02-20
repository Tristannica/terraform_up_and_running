provider "aws" {
    region = "us-east-2"
}

# # SINGLE INSTANCE
# resource "aws_instance" "tf-example" {
#     ami                    = "ami-0fb653ca2d3203ac1"
#     instance_type          = "t2.micro"
#     vpc_security_group_ids = [aws_security_group.instance.id]
# }

# ASG LAUNCH TEMPLATE
resource "aws_launch_template" "tf-example" {
    name_prefix   = "tf-example-"
    image_id      = "ami-0fb653ca2d3203ac1"
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

    target_group_arns = [aws_alb_target_group.asg.arn]
    health_check_type = "ELB"

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

# ALB for ASG
resource "aws_lb" "tf-example" {
    name                = "terraform-asg-example"
    load_balancer_type  = "application"
    subnets             = data.aws_subnets.default.ids
    security_groups     = [aws_security_group.alb.id]
}

# Listener for ALB
resource "aws_lb_listener" "http" {
    load_balancer_arn   = aws_lb.tf-example.arn
    port                = var.server_port
    protocol            = "HTTP"

    default_action {
      type = "fixed-response"

      fixed_response {
        content_type = "text/plain"
        message_body = "404: page not found"
        status_code  = 404
      }
    }
}

# ALB Target Group for ASG
resource "aws_alb_target_group" "asg" {
  name      = "terraform-asg-example"
  port      = var.server_port
  protocol  = "HTTP"
  vpc_id    = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Listener Rules for ALB
resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.asg.arn
  }
}   

# Security Group for ALB Traffic
resource "aws_security_group" "alb" {
  name = "terraform-example-alb"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
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

output "alb_dns_name" {
  value         = aws_lb.tf-example.dns_name
  description   = "The public IP address of the load balancer"
}