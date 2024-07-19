#1a Security Group for ALB (Internet -> ALB) 
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "enable http access on port 80"

  vpc_id      = aws_vpc.main_vpc.id

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

  tags = {
    Name = "alb-sg"
  }
}

#1b Secuirty Group for ALB (ALB -> EC2)
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-sg"
  description = "Security Group for Webserver Instance"
  
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-sg"
  }
}

#2 Create Application load Balancer
resource "aws_lb" "app_lb" {
  name                       = "app-lb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb_sg.id]
  subnets                    = flatten([aws_subnet.public_subnet.*.id])
  depends_on                 = [aws_internet_gateway.igw_vpc] 

  tags = {
    Name = "app-lb"
  }
}

# Create Target Group For ALB
resource "aws_lb_target_group" "alb_ec2_tg" {
  name        = "webserver-tg"
  port        = "80"
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main_vpc.id
  tags = {
    name = "alb_ec2_tg"
  }
}

# create Alb listener on port 80 with forward action
resource "aws_lb_listener" "alb_http_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_ec2_tg.arn
  }
  tags = {
    name = "alb_http_listener"
  }
}

# Create launch Template for EC2 instance
resource "aws_launch_template" "ec2_launch_template" {
  name = "webserver"
  image_id = "ami-0b72821e2f351e396"
  instance_type = "t2.micro"

  network_interfaces {
    associate_public_ip_address = false
    security_groups = [aws_security_group.ec2_sg.id]
  }

  user_data = filebase64("userdata.sh")
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "webserver"
    }
  }  
}

# create auto scaling group
resource "aws_autoscaling_group" "auto_scaling_group" {
  vpc_zone_identifier = aws_subnet.private_subnet[*].id
  desired_capacity    = 2
  max_size            = 3
  min_size            = 2
  health_check_type   = "EC2"
  name                = "webserver-asg" 
  target_group_arns   = [aws_lb_target_group.alb_ec2_tg.arn]

  launch_template {
    id      = aws_launch_template.ec2_launch_template.id
    version = "$Latest"
  }

}

output "alb_dns_name" {
  value = aws_lb.app_lb.dns_name
}
