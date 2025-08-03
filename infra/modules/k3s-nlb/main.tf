# Network Load Balancer for K3s with ACM Certificate
resource "aws_lb" "k3s_nlb" {
  name               = "${var.name_prefix}-k3s-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.subnet_ids

  enable_deletion_protection = false

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-k3s-nlb"
    Type = "k3s-load-balancer"
  })
}

# Target group for K3s API server
resource "aws_lb_target_group" "k3s_api" {
  name     = "${var.name_prefix}-k3s-api-tg"
  port     = 6443
  protocol = "TCP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/readyz"
    port                = "6443"
    protocol            = "HTTPS"
    timeout             = 10
    unhealthy_threshold = 2
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-k3s-api-tg"
  })
}

# Attach K3s instance to target group
resource "aws_lb_target_group_attachment" "k3s_api" {
  target_group_arn = aws_lb_target_group.k3s_api.arn
  target_id        = var.k3s_instance_id
  port             = 6443
}

# HTTPS listener with ACM certificate
resource "aws_lb_listener" "k3s_https" {
  load_balancer_arn = aws_lb.k3s_nlb.arn
  port              = "443"
  protocol          = "TLS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k3s_api.arn
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-k3s-https-listener"
  })
}