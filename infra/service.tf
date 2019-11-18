locals {
  service_name = "gunicorn-demo"
  container_port = 80
}

/*====
Cloudwatch
======*/
resource "aws_cloudwatch_log_group" "default" {
  name = "${local.service_name}"
}

/*====
ECR
======*/
resource "aws_ecr_repository" "default" {
  name = "${local.service_name}"
}

/*====
Task
======*/
data "template_file" "task" {
  template = "${file("${path.module}/task.json")}"

  vars {
    container_name  = "${local.service_name}"
    container_image = "${aws_ecr_repository.default.repository_url}"
    container_port  = "${local.container_port}"
    log_group       = "${aws_cloudwatch_log_group.default.name}"
    log_region      = "${local.region}"
  }
}

resource "aws_ecs_task_definition" "default" {
  family                   = "${local.service_name}"
  container_definitions    = "${data.template_file.task.rendered}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = "${aws_iam_role.ecs_exec.arn}"
  task_role_arn            = "${aws_iam_role.ecs_task.arn}"

  lifecycle {
    ignore_changes = ["container_definitions"] # Because it changes everytime we deploy
  }
}

/*====
IAM
======*/
# Task role
data "aws_iam_policy_document" "ecs_task" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task" {
  name               = "${local.service_name}-ecs-task"
  assume_role_policy = "${data.aws_iam_policy_document.ecs_task.json}"
}

# Task executor role (Docker daemon and ECS agent)
data "aws_iam_policy_document" "ecs_exec" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_exec" {
  name               = "${local.service_name}-ecs-task-exec"
  assume_role_policy = "${data.aws_iam_policy_document.ecs_exec.json}"
}

data "aws_iam_policy_document" "ecs_exec_policy" {
  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
  }
}

resource "aws_iam_role_policy" "ecs_exec" {
  name   = "${local.service_name}-ecs-task-exec"
  policy = "${data.aws_iam_policy_document.ecs_exec_policy.json}"
  role   = "${aws_iam_role.ecs_exec.id}"
}

# ECS Service role
data "aws_iam_policy_document" "ecs_service" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_service" {
  name               = "${local.service_name}-ecs"
  assume_role_policy = "${data.aws_iam_policy_document.ecs_service.json}"
}

data "aws_iam_policy_document" "ecs_service_policy" {
  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "elasticloadbalancing:Describe*",
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
      "ec2:Describe*",
      "ec2:AuthorizeSecurityGroupIngress",
    ]
  }
}

resource "aws_iam_role_policy" "ecs_service" {
  name   = "${local.service_name}-ecs"
  policy = "${data.aws_iam_policy_document.ecs_service_policy.json}"
  role   = "${aws_iam_role.ecs_service.id}"
}

/*====
Networking
======*/
resource "aws_security_group" "ecs_service" {
  vpc_id      = "${aws_vpc.vpc.id}"
  name        = "${local.service_name}-ecs-service"
  description = "Allow egress from container"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "default" {
  name                 = "${local.service_name}"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = "${aws_vpc.vpc.id}"
  target_type          = "ip"
  deregistration_delay = 30

  health_check {
    path = "/"
    interval = 300
  }
}

resource "aws_lb_listener_rule" "default" {
  listener_arn = "${aws_lb_listener.http.arn}"
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.default.arn}"
  }

  condition {
    field  = "path-pattern"
    values = ["/*"]
  }
}

/*====
ECS Service
======*/
resource "aws_ecs_service" "default" {
  name            = "${local.service_name}"
  task_definition = "${aws_ecs_task_definition.default.family}:${aws_ecs_task_definition.default.revision}"
  desired_count   = "1"
  launch_type     = "FARGATE"
  cluster         = "${aws_ecs_cluster.default.arn}"
  depends_on      = ["aws_iam_role_policy.ecs_service"]

  network_configuration {
    security_groups  = ["${aws_security_group.default.id}", "${aws_security_group.ecs_service.id}"]
    subnets          = ["${aws_subnet.public_subnet.*.id}"]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = "${aws_lb_target_group.default.arn}"
    container_name   = "${local.service_name}"
    container_port   = "${local.container_port}"
  }

  depends_on = ["aws_lb_listener_rule.default"]
}
