provider "aws" {
  region = "eu-central-1"
}
variable "default_port" {
  default = 80
  type = number

}
/////////////AZS/////////////
data "aws_availability_zones" "azs" {}
///////////VPC//////////////
data "aws_vpc" "vpc" {
  default = true
}
////////////SUBNETS//////////////
data "aws_subnets" "subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }
}

///////////////////SG////////////////////
resource "aws_security_group" "sg" {
  name = "open http sg"
  ingress {
    from_port   = var.default_port
    to_port     = var.default_port
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

////////////////////////LAUNCH CNFIG//////////////////
resource "aws_launch_configuration" "lc" {
  image_id      = "ami-0b2ac948e23c57071"
  instance_type = "t2.micro"
  user_data     = file("web_script.sh")

  security_groups = [aws_security_group.sg.id]


}

/////////////////////AUTO ScALING GROUP/////////////////////


resource "aws_autoscaling_group" "asg" {
  launch_configuration = aws_launch_configuration.lc.id

  min_size            = 3
  max_size            = 4
  target_group_arns   = [aws_alb_target_group.alb_tg.arn]
  vpc_zone_identifier = data.aws_subnets.subnets.ids

  health_check_type = "ELB"

  lifecycle {
    create_before_destroy = true
  }
}
///////////////////////ALB//////////////////////////////////

resource "aws_alb" "example_alb" {
  name               = "terraform-example-alb"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.subnets.ids
  security_groups    = [aws_security_group.alb_sg.id]
}

///////////////////ALB_LISTENER///////////////////////


resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_alb.example_alb.arn
  port              = var.default_port
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404, page not found"
      status_code  = 404
    }
  }
}
/////////////////ALB_SECURITY_GROUP////////////

resource "aws_security_group" "alb_sg" {
  name = "alb-security-group"
  ingress {
    from_port   = var.default_port
    to_port     = var.default_port
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

resource "aws_alb_target_group" "alb_tg" {
  name     = "terraform-alb-target-group"
  protocol = "HTTP"
  port     = var.default_port
  vpc_id   = data.aws_vpc.vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = 200
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 15
  }

}


resource "aws_lb_listener_rule" "lr" {
  listener_arn = aws_alb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }
  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.alb_tg.arn
  }
}



output "alb_dns" {
  value = aws_alb.example_alb.dns_name
  description = "The domain name of the load balancer"
}
output "port" {
  value = var.default_port
  }