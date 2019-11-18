/*====
IAM
======*/
resource "aws_security_group" "alb" {
  name        = "gunicorn-demo-alb"
  description = "Allow HTTP from Anywhere into ALB"
  vpc_id      = "${aws_vpc.vpc.id}"

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

/*====
ALB
======*/
resource "aws_alb" "default" {
  name            = "gunicorn-demo"
  subnets         = ["${aws_subnet.public_subnet.*.id}"]
  security_groups = ["${aws_security_group.default.id}", "${aws_security_group.alb.id}"]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = "${aws_alb.default.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not found"
      status_code  = "404"
    }
  }
}
