# ALB with ACM SSL Certificate for K3s API access
resource "aws_acm_certificate" "k3s_cert" {
  domain_name       = "${var.environment}.k3s.${var.domain_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "health-app-${var.environment}-k3s-cert"
    Environment = var.environment
  }
}

resource "aws_lb" "k3s_alb" {
  name               = "health-app-${var.environment}-k3s-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets           = var.subnet_ids

  tags = {
    Name = "health-app-${var.environment}-k3s-alb"
    Environment = var.environment
  }
}

resource "aws_security_group" "alb_sg" {
  name_prefix = "health-app-${var.environment}-alb-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from internet"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP redirect to HTTPS"
  }

  egress {
    from_port       = 6443
    to_port         = 6443
    protocol        = "tcp"
    security_groups = [var.k3s_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "health-app-${var.environment}-alb-sg"
  }
}

resource "aws_lb_target_group" "k3s_tg" {
  name     = "health-app-${var.environment}-k3s-tg"
  port     = 6443
  protocol = "HTTPS"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200,401"
    path                = "/version"
    port                = "traffic-port"
    protocol            = "HTTPS"
    timeout             = 5
    unhealthy_threshold = 3
  }

  target_type = "instance"

  tags = {
    Name = "health-app-${var.environment}-k3s-tg"
  }
}

resource "aws_lb_target_group_attachment" "k3s_attachment" {
  target_group_arn = aws_lb_target_group.k3s_tg.arn
  target_id        = var.k3s_instance_id
  port             = 6443
}

resource "aws_lb_listener" "k3s_listener" {
  load_balancer_arn = aws_lb.k3s_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.k3s_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k3s_tg.arn
  }

  depends_on = [aws_acm_certificate.k3s_cert]
}

# HTTP listener for redirect to HTTPS
resource "aws_lb_listener" "k3s_http_redirect" {
  load_balancer_arn = aws_lb.k3s_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# WAF for additional security
resource "aws_wafv2_web_acl" "k3s_waf" {
  name  = "health-app-${var.environment}-k3s-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "RateLimitRule"
    priority = 1

    override_action {
      none {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
      sampled_requests_enabled   = true
    }

    action {
      block {}
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "k3sWAF"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "health-app-${var.environment}-k3s-waf"
    Environment = var.environment
  }
}

# Associate WAF with ALB
resource "aws_wafv2_web_acl_association" "k3s_waf_association" {
  resource_arn = aws_lb.k3s_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.k3s_waf.arn
}
}