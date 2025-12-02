resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "ALB security group"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-alb-sg"
  })
}

resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  idle_timeout = 60

  tags = var.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      status_code = "HTTP_301"
      port        = "443"
      protocol    = "HTTPS"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      status_code  = "404"
      message_body = "Route not configured"
    }
  }
}

resource "aws_lb_target_group" "this" {
  for_each = var.routes

  name        = substr("${var.name}-${each.key}", 0, 32)
  vpc_id      = var.vpc_id
  target_type = "ip"
  port        = lookup(each.value, "port", 80)
  protocol    = lookup(each.value, "protocol", "HTTP")

  health_check {
    enabled             = true
    path                = var.health_check_path
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
    matcher             = "200-399"
  }

  tags = merge(var.tags, {
    Route = each.key
  })
}

resource "aws_lb_listener_rule" "routes" {
  for_each     = var.routes
  listener_arn = aws_lb_listener.https.arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[each.key].arn
  }

  condition {
    path_pattern {
      values = [each.value.path]
    }
  }
}

resource "aws_wafv2_web_acl_association" "this" {
  count        = var.waf_arn != "" ? 1 : 0
  resource_arn = aws_lb.this.arn
  web_acl_arn  = var.waf_arn
}

